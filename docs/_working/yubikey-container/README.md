# Yubikey In Container

`pcscd` needs to be disabled or removed from the host system. It takes exclusive
control of smard card devices, so they will not be able to be accessed inside of
containers if active.

## Udev Rule

`idProduct` restricts the type of Yubikeys that the rule applies to.

`"0401|0402|0403|0404|0405|0406|0407"` is all Yubikey 4 / 5 variations.

Enabling or disabling USB interfaces will change the `idProduct`.

??? info "Yubikey Product Code Table"
    | YubiKey Series             | USB Interfaces  | `idProduct` | iProduct String        |
    | :-                         | :-              | :-          | :-                     |
    | YubiKey Gen 1              | OTP             | `0010`      | N/A                    |
    | YubiKey Gen 2              | OTP             | `0010`      | N/A                    |
    | YubiKey NEO                | OTP             | `0110`      | YubiKey OTP            |
    | YubiKey NEO                | FIDO            | `0111`      | YubiKey FIDO           |
    | YubiKey NEO                | CCID            | `0112`      | YubiKey CCID           |
    | YubiKey NEO                | OTP, FIDO       | `0113`      | YubiKey OTP+FIDO       |
    | YubiKey NEO                | OTP, CCID       | `0114`      | YubiKey OTP+CCID       |
    | YubiKey NEO                | FIDO, CCID      | `0115`      | YubiKey FIDO+CCID      |
    | YubiKey NEO                | OTP, FIDO, CCID | `0116`      | YubiKey OTP+FIDO+CCID  |
    | YubiKey 4                  | OTP             | `0401`      | YubiKey OTP            |
    | YubiKey 4                  | FIDO            | `0402`      | YubiKey FIDO           |
    | YubiKey 4                  | CCID            | `0404`      | YubiKey CCID           |
    | YubiKey 4                  | OTP, FIDO       | `0403`      | YubiKey OTP+FIDO       |
    | YubiKey 4                  | OTP, CCID       | `0405`      | YubiKey OTP+CCID       |
    | YubiKey 4                  | FIDO, CCID      | `0406`      | YubiKey FIDO+CCID      |
    | YubiKey 4                  | OTP, FIDO, CCID | `0407`      | YubiKey OTP+FIDO+CCID  |
    | YubiKey FIPS (4 Series) \* | OTP, FIDO, CCID | `0407`      | YubiKey OTP+FIDO+CCID  |
    | YubiKey 5                  | OTP             | `0401`      | YubiKey OTP            |
    | YubiKey 5                  | FIDO            | `0402`      | YubiKey FIDO           |
    | YubiKey 5                  | CCID            | `0404`      | YubiKey CCID           |
    | YubiKey 5                  | OTP, FIDO       | `0403`      | YubiKey OTP+FIDO       |
    | YubiKey 5                  | OTP, CCID       | `0405`      | YubiKey OTP+CCID       |
    | YubiKey 5                  | FIDO, CCID      | `0406`      | YubiKey FIDO+CCID      |
    | YubiKey 5                  | OTP, FIDO, CCID | `0407`      | YubiKey OTP+FIDO+CCID  |
    | YubiKey 5 FIPS Series \*   | OTP, FIDO, CCID | `0407`      | YubiKey OTP+FIDO+CCID  |
    | Security Key Series        | FIDO            | `0120`      | Security Key by Yubico |

    **\*** The YubiKey FIPS (4 Series) and YubiKey 5 FIPS Series devices, when
    deployed in a FIPS-approved mode, will have all USB interfaces enabled.
    Should an exemption be obtained to deploy these devices with some interfaces
    disabled, the PID and iProduct values will be identical to the YubiKey 4/5
    Series.

    Source: [Yubico](https://support.yubico.com/hc/en-us/articles/360016614920-YubiKey-USB-ID-Values){target=_blank rel="nofollow noopener noreferrer"}

```raw title="/etc/udev/rules.d/99-yubikey.rules"
SUBSYSTEMS=="usb", \
    ATTRS{idVendor}=="1050", \
    ATTRS{idProduct}=="0401|0402|0403|0404|0405|0406|0407", \
    SYMLINK+="yubikey", \
    OWNER:="core", \
    GROUP:="core"
```

Check that the proper device is mounted:

```sh
ls -l /dev/yubikey
```

If the `symlink` points to an `hidraw` device or something that is not on the
USB bus (eg. `/dev/bus/usb/XXX/XXX`), unplug the Yubikey and reload the
`udev` rules:

```sh
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Then plug the Yubikey back in and recheck the `symlink` location:

```sh
$ ls -l /dev/yubikey
lrwxrwxrwx. 1 root root 15 Jan 01 00:00 /dev/yubikey -> bus/usb/001/004
```

Finally, check the user and group of the USB bus device to make sure it's owned
but the user you plan to execute the container as.

```sh
$ ls -l /dev/yubikey
crw-rw----. 1 core core 189, Jan 22 00:00 /dev/bus/usb/001/004
```

### FCOS Butane

```yaml
. . .
storage:
  files:
    - path: /etc/udev/rules.d/99-yubikey.rules
      mode: 0644
      contents:
        inline: |
          SUBSYSTEMS=="usb", \
            ATTRS{idVendor}=="1050", \
            ATTRS{idProduct}=="0401|0402|0403|0404|0405|0406|0407", \
            SYMLINK+="yubikey", \
            OWNER:="core", \
            GROUP:="core"
. . .
```

## SELinux Rule

### Compile Module

```raw title="yubikey_container.te"
module yubikey_container 1.0;

require {
    type container_t;
    type usb_device_t;
    class chr_file { getattr ioctl open read write };
}
allow container_t usb_device_t:chr_file { getattr ioctl open read write };
```

```sh
checkmodule -M -m -o yubikey_container.mod yubikey_container.te
```

```sh
semodule_package -o yubikey_container.pp -m yubikey_container.mod
```

```sh
semodule -i yubikey_container.pp
```

### Common Intermediate Language (CIL)

```raw title="yubikey_container.cil"
(typeattributeset cil_gen_require container_t)
(typeattributeset cil_gen_require usb_device_t)
(allow container_t usb_device_t (chrfile (getattr ioctl open read write)))
```

```sh
semodule -i yubikey_container.cil
```

### CIL + FCOS Butane

```yaml
. . .
storage:
  files:
  - path: /etc/policies/yubikey_container.cil
    mode: 0644
    contents:
      inline: |
        (typeattributeset cil_gen_require container_t)
        (typeattributeset cil_gen_require usb_device_t)
        (allow container_t usb_device_t (chrfile (getattr ioctl open read write)))
. . .
systemd:
  units:
  - name: yubikey-container-selinux-policy.service
    enabled: true
    contents: |
      [Service]
      Type=oneshot
      ExecStart=/usr/sbin/semodule -i /etc/policies/yubikey_container.cil
      RemainAfterExit=yes
      [Install]
      WantedBy=multi-user.target
. . .
```

## Images

### Ubuntu

```sh
mkdir ubuntu
```

Ubuntu images contain and run `dbus` by default, so we only need to install
`pcscd` and Yubikey libraries.

```sh title="ubuntu/entrypoint.sh"
#!/bin/bash
init() {
    local pcscd_running=$(ps aux | grep [p]cscd)
    if [ -z "$pcscd_running" ]; then
        echo "starting pcscd in background"
        pcscd --debug --apdu
        pcscd --hotplug
    else
        echo "pcscd is running: ${pscsd_running}"
    fi
}
init
"$@"
```

```dockerfile title="ubuntu/Dockerfile"
FROM docker.io/library/ubuntu:latest
RUN apt update && \
    apt install -y --no-install-recommends software-properties-common && \
    add-apt-repositry -y ppa:yubico/stable && \
    apt update && \
    apt install -y --no-install-recommends pcscd usbutils yubico-piv-tool && \
    apt clean
WORKDIR /root/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
CMD [ "yubico-piv-tool", "--help" ]
```

```sh
podman build -t localhost/yubi-ubuntu:latest ubuntu/
```

```sh
podman run --rm -it --device=/dev/yubikey \
localhost/yubi-ubuntu:latest yubico-piv-tool -a status
```

### Fedora

```sh
mkdir fedora
```

Fedora images do not contain the `dbus-daemon` by default, which is used by
`pcscd` to locate and communicate with smart cards. It needs to be installed
explicitly.

```sh title="fedora/entrypoint.sh"
#!/bin/bash
init() {
    local pcscd_running=$(pc aux | grep [p]cscd)
    if [ -z "$pcscd_running" ]; then
        echo "starting pcscd"
        pcscd --debug --apdu
        pcscd --hotplug
    else
        echo "pcscd is running: ${pscsd_running}"
    fi
    local dbus_daemon_running=$(ps aux | grep [d]bus-daemon)
    if [ -z "$dbus_daemon_running" ]; then
        echo "starting dbus-daemon"
        mkdir -p /run/dbus
        dbus-daemon --config-file=/usr/share/dbus-1/system.conf
    else
        echo "dbus-daemon is running: ${dbus-daemon}"
    fi
}
init
"$@"
```

```dockerfile title="fedora/Dockerfile"
FROM registry.fedoraproject.org/fedora:35
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
    dbus-daemon procps yubico-piv-tool && \
    dnf clean all
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
WORKDIR /root/
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
CMD [ "yubico-pib-tool", "--help" ]
```

```sh
podman build -t localhost/yubi-fedora:latest fedora/
```

```sh
podman run --rm -it --device=/dev/yubikey \
localhost/yubi-fedora:latest yubico-piv-tool -a status
```

### Buildah from Scratch

```sh
mkdir -p buildah
```

```dockerfile title="buildah/Dockerfile"
FROM registry.fedoraproject.org/fedora:35
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
    buildah fuse-overlayfs podman --exclude container-selinux && \
    dnf clean all
RUN sed -i \
    -e 's|^#mount_program|mount_program|g' \
    -e '/additionalimage.*/a "/var/lib/shared",' \
    /etc/containers/storage.conf
RUN mkdir -p /var/lib/shared/overlay-{images,layers}
RUN touch /var/lib/shared/overlay-{iamges/iamges.lock,layers/layers.lock}
ENV _BUILDAH_STARTED_IN_USERNS="" BUILDAH_ISOLATION=chroot
CMD [ "/usr/bin/bash" ]
```

```sh title="buildah/yubi-buildah.sh"
set -x

CONTAINER=$(buildah from scratch)
MOUNT=$(buildah mount $CONTAINER)
dnf install -y --setopt=install_weak_deps=False --nodocs --release=35 \
    --installroot=$MOUNT dbus-daemon procps yubico-piv-tool
dnf clean --installroot=$MOUNT all
cat << 'EOF' > $MOUNT/usr/local/bin/entrypoint.sh
#!/bin/bash
init() {
    local pcscd_running=$(pc aux | grep [p]cscd)
    if [ -z "$pcscd_running" ]; then
        echo "starting pcscd"
        pcscd --debug --apdu
        pcscd --hotplug
    else
        echo "pcscd is running: ${pscsd_running}"
    fi
    local dbus_daemon_running=$(ps aux | grep [d]bus-daemon)
    if [ -z "$dbus_daemon_running" ]; then
        echo "starting dbus-daemon"
        mkdir -p /run/dbus
        dbus-daemon --config-file=/usr/share/dbus-1/system.conf
    else
        echo "dbus-daemon is running: ${dbus-daemon}"
    fi
}
init
"$@"
EOF
chmod +x $MOUNT/usr/local/bin/entrypoint.sh
buildah config \
    --workingdir=/root/ \
    --cmd="yubico-piv-tool --help" \
    --entrypoint='[ "/usr/local/bin/entrypoint.sh" ]' \
    --env=PATH=$PATH \
    $CONTAINER
buildah unmount $CONTAINER
buildah commit $CONTAINER localhost/yubi-buildah:latest
podman save --format=oci-archive -o /srv/yubi-buildah.tar localhost/yubi-buildah:latest

set +x
```

```sh
podman build -t localhost/buildah:latest buildah/
```

```sh
podman run --rm -i --privileged --device=/dev/fuse -v ./buildah/:/srv/:z \
localhost/buildah:latest < ./buildah/yubi-buildah.sh
```

Container image archive will be saved to `./buildah/yubi-buildah.tar`. To
use it, first execute the following:

```sh
podman load < ./buildah/yubi-buildah.tar
```

```sh
podman run --rm -it --device=/dev/yubikey \
localhost/yubi-ubuntu:latest yubico-piv-tool -a status
```
