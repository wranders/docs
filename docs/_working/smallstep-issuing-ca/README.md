# Smallstep Issuing CA

Builds on the [Lab Root CA](/lab/root-ca/){target=_blank rel="nofollow noopener noreferrer"}.

## Setup

```sh
randpass(){ \
    dd if=/dev/urandom 2>/dev/null | \
    tr -cd '[:alnum:]' | \
    fold -w64 | \
    head -1;
}
```

```sh
randpass 64 > password.txt
randpass 64 > provisioner-password.txt
```

```sh
step ca init \
--deployment-type standalone \
--name "DoUbleU Home Issuing CA 01" \
--dns localhost,$(hostname),pki.home.doubleu.codes \
--address ":443" \
--provisioner "home.doubleu.codes" \
--password-file password.txt \
--provisioner-password-file provisioner-password.txt
```

```sh
rm certs/* secrets/*
```

Copy PEM encoded root certificate to `certs/root_ca.crt`.

```sh
openssl genpkey \
-algorithm ec \
-pkeyopt ec_paramgen_curve:P-384 \
-pkeyopt ec_param_enc:named_curve | \
openssl ec -aes256 \
-passout file:password.txt \
-out secrets/intermediate_ca_key
```

```sh
openssl req -new \
-subj "/CN=DoubleU Home Issuing CA 01/O=DoubleU Labs/C=US/DC=home/DC=doubleu/DC=codes" \
-key secrets/intermediate_ca_key \
-passin file:password.txt \
-out certs/intermediate_ca.csr
```

```sh
source /run/media/$USER/ROOTCA/activate
```

```sh
rootca \
-passin file:/run/media/$USER/YUBIROOTSEC/PIN \
-in certs/intermediate_ca.csr \
-out certs/intermediate_ca.crt \
-extensions issuing_ca_ext \
-notext
```

```json title="templates/leaf.tpl"
{
  "subject": {
    "commonName": {{ toJson .Subject.CommonName }},
    "country": {{ toJson .Country }},
    "organization": {{ toJson .Organization }},
    "organizationalUnit": {{ toJson .OrganizationalUnit }}
  },
{{- if .SANs }}
  "sans": {{ toJson .SANs }},
{{- end }}
{{- if typeIs "*rsa.PublicKey" .Insecure.CR.PublicKey }}
  "keyUsage": [ "keyEncipherment", "digitalSignature" ],
{{- else }}
  "keyUsage": [ "digitalSignature" ],
{{- end }}
  "extKeyUsage": [ "serverAuth", "clientAuth" ],
  "ocspServer": {{ toJson .OCSPServer }},
  "issuingCertificateURL": {{ toJson .IssuingCA }},
  "crlDistributionPoints": {{ toJson .CDP }}
}
```

```json title="config/ca.json" hl_lines="9-26"
{
  . . .
  "authority": {
    "provisioners": [
      {
        "type": "JWK",
        "name": "home.doubleu.codes",
        . . .
        "claims": {
          "minTLSCertDuration": "24h",
          "maxTLSCertDuration": "43800h",
          "defaultTLSCertDuration": "17520h"
        },
        "options": {
          "x509": {
            "templateFile": "templates/leaf.tpl",
            "tempalteData": {
              "Country": "US",
              "Organization": "DoubleU Labs",
              "OrganizationalUnit": "Home",
              "OCSPServer": "http://pki.home.doubleu.codes/ocsp",
              "IssuingCA": "http://pki.home.doubleu.codes/ca/intermediate_ca.crt",
              "CDP": "http://pki.home.doubleu.codes/ca/intermediate_ca.crl"
            }
          }
        }
      }
    ]
  }
}
```

```sh
step-ca \
--password-file password.txt \
config/ca.json 
```

```sh
ROOTFP=$(
step certificate fingerprint certs/root_ca.crt
)
step ca bootstrap --force \
--ca-url https://localhost/ \
--fingerprint $ROOTFP
```

## Request Certificate

### Directly

```sh
mkdir svc
```

```sh
TOKEN=$(
step ca token \
--password-file provisioner-password.txt \
svc.home.doubleu.codes
)
step ca certificate \
--token $TOKEN \
svc.home.doubleu.codes \
svc/svc.crt \
svc/svc.key
```

### CSR

```sh
mkdir svc
```

```sh
step certificate create --csr \
--no-password --insecure \
svc.home.doubleu.codes \
svc/svc.csr \
svc/svc.key
```

```sh
TOKEN=$(
step ca token \
--password-file provisioner-password.txt \
svc.home.doubleu.codes
)
step ca sign \
--token $TOKEN \
svc/svc.csr \
svc/svc.crt
```
