# Yubikey In Containers

`pcscd` must not be running on the host. The daemon takes exclusive control of
smart card devices, so they will not be able to be accessed inside containers.

Stopping the systemd `pcscd.socket` is generally all that needs to be done. If
you use smart cards for other purposes, be sure to re-enable it when you're
done.

```sh
sudo systemctl stop pcscd.socket
```

## SELinux

On SELinux-enforcing systems, a policy needs to be created to allow container
applications (Docker & Podman) access to USB devices that mount as character
devices. This will allow a yubikey to be passed in as a `--device`.

### Compile Module

Using the classic Type Enforcement (`te`) format, the policy can be compiled
with the following:

```raw title="container_usb_chr.te"
module container_usb_chr 1.0;

require {
    type container_t;
    type usb_device_t;
    class chr_file { getattr ioctl open read write };
}
allow container_t usb_device_t:chr_file { getattr ioctl open read write };
```

If you're unfamiliar with writing custom SELinux policies, `te` files must be
compiled into a module (`mod`) first, then bundled into a Policy Package (`pp`).

```sh
checkmodule -M -m -o container_usb_chr.mod container_usb_chr.te
```

```sh
semodule_package -o container_usb_chr.pp -m container_usb_chr.mod
```

Finally, install the Policy Package:

```sh
semodule -i container_usb_chr.pp
```

### Common Intermediate Language (CIL)

An alternative to the Type Enforcement compilation workflow is the Common
Intermediate Language (CIL). The syntax is a bit more convoluted, but `cil`
files can be installed directly without transatory compilation.

```raw title="container_usb_chr.cil"
(typeattributeset cil_gen_require container_t)
(typeattributeset cil_gen_require usb_device_t)
(allow container_t usb_device_t (chr_file (getattr ioctl open read write)))
```

Install the `cil` file.

```sh
semodule -i container_usb_chr.cil
```

!!! note
    Policies installed using CIL are named after the file, in this case
    `container_usb_chr`. This differs from Type Enforcement syntax where the
    policy name is derived from the `module` declaration.

    This is important if you want to remove the policy in the future since
    modules are removed by name (ie. `semodule -r container_usb_chr`).

??? tip "FCOS Butane"

    Installing the policy in Fedora CoreOS utilizes the CIL format and a
    `systemd` one-shot unit.

    ```yaml
    storage:
      files:
      - path: /etc/policies/container_usb_chr.cil
        mode: 0644
        contents:
          inline: |
            (typeattributeset cil_gen_require container_t)
            (typeattributeset cil_gen_require usb_device_t)
            (allow container_t usb_device_t (chr_file (getattr ioctl open read write)))
    systemd:
      units:
      - name: yubikey-container-selinux-policy.service
        enabled: true
        contents: |
          [Service]
          Type=oneshot
          ExecStart=/usr/sbin/semodule -i /etc/policies/container_usb_chr.cil
          RemainAfterExit=yes
          [Install]
          WantedBy=multi-user.target
    ```

## PIV udev Rule

Udev rules aren't strictly necessary, but they ensure a predictable name to pass
to the container engine.

Without this rule, the PIV device would be (for example) `/dev/bus/usb/001/001`.
This last number increments for every device inserted on that bus and does not
reset until your computer is restarted.

The following rule mounts the PIV device as `/dev/yubipiv` with the serial
number appended if serial numbers are visible over USB (ie.
`/dev/yubipiv0123456789`).

!!! warning "Notice"
    It is strongly recommended to enable serial numbers if you use multiple
    Yubikeys. Without serial numbers enabled, subsequent Yubikeys will overide
    any existing `/dev/yubikey` links.

??? note "Toggling Yubikey Serial Number Visibility"
    To enable:

    ```sh
    ykpersonalize -vu1y -o serial-usb-visible -o serial-api-visible
    ```

    To disable:

    ```sh
    ykpersonalize -vu1y -o -serial-usb-visible -o -serial-api-visible
    ```

```raw title="/etc/udev/rules.d/99-yubikey-piv.rules"
SUBSYSTEM=="usb", \
    ATTRS{idVendor}=="1050", \
    ATTRS{idProduct}=="0401|0402|0403|0404|0405|0406|0407", \
    SYMLINK+="yubipiv$attr{serial}", \
    TAG+="uaccess"
```

!!! abstract "Note"
    The `idProduct` values here match Yubikey 4 and 5 devices. If you use a
    different device, refer to the
    [Yubikey Product Codes](#yubikey-product-codes).

Refresh and load the rules:

```sh
sudo udevadm control --reload-rules && sudo udevadm trigger
```

??? tip "FCOS Butane"

    ```yaml
    storage:
      files:
        - path: /etc/udev/rules.d/99-yubikey-piv.rules
          mode: 0644
          contents:
            inline: |
              SUBSYSTEM=="usb", \
                ATTRS{idVendor}=="1050", \
                ATTRS{idProduct}=="0401|0402|0403|0404|0405|0406|0407", \
                SYMLINK+="yubipiv$attr{serial}", \
                TAG+="uaccess"
    ```

## FIDO udev Rule

This udev rule operates simliarly to the PIV rule. It maps the appropriate
`hidraw` device to `/dev/yubifido` with the serial number appended if serial
numbers are visible over USB (ie. `/dev/yubifido0123456789`).

!!! warning "Notice"
    It is strongly recommended to enable serial numbers if you use multiple
    Yubikeys. Without serial numbers enabled, subsequent Yubikeys will overide
    any existing `/dev/yubikey` links.

??? note "Toggling Yubikey Serial Number Visibility"
    To enable:

    ```sh
    ykpersonalize -vu1y -o serial-usb-visible -o serial-api-visible
    ```

    To disable:

    ```sh
    ykpersonalize -vu1y -o -serial-usb-visible -o -serial-api-visible
    ```

```raw title="/etc/udev/rules.d/99-yubikey-fido.rules"
SUBSYSTEM=="hidraw", \
    ATTRS{idVendor}=="1050", \
    ATTRS{idProduct}=="0401|0402|0403|0404|0405|0406|0407", \
    SYMLINK+="yubifido$attr{serial}", \
    TAG+="uaccess"
```

!!! abstract "Note"
    The `idProduct` values here match Yubikey 4 and 5 devices. If you use a
    different device, refer to the
    [Yubikey Product Codes](#yubikey-product-codes).

Refresh and load the rules:

```sh
sudo udevadm control --reload-rules && sudo udevadm trigger
```

??? tip "FCOS Butane"

    ```yaml
    storage:
      files:
        - path: /etc/udev/rules.d/99-yubikey-fido.rules
          mode: 0644
          contents:
            inline: |
              SUBSYSTEM=="hidraw", \
                ATTRS{idVendor}=="1050", \
                ATTRS{idProduct}=="0401|0402|0403|0404|0405|0406|0407", \
                SYMLINK+="yubifido$attr{serial}", \
                TAG+="uaccess"
    ```

## Yubikey Product Codes

| YubiKey Series                              | USB Interfaces  | `idProduct` | iProduct String        |
| :-                                          | :-              | :-          | :-                     |
| YubiKey Gen 1                               | OTP             | `0010`      | N/A                    |
| YubiKey Gen 2                               | OTP             | `0010`      | N/A                    |
| YubiKey NEO                                 | OTP             | `0110`      | YubiKey OTP            |
| YubiKey NEO                                 | FIDO            | `0111`      | YubiKey FIDO           |
| YubiKey NEO                                 | CCID            | `0112`      | YubiKey CCID           |
| YubiKey NEO                                 | OTP, FIDO       | `0113`      | YubiKey OTP+FIDO       |
| YubiKey NEO                                 | OTP, CCID       | `0114`      | YubiKey OTP+CCID       |
| YubiKey NEO                                 | FIDO, CCID      | `0115`      | YubiKey FIDO+CCID      |
| YubiKey NEO                                 | OTP, FIDO, CCID | `0116`      | YubiKey OTP+FIDO+CCID  |
| YubiKey 4                                   | OTP             | `0401`      | YubiKey OTP            |
| YubiKey 4                                   | FIDO            | `0402`      | YubiKey FIDO           |
| YubiKey 4                                   | CCID            | `0404`      | YubiKey CCID           |
| YubiKey 4                                   | OTP, FIDO       | `0403`      | YubiKey OTP+FIDO       |
| YubiKey 4                                   | OTP, CCID       | `0405`      | YubiKey OTP+CCID       |
| YubiKey 4                                   | FIDO, CCID      | `0406`      | YubiKey FIDO+CCID      |
| YubiKey 4                                   | OTP, FIDO, CCID | `0407`      | YubiKey OTP+FIDO+CCID  |
| YubiKey FIPS (4 Series) <sup>&dagger;</sup> | OTP, FIDO, CCID | `0407`      | YubiKey OTP+FIDO+CCID  |
| YubiKey 5                                   | OTP             | `0401`      | YubiKey OTP            |
| YubiKey 5                                   | FIDO            | `0402`      | YubiKey FIDO           |
| YubiKey 5                                   | CCID            | `0404`      | YubiKey CCID           |
| YubiKey 5                                   | OTP, FIDO       | `0403`      | YubiKey OTP+FIDO       |
| YubiKey 5                                   | OTP, CCID       | `0405`      | YubiKey OTP+CCID       |
| YubiKey 5                                   | FIDO, CCID      | `0406`      | YubiKey FIDO+CCID      |
| YubiKey 5                                   | OTP, FIDO, CCID | `0407`      | YubiKey OTP+FIDO+CCID  |
| YubiKey 5 FIPS Series <sup>&dagger;</sup>   | OTP, FIDO, CCID | `0407`      | YubiKey OTP+FIDO+CCID  |
| Security Key Series (firmware <5.2.7)       | FIDO            | `0120`      | Security Key by Yubico |
| Security Key Series (firmware 5.2.7+)       | FIDO            | `0420`      | YubiKey FIDO           |
| YubiKey Bio Series                          | FIDO            | `0420`      | YubiKey FIDO           |

!!! info ""

    &dagger; The YubiKey FIPS (4 Series) and YubiKey 5 FIPS Series devices, when
    deployed in a FIPS-approved mode, will have all USB interfaces enabled.
    Should an exemption be obtained to deploy these devices with some interfaces
    disabled, the `idProduct` and iProduct values will be identical to the
    YubiKey 4 / 5 Series.

    Source: [Yubico](https://support.yubico.com/hc/en-us/articles/360016614920-YubiKey-USB-ID-Values){target=_blank rel="nofollow noopener noreferrer"}

## Using Fedora Base

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

Fedora images do not contain `dbus` by default, which is used by `pcscd` to
locate and communicate with smart cards. It will need to be installed.

```dockerfile title="fedora/Dockerfile"
FROM registry.fedoraproject.org/fedora:37
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
    dbus-daemon procps yubico-piv-tool && \
    dnf clean all
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
WORKDIR /root/
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
CMD [ "yubico-piv-tool", "--help" ]
```

```sh
podman build -t localhost/fedora-yubikey:latest fedora/
```

```sh
podman run --rm -it --device=/dev/yubikey0123456789 \
  localhost/fedora-yubikey:latest yubico-piv-tool -a status
```

## Using Ubuntu Base

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
podman build -t localhost/ubuntu-yubikey:latest ubuntu/
```

```sh
podman run --rm -it --device=/dev/yubikey \
  localhost/ubuntu-yubikey:latest yubico-piv-tool -a status
```
