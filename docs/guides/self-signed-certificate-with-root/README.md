# Self-Signed Certificate with Root

## Why

If you're installing a web-based service that won't be internet accessible and
you can't use Let's Encrypt[^1], self-signed certificates are commonly used.
But, many are annoyed by the trust errors that modern browsers display when
accessing them.

Some don't want to go through the process of setting up a full-blown certificate
authority (CA), especially in a home setting, but certificates without roots
cannot be installed, so to avoid certificate trust errors a root certificate
authority is needed.

We'll set up a small certificate authority using OpenSSL[^2] for our service.

!!! Warning
    This shouldn't be used for anything outside of self-hosted services that
    aren't internet facing. This guide will not include certificate revocation
    lists (CRL) or Online Certificate Status Protocol (OCSP). Internet-facing
    services should really include a way to publish a list of revoked
    certificates.

## Directory Setup

Create the directories for the root CA. I'm using `/etc/ssl/private` as the base
directory and I'm using the `root` user to do this, but you can use `sudo`.

```sh
mkdir -p /etc/ssl/private/root/{certs,csr,newcerts,private}
```

```sh
chmod 700 /etc/ssl/private/root/private
```

Create the `index.txt` and `serial` files:

```sh
touch /etc/ssl/private/root/index.txt
```

```sh
echo 1000 | tee /etc/ssl/private/root/serial
```

## Configuration

Next, create the OpenSSL configuration for the root CA:

```sh hl_lines="57 58" title="/etc/ssl/private/root/openssl.conf"
--8<-- "docs/guides/self-signed-certificate-with-root/config/openssl.conf"
```

!!! Danger "Critical"
    Edit the highlighted lines above to reflect the URL and IP address your
    service will be accessible by.

## Root CA Pair Generation

Generate the root CA's private key:

```sh
openssl genrsa -aes256 -out /etc/ssl/private/root/private/cakey.pem 4096
```

You will be prompted for a password. Remember this as it will be needed to
create the root's certificate and later to sign the service's certificate.

```sh
chmod 400 /etc/ssl/private/root/cakey.pem
```

Create the root CA certificate:

```sh hl_lines="7"
openssl req -new -x509 -sha256 \
  -extensions v3_ca \
  -days 3650 \
  -config /etc/ssl/private/root/openssl.conf \
  -key /etc/ssl/private/root/private/cakey.pem \
  -out /etc/ssl/private/root/certs/cacert.pem \
  -subj "/CN=My Service Root CA"
```

This above highlighted line can be changed to anything you want.

```sh
chmod 444 /etc/ssl/private/root/certs/cacert.pem
```

## Service Pair Generation

Next, create the private key for your service:

```sh
openssl genrsa -out /etc/ssl/private/root/private/my-service.pem 2048
```

```sh
chmod 400 /etc/ssl/private/root/private/my-service.pem
```

Create a certificate signing request (CSR) for your service:

```sh hl_lines="3 6"
openssl req -new \
  -config /etc/ssl/private/root/openssl.conf \
  -key /etc/ssl/private/root/private/my-service.pem \
  -out /etc/ssl/private/root/csr/my-service.csr \
  -reqexts req_server \
  -subj "/CN=myservice.example.local"
```

If you used a different file name for the private key, make sure it's reflected,
and make sure the last line (`-subj`) reflects the domain name used in
`openssl.conf` for your service. Modern browsers may display errors if these
domain names do not match.

Sign the CSR:

```sh hl_lines="4 5"
openssl ca -notext \
  -extensions v3_server \
  -config /etc/ssl/private/root/openssl.conf \
  -in /etc/ssl/private/root/csr/my-service.csr \
  -out /etc/ssl/private/root/certs/my-service.pem
```

Make sure the file names for the CSR and certificate are correct.

Enter the password for the root CA private key, then `y` to sign the
certificate, then `y` again to commit.

```sh
chmod 444 /etc/ssl/private/root/certs/my-service.pem
```

## Make Available

Copy the service's private key to the directory oyur service will use:

```sh
cp /etc/ssl/private/root/private/my-service.pem \
  /etc/ssl/private/my-service/key.pem
```

The same can be done for the service's certificate and root CA certificate.

```sh
cp /etc/ssl/private/root/certs/my-service.pem \
  /etc/ssl/private/my-service/cert.pem
```

```sh
cp /etc/ssl/private/root/certs/cacert.pem \
  /etc/ssl/private/my-service/cacert.pem
```

If your service only takes a single certificate and key, the root CA certificate
will need to be appended to the service's certificate:

```sh
cat /etc/ssl/private/my-servie/cacert.pem | \
  tee -a /etc/ssl/private/my-service/cert.pem >/dev/null
```

If your service only takes a single file containing the whole chain, including
the private key, append the chained certificate above to the key file:

```sh
cat /etc/ssl/private/my-service/cert.pem | \
  tee -a /etc/ssl/private/my-service/key.pem >/dev/null
```

[^1]: [https://letsencrypt.org/](https://letsencrypt.org/){target=_blank rel="nofollow noopener noreferrer"}
[^2]: [https://www.openssl.org/](https://www.openssl.org/){target=_blank rel="nofollow noopener noreferrer"}
