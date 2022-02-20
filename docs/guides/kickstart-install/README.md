# Kickstart Install

This will show you how to inject a Kickstart file for unattended installations.
We'll focus on Fedora-based distributions since that's what you'll probably be
using.

## Prepare

Create a working directory.

```sh
mkdir ~/custom-iso && cd $_
```

Download your ISO and store its location in an environment variable.

```sh
ISO=~/Downloads/Fedora-Server-dvd-x86_64-35-1.2.iso
```

Extract the `grub.cfg` file so you can modify it.

```sh
xorriso -osirrox on \
  -indev $ISO \
  -extract /EFI/Boot/grub.cfg ./grub.cfg
```

## Modify GRUB Configuration

Get the ISO label.

```sh
grep -oP "hd:LABEL=\K[^ ]+" ./grub.cfg | sort --unique
```

Duplicate the `Install` entry and append the following to the `linux` directive.

Ensure the correct label from the command above.

```sh
inst.ks=hd:LABEL=Fedora-S-dvd-x86_64-35:/ks.cfg
```

Also, be sure to change `set default` reflect the index if the new entry.

```diff
-   set default="1"
+   set default="0"
    . . . . . .
    ### BEGIN /etc/grub.d/10_linux ###
+   menuentry 'Kickstart Install Fedora 35' --class red --class gnu-linux --class gnu --class os {
+       linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=Fedora-S-dvd-x86_64-35 ro inst.ks=hd:LABEL=Fedora-S-dvd-x86_64-35:/ks.cfg
+       initrd /images/pxeboot/initrd.img
+   }
    menuentry 'Install Fedora 35' --class red --class gnu-linux --class gnu --class os {
        linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=Fedora-S-dvd-x86_64-35 ro
        initrd /images/pxeboot/initrd.img
    }
    . . . . . .
```

## Create Kickstart File

Set some environment variables for user creation and timezone info.

```sh
KS_USER="user"
KS_USER_GECOS="User"
KS_USER_PASSWD=$(openssl passwd -6)
KS_TZ="America/New_York"
```

```sh
cat <<EOF > ./ks.cfg
text
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
network --bootproto=dhcp --activate
url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-35&arch=x86_64"
%packages
@^server-product-environment
%end
firstboot --enable
ignoredisk --use-only=sda
autopart
clearpart --none --initlabel
timezone $KS_TZ --utc
rootpw --lock
user --groups=wheel --name=$KS_USER --gecos=$KS_USER_GECOS --iscrypted --password=$KS_USER_PASSWD
reboot
EOF
```

If you want any addional packages, be sure to include them between `%packages`
and its corrosponding `%end`.

Clean up your variables.

```sh
unset KS_USER KS_USER_GECOS KS_USER_PASSWD KS_TZ
```

## Create New ISO with Files

```sh
xorriso \
  -indev $ISO \
  -outdev ./custom.iso \
  -compliance no_emul_toc \
  -map ./grub.cfg /EFI/BOOT/grub.cfg \
  -map ./ks.cfg /ks.cfg \
  -boot_image any replay
```

Your new custom ISO will be in your current working directory at `./custom.iso`.

## Flash Custom Image

We'll assume you're using a USB drive at `/dev/sdb`.

Wipe the drive.

```sh
sudo wipefs -af /dev/sdb
```

Use `dd` to write the image.

```sh
sudo dd -if=./custom.iso -of=/dev/sdb status=progress
```

The installer is ready for use.
