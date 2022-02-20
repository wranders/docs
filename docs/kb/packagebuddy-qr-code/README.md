# Package-Buddy QR Code

This will show how to generate QR codes compatible with the PackageBuddy package
tracking application.

I love this application, but it hasn't been updated since about 2013. So this is
in anticipation of the application's website going offline and the convenient QR
code generator[^1] with it.

## Example QR Code

```sh
█████████████████████████████████████
█████████████████████████████████████
████ ▄▄▄▄▄ █▄▄████ █ ▀██▄█ ▄▄▄▄▄ ████
████ █   █ █ ▀█ ▄ ▀█▄▀█▀ █ █   █ ████
████ █▄▄▄█ █▄ ▄▄▀▀▀▄ ▄█▀▀█ █▄▄▄█ ████
████▄▄▄▄▄▄▄█▄▀▄▀▄█ ▀▄▀ ▀▄█▄▄▄▄▄▄▄████
████ ▄▄ ▀▀▄▀▄▀███▀▄█▀▄ █ ▄▀█ ▄▄█ ████
████ ▀█▀▀█▄█▄██▀▀▀ ▀ █▀▀▄█▀█▀ ▄██████
████ ▄▀▄▀█▄█  ▀ █   ▀▄█ ▄▀█ █▄   ████
████▄ █ ▄█▄▀█▄██ █ ██▄█▄ ▄▀██▄▄▀ ████
██████▀██ ▄███▀▄▀▄█▀▄█▄█  ▀█▄ █▀▀████
████▄█ █▄▄▄ ▄▀ ▄ ▄ ▄ ▀ ██▀ ▄█▄ ▀█████
█████▄█▄▄█▄▄▀█▄▄   █ ▄ ▄ ▄▄▄ ▀▄█▄████
████ ▄▄▄▄▄ ██▄▀▄▄ ▀███ ▄ █▄█ ▀▄ █████
████ █   █ █▀▄ ▀ ▀▄▄▀ █▀  ▄▄   ▄ ████
████ █▄▄▄█ █ ██ ██ ▀▄█▄█▀██████▀▄████
████▄▄▄▄▄▄▄█▄▄████▄████▄▄█▄██▄█▄█████
█████████████████████████████████████
█████████████████████████████████████
```

## Generation Command

```sh
TRACKINGNUM="1234567890"
CARRIERSLUG="fedex"
DESCRIPTION="Package Description"
qrencode -t utf8 -8 "QR:${TRACKINGNUM}__${CARRIERSLUG}__${DESCRIPTION}__"
```

### Supported Carriers

| Carrier Slug      | Carrier Name                  |
| :-                | :-                            |
| a1                | A-1 International             |
| adrexo            | Adrexo                        |
| aero              | Aeronet                       |
| air21             | Air21                         |
| aacargo           | American Airlines Cargo       |
| amerijet          | AmeriJet                      |
| anpost            | An Post                       |
| aramex            | Aramex                        |
| argix             | Argix Direct                  |
| ats               | ATS Solutions                 |
| auspost           | Australia Post                |
| ausair            | Australian Air Express        |
| belginpost        | Belgin Post                   |
| belpost           | Belpost                       |
| canadapost        | Canada Post                   |
| ceva              | CEVA                          |
| chronopost        | Chornopost                    |
| citylink          | City Link                     |
| colissimo         | Colissimo                     |
| collectplus       | Collect Plus                  |
| ccargo            | Continental Cargo             |
| correiosbr        | Correios Brazil               |
| correoscl         | Correos Chile                 |
| correosec         | Correos del Ecuador           |
| correoses         | Correos Spain                 |
| couriernz         | Courier Post (NZ)             |
| cttportugal       | CTT Portugal                  |
| cypruspost        | Cyprus Post                   |
| db                | DB Schenker                   |
| dbprivpak         | DB Schenker Privpak           |
| delta             | Delta Cargo                   |
| dhl               | DHL                           |
| dhlacg            | DHL ACG                       |
| dhlbr             | DHL Brazil                    |
| dhlca             | DHL Canada                    |
| dhlde             | DHL DE                        |
| dhlgm             | DHL GM                        |
| dhlpl             | DHL Poland                    |
| dhlsame           | DHL Same Day                  |
| dhles             | DHL Spain                     |
| dhlse             | DHL Sweden                    |
| dhluk             | DHL UK                        |
| dpd               | DPD                           |
| dpdie             | DPD Ireland                   |
| dpdpl             | DPD Poland                    |
| dpduk             | DPD UK                        |
| directfreight     | Direct Freight Express        |
| dynamex           | Dynamex                       |
| empost            | Empost                        |
| ensenda           | Ensenda                       |
| expeditors        | Expeditors                    |
| fedex             | FedEx                         |
| fedexuk           | FedEx UK                      |
| flyt              | Flyt Express                  |
| forward           | Forward Air                   |
| gls               | GLS                           |
| gso               | GSO                           |
| hdnl              | HDNL                          |
| hermes            | Hermes                        |
| hermesuk          | Hermes UK                     |
| hongkongpost      | Hong Kong Post                |
| iparcel           | i-parcel                      |
| interlink         | Interlink                     |
| irishpost         | Irish Post                    |
| israelpost        | Israel Post                   |
| itella            | Itella                        |
| japanems          | Japan Post                    |
| korea             | Korea Post                    |
| laser             | Lasership                     |
| lbc               | LBC Express                   |
| luxpost           | Luxembourg Post               |
| magyar            | Magyar Post                   |
| mailexpress       | Mail Express                  |
| matkahuolto       | Matkahuolto                   |
| metrowide         | Metrowide Courier Express     |
| mrw               | MRW ES                        |
| newgistics        | Newgistics                    |
| ocs               | OCS                           |
| olddom            | Old Dominion                  |
| ontrac            | OnTrac                        |
| parcelforce       | Parcel Force                  |
| polish            | Poczta Polska                 |
| ponyexpress       | PonyExpress Post              |
| indonesianpost    | Pos Indonesia                 |
| posindonesia      | Pos Indonesia (Registered)    |
| poslaju           | Pos Laju                      |
| posdaftar         | Pos Malaysia (Pos Daftar)     |
| posmalaysia       | Pos Malaysia                  |
| postat            | Post Austria                  |
| postde            | Post Denmark                  |
| postnl            | Post NL                       |
| postenno          | Posten.no                     |
| postense          | Posten.se                     |
| ppl               | PPL                           |
| prestige          | Prestige                      |
| purolator         | Purolator                     |
| quick             | Quick International           |
| randl             | R & L Carriers                |
| royalmail         | Royal Mail                    |
| saudipost         | Saudi Post                    |
| servientrega      | Servientrega                  |
| singapore         | Singapore Post                |
| sefreight         | Southeast Freight             |
| startrack         | Star Track Express            |
| streamlite        | Streamlite                    |
| swiss             | Swiss Post                    |
| teamww            | Team Worldwide                |
| tnt               | TNT                           |
| tntau             | TNT Express Australia         |
| tntpostnl         | TNT Post NL                   |
| tntuk             | TNT UK                        |
| toll              | Toll IPEC                     |
| tollpost          | Tollpost                      |
| turkey            | Turkish Post                  |
| ucs               | UCS                           |
| ukmail            | UKMail                        |
| ukraine           | Ukrposhta                     |
| ups               | UPS                           |
| upsair            | UPS Air Cargo                 |
| upsmi             | UPS Mail Innovations          |
| upslns            | UPS Supply Chain Solutions    |
| usps              | USPS                          |
| xend              | Xend                          |
| yodel             | Yodel                         |
| yrc               | YRC                           |

### Unsupported Carriers

| Carrier Slug  | Carrier Name  |
| :-            | :-            |
| chinapost     | China Post    |
| russia        | Russian Post  |

[^1]: [http://www.package-buddy.com/code](http://www.package-buddy.com/code){target=_blank rel="nofollow noopener noreferrer"}
