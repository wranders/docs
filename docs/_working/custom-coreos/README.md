# Custom CoreOS

In a working directory, create some directories that will be needed.

```sh
mkdir ssh tmp
```

`ssh` will hold the keys used by the builder installation and `tmp` is used by
the compressor after the build.

## Setup Builder on Pi

Generate an ED25519 SSH key pair in the `ssh` directory.

```sh
ssh-keygen -t ed25519 -N '' -f ssh/id_ed25519_builder
```

Create the first part of the Butane configuration. This contains public SSH key
that will be authorized to login as the `core` user, which is the default user
for Fedora CoreOS.

```sh
cat << EOF > builder.bu
--8<-- "docs/_working/custom-coreos/builder.bu.d/01.passwd.bu"
EOF
```

Next, append the portion of the Butane configuration that sets up the Podman
socket. This is what the CoreOS Assembler will connect to to run the build job.

```sh
cat << EOF >> builder.bu
--8<-- "docs/_working/custom-coreos/builder.bu.d/02.podman.sock.bu"
EOF
```

Finally, this portion provisions an attached SSD for use as the `/var` mount.
This is optional, but only using an SD card for storage could cause the build to
take a couple hours.

```sh
cat << EOF | sed 1d >> builder.bu
--8<-- "docs/_working/custom-coreos/builder.bu.d/03.disks.bu"
EOF
```

Transpile the Butane configuration to an Ignition file.

```sh
podman run --rm -i quay.io/coreos/butane:latest --strict < builder.bu > builder.ign
```

Create a Bash function for the `coreos-installer`. Doing this since it will be
used multiple times.

```sh
coreos-installer() {
  sudo podman run --rm --privileged \
  -v /dev:/dev -v /run/udev:/run/udev \
  -v ${PWD}:/data -w /data quay.io/coreos/coreos-installer:latest "$@"
}
```

Insert the SD card into your reader. It appears as `sdb` for me, but might be
different for you.

```sh
coreos-installer install \
-a aarch64 -i builder.ign /dev/sdb
```

Create the following Bash function to help installing UEFI firmware to the SD
card. This is done since the SD card contains the installed OS, not just
installer media. This block can be copied directly into the terminal to create
the function.

```sh
rpi-uefi() {
  if [ "$#" -ne 2 ]; then
    echo "requires 2 arguments: rpi-uefi [VERSION] [BLOCK_DEVICE]"
    return 1
  fi
  sudo -v || return $?
  part=$(lsblk $2 -J -oLABEL,PATH | \
jq -r '.blockdevices[]|select(.label=="EFI-SYSTEM")'.path)
  tmp=/tmp/EFI
  file=RPi4_UEFI_Firmware_$1.zip
  sudo mkdir -p $tmp
  sudo mount $part $tmp
  pushd $tmp >/dev/null
  sudo curl -fsSLO https://github.com/wranders/RPi4/releases/download/$1/$file
  rc=$?; if [ $rc -eq 0 ]; then
    sudo unzip $file
    sudo rm $file
  fi
  popd >/dev/null
  sudo umount $tmp
  sudo rm -rf $tmp
  sudo -k
  [ $rc -eq 0 ] && return $rc
}
```

Get the
[latest version](https://github.com/wranders/RPi4/releases/latest){target=_blank rel="nofollow noopener noreferrer"}
and enter it along with the SD card device path.

!!! note
    This is a customized version of the Tianocore EDK II[^1] UEFI firmware for
    the Raspberry Pi. It is forked from Pi Firmware Task Force[^2] and contains
    a couple modifications that I use for my Raspberry Pi, notably removing the
    3GB RAM limit. You can use the firmware directly from the PFTF, but will
    have to enter the UEFI configuration menu to change this setting manually.

    I also disable WiFI and Bluetooth by default, so if you want to use those
    for some reason, you'll need to delete the respective `dtoverlay` from the
    `config.txt` file.

```sh
rpi-uefi v1.33.1 /dev/sdb
```

Insert SD Card into Pi and wait for the provision to complete. It will take
about 5 minutes to provision.

!!! note
    When the login screen appears, take note of the IPv4 address for later
    unless you have MAC reservations already set up for the Raspberry Pi and
    already know the address.

## Run Builder

Create a function alias for the CoreOS Assembler.

```sh
cosa() {
  env | grep COREOS_ASSEMBLER
  set -x
  podman run --rm -ti --security-opt label=disable --privileged                          \
    --uidmap=1000:0:1 --uidmap=0:1:1000 --uidmap 1001:1001:64536                         \
    -v ${PWD}:/srv/ --device /dev/kvm --device /dev/fuse                                 \
    --tmpfs /tmp -v /var/tmp:/var/tmp --name cosa                                        \
    ${COREOS_ASSEMBLER_CONFIG_GIT:+-v $COREOS_ASSEMBLER_CONFIG_GIT:/srv/src/config/:ro}  \
    ${COREOS_ASSEMBLER_GIT:+-v $COREOS_ASSEMBLER_GIT/src/:/usr/lib/coreos-assembler/:ro} \
    ${COREOS_ASSEMBLER_CONTAINER_RUNTIME_ARGS}                                           \
    ${COREOS_ASSEMBLER_CONTAINER:-quay.io/coreos-assembler/coreos-assembler:latest} "$@"
  rc=$?; set +x; return $rc
}
```

Insert the SSH private key into a Podman secret so it will be easier to pass to
the CoreOS Assembler.

```sh
podman secret create builderssh ssh/id_ed25519_builder
```

Create an `env-file` containing the variables we need to pass to the CoreOS
Assembler. `CONTAINER_HOST` and `CONTAINER_SSHKEY` are used by the `gangplank`
component to access the remote builder.

```ini title="cosa.env"
CONTAINER_HOST=ssh://core@192.168.1.12/run/user/1000/podman/podman.sock
CONTAINER_SSHKEY=/run/secrets/builderssh
```

Create a JobSpec[^3] file that will be used by `gangplank` to build the image.

Specifying only `metal` in the `build` directive implies building the required
`ostree` artifact, which will be returned alongside the `metal` artifact.

```yaml title="spec.tmpl"
recipe:
  git_url: https://github.com/wranders/fcos-k3s-config
  git_ref: stable
stages:
- commands:
  - cosa fetch
  - cosa build metal
```

Use the `CONTAINER_RUNTIME_ARGS` environment variable for the CoreOS Assembler
to insert the SSH secret and the environment file.

```sh
export COREOS_ASSEMBLER_CONTAINER_RUNTIME_ARGS="--secret=builderssh --env-file=cosa.env"
```

Run the following `gangplank` command to start the build.

```sh
cosa shell gangplank pod --podman \
--arch=aarch64 --bucket=builds --spec=spec.spec \
--image=quay.io/wranders/coreos-assembler:latest
```

Using a Raspberry Pi 4B 8GB with a Samsung 870 Evo SSD over USB3, the build
takes roughly 25 minutes.

Compression takes a lot of memory, so it is probably a better idea to do this on
your working machine as it takes the Raspberry Pi 4B 8GB almost as much time to
compress the image as it does to build it.

```sh
cosa compress --compressor=xz
```

I use a Thinkpad T540p with an i7-4700MQ and 16GB of memory as my working
machine, so compression takes about 3 minutes; quite the improvement over
compressing on the Raspberry Pi 4B.

## Write Custom CoreOS to Disk

```sh
coreos-installer install \
-i initial.ign -f builds/*/aarch64/*.raw.xz --insecure /dev/sdb
```

```sh
rpi-uefi v1.33.1 /dev/sdb
```

[^1]: [https://github.com/tianocore/edk2](https://github.com/tianocore/edk2){target=_blank rel="nofollow noopener noreferrer"}
[^2]: [https://github.com/pftf/RPi4](https://github.com/pftf/RPi4){target=_blank rel="nofollow noopener noreferrer"}
[^3]: [https://coreos.github.io/coreos-assembler/gangplank/api-spec/](https://coreos.github.io/coreos-assembler/gangplank/api-spec/){target=_blank rel="nofollow noopener noreferrer"}
