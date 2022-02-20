# OpenSSL Request Active Directory Certificate Services

Active Directory Certificate Services requires the Template Name to be submitted
with the request.

## Request using OpenSSL configuration

To accomplish this with OpenSSL, use the `1.3.6.1.4.1.311.20.2` OID as part of
the request extensions with the value of `ASN1:UTF8String:<template name>`.

For example, to request a certificate using the `WebServices` template, use:

```ini
1.3.6.1.4.1.311.20.2 = ASN1:UTF8String:WebServices
```

Edit the following request template:

```ini title="myservice.example.com.cnf"
--8<-- "docs/guides/openssl-req-adcs/config/myservice.example.com.conf"
```

Then create your private key and CSR with the following command:

```sh
openssl req -new -nodes \
  -keyout service.key \
  -out service.csr \
  -config myservice.example.com.cnf
```

Verify the requst using:

```sh
openssl req -noout -text -in service.csr
```

```sh
Certificate Request:
    Data:
        Version: 1 (0x0)
        Subject: C = US, ST = Texas, L = San Antonio, O = Some Organization, OU = Some Section, CN = myservice.example.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (2048 bit)
                Modulus:
                    00:99:10:2e:52:e8:23:16:3b:b3:13:2a:b8:da:ea:
                    19:2d:17:5d:43:1a:fd:53:88:94:07:c3:a7:b3:49:
                    1b:27:74:ca:ba:21:2c:4f:72:46:1f:3b:fc:db:69:
                    01:5e:b5:00:24:d1:67:82:a8:1e:38:6d:3a:b8:4c:
                    c6:a8:63:f1:b7:3b:2e:c6:04:3e:d7:a9:d4:7e:53:
                    88:2e:70:50:72:67:97:c4:df:37:71:a1:6e:e8:52:
                    6f:73:b8:95:50:15:1b:95:a6:35:9e:9f:1e:5c:99:
                    5c:64:92:60:0f:60:f6:aa:02:d3:c1:14:49:ed:cf:
                    4e:61:33:29:6b:5c:79:8b:b5:d2:2a:ac:3a:29:5c:
                    84:7c:43:ce:f4:21:5f:27:e0:7a:c1:1d:3b:e7:1b:
                    63:63:2f:a2:27:aa:5a:79:36:c3:1a:eb:3b:96:10:
                    19:08:16:21:6a:c7:2a:ed:ac:77:63:ff:ef:01:b0:
                    5e:f2:60:5e:9c:cc:1d:9c:60:49:a8:e1:4b:46:69:
                    ec:22:bd:e1:2b:37:e2:a6:42:6d:a2:f2:8f:68:5d:
                    8f:fa:5b:c8:07:d4:ef:3a:e2:51:db:3b:f4:6b:63:
                    16:11:ec:3a:9c:2b:32:12:d4:7c:c3:4d:37:c3:f4:
                    4f:a7:9e:64:4c:93:5d:35:77:3f:03:3a:21:71:0e:
                    f9:f9
                Exponent: 65537 (0x10001)
        Attributes:
        Requested Extensions:
            X509v3 Basic Constraints:
                CA:FALSE
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage:
                TLS Web Server Authentication
            X509v3 Subject Alternative Name:
                DNS:myservice.example.com
            1.3.6.1.4.1.311.20.2:
                ..ADCSTemplateName
    Signature Algorithm: sha256WithRSAEncryption
         45:7b:90:9f:9b:73:55:05:41:53:7b:44:31:d3:12:14:9a:6a:
         95:a2:7a:35:92:7f:3a:98:ba:d8:27:a6:63:4b:28:c3:5f:47:
         1b:01:44:7e:a1:b3:9b:d1:45:9b:24:58:d0:6f:d5:e3:15:a4:
         04:60:f1:52:8b:e8:09:f4:e3:54:ce:4c:32:6d:ff:81:f6:ea:
         51:ae:1f:37:21:de:4b:cc:d4:fd:4a:6e:0e:4b:cb:74:ca:6c:
         04:86:db:6f:aa:58:bc:6b:a6:ea:1c:83:0d:cb:23:02:92:94:
         8d:d3:a0:2d:c6:da:48:44:7d:ac:79:95:8c:ca:b6:bf:37:37:
         20:24:c8:c5:53:db:b8:cf:f9:85:74:de:cd:d3:56:cc:37:b0:
         7a:97:4a:c6:7d:e1:37:c4:bb:9c:b4:af:9b:5d:5b:b7:f0:af:
         23:fe:16:23:63:9c:59:2e:4f:63:41:95:ba:0b:86:35:02:79:
         98:ea:f8:6f:2d:d3:fb:30:54:bb:fe:52:b8:81:d6:dc:e6:69:
         af:2f:d3:9a:af:b0:05:ee:ef:04:59:58:8c:cb:b6:ba:cc:6c:
         08:d5:4c:96:4f:f5:76:fa:c9:78:e0:13:4a:03:65:08:f1:9c:
         e0:f5:20:ef:81:ac:a0:37:03:a3:b2:31:2e:04:f4:6a:d4:8d:
         40:53:61:57
```

Submit the Base64-encoded request file to ADCS and retrieve the certificate.

```powershell
certreq.exe -submit service.csr service.cer service.p7b
```

## Request by specifying the Template attribute

If you didn't create the CSR or can't use OpenSSL config files to generate the
request, add the attribute using `certreq`:

```powershell
certreq.exe -submit -attrib "CertificateTemplate:ADCSTemplateName" service.csr service.cer service.p7b
```

`service.cer` is the issued certificate, and `service.p7b` is the full chain file.

This information is included for posterity.

## Process Certificates

The `cer` file directly from `certreq.exe` is DER encoded. You might need them
in PEM / Base64 format.

If the full certificate chain ***IS NOT*** required:

```sh
openssl x509 -inform der -in service.cer -out service.pem
```

If the full certificate chain ***IS*** required:

```sh
openssl pkcs7 -inform der -print_certs -in service.p7b -out service.chain.pem
```
