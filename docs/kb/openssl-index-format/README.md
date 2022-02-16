# OpenSSL Index Format

Each line is a tab-delimited list of certificates and their related information.

```sh
{TYPE}\t{EXPIRES}\t{REVOKED}\t{SERIAL}\t{FILENAME}\t{SUBJECT}
```

| Key           | Value                                                         |
| :-            | :-                                                            |
| `TYPE`        | <li>V (Valid)</li><li>R (Revoked)</li><li>E (Expired)</li>    |
| `EXPIRES`     | Expiration DateTime, UTC/Z (`%y%m%d%H%M%SZ`, `yymmddHHMMSSZ`) |
| `REVOKED`     | Revocation DateTime, UTC/Z (`%y%m%d%H%M%SZ`, `yymmddHHMMSSZ`) |
| `SERIAL`      | Certificate Serial Number                                     |
| `FILENAME`    | Filename, or `unknown`                                        |
| `SUBJECT`     | Certificate Subject Name                                      |

Raw file:

```txt
R    220123230539Z    220122231135Z    143297E5CF148559B5F4F87F9E03F1A6    unknown    CN=localhost
V    220123230539Z        BDD5E71ED14467B6336D0B2B0A333FE2    unknown    CN=localhost
```

| Type  | Expires       | Revoked       | Serial                            | Filename  | Subject       |
| :-    | :-            | :-            | :-                                | :-        | :-            |
| R     | 220123230539Z | 220122231135Z | 143297E5CF148559B5F4F87F9E03F1A6  | unknown   | CN=localhost  |
| V     | 220123230539Z |               | BDD5E71ED14467B6336D0B2B0A333FE2  | unknown   | CN=localhost  |
