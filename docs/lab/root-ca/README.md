# Root Certificate Authority (CA)

## PKI Overview

My internal PKI is built using several different pieces of software, namely
OpenSSL[^1], Smallstep CA[^2], Microsoft Active Directory Certificate Services,
and FreeIPA[^3].

My Root CA is offline and based on OpenSSL. The private key is generated and
stored on a Yubikey 5 Nano[^4]. The Root CA is restricted to a `pathlen` of 1
and is only used to sign subordinated CAs for issuing end entity certificates.

The following is the structure of my internal PKI:

```sh
DoubleU Root CA             { openssl } [          doubleu.codes ]
├── Home Issuing CA 01      { step-ca } [     home.doubleu.codes ]
├── Home Cloud ACME CA 01   { step-ca } [    cloud.doubleu.codes ]
├── Home AD CA 01           { adcs    } [  ad.home.doubleu.codes ]
└── Home IPA CA 01          { dogtag  } [ ipa.home.doubleu.codes ]
```

Subordinate CAs have their own entries.

## Root CA Implementation

CA files and the database are stored on two USB drives, where one is where CA
actions are taken, and the second is mirrored using `rsync` to ensure a safe
backup. Both USB drives contain a 64MB LUKS-encrypted partition that holds only
text files that contain the Yubikey's `Management Key (KEY)`, `PIN`, and
`PIN Unlock Key (PUK)`. These files are generated using `urandom` and CA actions
are documented to use the files directly as credentials, meaning the values
contained in these files are never leaked to the environment or command history.

Root CA assets, such as the issuing certificate defined in the Authority
Information Access (AIA) extension and the Certificate Revocation List (CRL)
Distribution Points (CDP) extension, are made available through a statically
generated site on Github Pages
([http://ca.doubleu.codes](http://ca.doubleu.codes){target=_blank rel="nofollow noopener noreferrer"}).
That site describes how it was set up and why.

## Install Dependencies

OpenSSL and cryptsetup are already installed on Fedora 35, but there is a few
other tools we need.

```sh
sudo dnf install -y datefudge dateutils yubikey-manager yubico-piv-tool
```

- `datefudge` is used to obscure the exact date and time the certificate was
generated, thus denying some bits of information contributing to the overall
entropy used to generate the key.
- `dateutils` contains the tool `datediff`, which is used to calculate the exact
number of days between two dates. Useful for long periods of time like the 20
year validity of a Root Certificate.
- `yubikey-manager` is used to reset, generate private keys, and
copy the signed certificate to the Yubikey.
- `yubico-piv-tool` is used to configure the management key, PIN, and PIN unlock
key. This can be done from `yubikey-manager`, but changing the management key
using that is obnoxious due to length of the default key, which must be provided
to change it.

## Prepare CA Storage

Insert your USB drive and use `lsblk` to get the device id.

```sh
$ lsblk
NAME        MAJ:MIN  RM   SIZE  RO  TYPE  MOUNTPOINTS
. . .
sdb           8:16    1  28.7G   0  disk  
└──sdb1       8:17    1  28.7G   0  part  /run/media/$USER/14F4-0530
. . .
```

USB drives generally automount on Fedora Workstation, so be sure to unmount it
before doing anything with it.

```sh
umount /dev/sdb1
```

Next, use `fdisk` to wipe the drive and create two partitions, one 64MB, and the
other using the rest of the available space. Do this with a one-liner instead of
the interactive prompt. Single quotes without spaces (`''`) denote an ++enter++
keystroke.

```sh
printf '%s\n' g n '' '' +64M n '' '' '' w | sudo fdisk /dev/sdb
```

The commands equate to:

- `g` - Create a new GPT partition table
- `n` - Create a new partition
- `''` - Partition number, use default 1
- `''` - First sector, use default: beginning of drive
- `+64M` - Last sector, set as 64MB after first sector
- `n` - Create a new partition
- `''` - Partition number, use default 2
- `''` - First sector, use default: first available after previous partition
- `''` - Last sector, use default: remaining available space on drive
- `w` - Write partition table and exit

Running `lsblk` again will show the new drive structure.

```sh
$ lsblk
NAME        MAJ:MIN  RM   SIZE  RO  TYPE  MOUNTPOINTS
. . .
sdb           8:16    1  28.7G   0  disk
├──sdb1       8:17    1    64M   0  part
└──sdb2       8:18    1  28.6G   0  part
. . .
```

### Secrets Partition

Next, encrypt the 64MB partition using LUKS. Make sure the passphrase is
sufficiently long (<= 512 characters), but easy to remember.

??? quote "Obligatory XKCD"
    ![XKCD 936](https://imgs.xkcd.com/comics/password_strength.png){title="To anyone who understands information theory and security and is in an infuriating argument with someone who does not (possibly involving mixed case), I sincerely apologize."}

```sh
$ sudo cryptsetup luksFormat /dev/sdb1

WARNING!
========
This will overwrite data on /dev/sdb1 irrevocably.

Are you sure? (Type 'yes' in capital letters): YES
Enter passphrase for /dev/sdb1:
Verify passphrase:
```

Open the new LUKS partition and map it:

```sh
sudo cryptsetup open /dev/sdb1 yubirootsec
```

Next step is to format the partition. I chose FAT32 for both since I don't need
anything fancy, and a bit of added "security" of not being able to set execute
bits.

```sh
sudo mkfs.vfat -v -F 32 -n YUBIROOTSEC /dev/mapper/yubirootsec
```

Finally, close the device. We're going to remove and reinsert it after
formatting the data partition so Gnome will mount the drive in your user space,
sparing the need to use `sudo` for every command. Other desktop environments may
do something similar, but I have not tried so YMMV.

```sh
sudo cryptsetup close yubirootsec
```

### CA Data Partition

As before, format the partition as FAT32.

```sh
sudo mkfs.vfat -v -F 32 -n ROOTCA /dev/sdb2
```

Now remove and reinsert the drive. You should be prompted for the LUKS
partition's passphrase. The drives will be mounted using the filesystem labels
under `/run/media/$USER/`:

- `/run/media/$USER/ROOTCA`
- `/run/media/$USER/YUBIROOTSEC`

## Prepare Yubikey

Change into the `YUBIROOTSEC` directory:

```sh
cd /run/media/$USER/YUBIROOTSEC
```

Generate the secrets used to manage the Yubikey and PIV slots.

```sh
export LC_CTYPE=C
```

```sh
( \
    dd if=/dev/urandom 2>/dev/null | \
    tr -d '[:lower:]' | \
    tr -cd '[:xdigit:]' | \
    fold -w48 | \
    head -1 \
) > KEY
```

```sh
( \
    dd if=/dev/urandom 2>/dev/null | \
    tr -cd '[:digit:]' | \
    fold -w6 | \
    head -1 \
) > PIN
```

```sh
( \
    dd if=/dev/urandom 2>/dev/null | \
    tr -cd '[:digit:]' | \
    fold -w8 | \
    head -1 \
) > PUK
```

Reset the Yubikey to factory settings.

!!! danger
    ***If you've previously used this Yubikey, make sure you don't need any of
    the certificates, or you have backups elsewhere.***

```sh
ykman piv reset
```

Apply the secrets you just generated to the Yubikey.

```sh
yubico-piv-tool -a set-mgm-key -n $(cat KEY)
```

```sh
yubico-piv-tool -a change-pin -k $(cat KEY) -P 123456 -N $(cat PIN)
```

```sh
yubico-piv-tool -a change-puk -k $(cat KEY) -P 12345678 -N $(cat PUK)
```

## Generate Root CA Key

There are two ways to do this. I've done both, but for my uses prefer "The Risky
Way".

=== "The Risky Way"
    I generated my private key on the Yubikey so that it never touches the
    outside world.

    ```sh
    ykman piv keys generate -a ECCP384 -m $(cat KEY) -P $(cat PIN) 9a -
    ```

    This is a bit risky since if something happens to the Yubikey, then I'll
    have to order a new one and redeploy the entire PKI. If you prefer to have a
    backup, see "*The Safer Way*".

=== "The Safer Way"
    To ensure the safety of your private key, get another pair of USB drives,
    encrypt them, then generate it using OpenSSL.

    ```sh
    openssl genpkey \
    -algorithm ec \
    -pkeyopt ec_paramgen_curve:P-384 \
    -pkeyopt ec_param_enc:named_curve \
    -aes256
    -out root_ca.key.pem
    ```

    Import the key to the Yubikey.

    ```sh
    ykman piv keys import -m $(cat KEY) -P $(cat PIN) 9a root_ca.key.pem
    ```

## Setup CA Directory

Change to the `ROOTCA` partition.

```sh
cd /run/media/$USER/ROOTCA
```

Create the file structure.

```sh
mkdir ca certs crl db
```

Generate required files.

```sh
( \
    dd if=/dev/urandom 2>/dev/null | \
    tr -d '[:lower:]' | \
    tr -cd '[:xdigit]' | \
    fold -w 40 | \
    head -1 \
) > db/root_ca.crt.srl
```

```sh
echo 1000 > db/root_ca.crl.srl
```

```sh
touch db/root_ca.db{,.attr}
```

Create the following three files:

```ini title="openssl.cnf"
--8<-- "docs/lab/root-ca/openssl.cnf"
```

```sh title="rootalias"
--8<-- "docs/lab/root-ca/rootalias"
```

```sh title="norootalias"
--8<-- "docs/lab/root-ca/norootalias"
```

The `ROOTCA` directory should look like this now:

```sh
.
├── ca
├── certs
├── crl
├── db
│   ├── root_ca.crl.srl
│   ├── root_ca.crt.srl
│   ├── root_ca.db
│   └── root_ca.db.attr
├── norootalias
├── openssl.cnf
└── rootalias
```

## Generate Root Certificate

```sh
source rootalias
```

```sh
openssl req -new \
-config openssl.cnf \
-engine pkcs11 \
-keyform engine \
-key "pkcs11:id=%01;type=private" \
-passin file:/run/media/$USER/YUBIROOTSEC/PIN \
-out ca/root_ca.csr.pem
```

```sh
alias fudge="TZ=GMT datefudge -s '2022-01-01' $@"
EXP=$(fudge date -d '20 years' '+%Y-%m-%s')
DAYS=$(fudge datediff now $EXP)
```

```sh
fudge rootca \
-selfsign \
-notext \
-passin file:/run/media/$USER/YUBIROOTSEC/PIN \
-in ca/root_ca.csr.pem \
-out ca/root_ca.csr.pem \
-extensions root_ca_ext \
-days $DAYS
```

```sh
ykman piv certificates import \
-m $(cat /run/media/$USER/YUBIROOTSEC/KEY) \
-P $(cat /run/media/$USER/YUBIROOTSEC/PIN) \
9a \
ca/root_ca.crt.pem
```

```sh
ykman piv info
```

```sh
openssl x509 -in ca/root_ca.crt.pem -out ca/root_ca.crt -outform der
```

## Generate CRL

```sh
rootca -gencrl -passin file:/run/media/$USER/YUBIROOTSEC/PIN | \
openssl crl -outform der -out crl/root_ca.crl
```

## Signing Issuing/Intermediate CA

```sh
rootca \
-notext \
-passin file:/run/media/$USER/YUBIROOTSEC/PIN \
-in intermediate_ca.csr \
-out intermediate_ca.crt.pem \
-extensions issuing_ca_ext
```

Make sure the Distinguished Name in the request matches the policy in
`openssl.cnf`, in my case:

- `domainComponent` / `DC` must be set
- `countryName` / `C` must be `US`
- `organizationName` / `O` must be `DoubleU Labs`
- `commonName` / `CN` must be set

## Sync Backup USB

## Cleanup

```sh
source norootalias
```

Unmount the USB partitions from Gnome Files, or with the following:

```sh
umount /run/media/$USER/{ROOTCA,YUBIROOTSEC}
```

```sh
sudo cryptsetup close $(lsblk -o NAME /dev/sdb | grep -oe "luks.*")
```

[^1]: [https://www.openssl.org/](https://www.openssl.org/){target=_blank rel="nofollow noopener noreferrer"}
[^2]: [https://smallstep.com/certificates/](https://smallstep.com/certificates/){target=_blank rel="nofollow noopener noreferrer"}
[^3]: [https://www.freeipa.org/](https://www.freeipa.org/){target=_blank rel="nofollow noopener noreferrer"}
[^4]: [https://www.yubico.com/product/yubikey-5-nano/](https://www.yubico.com/product/yubikey-5-nano/){target=_blank rel="nofollow noopener noreferrer"}