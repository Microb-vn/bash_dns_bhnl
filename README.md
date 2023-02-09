# Bhosted DNS script to be used by acme.sh

My challenge was to create custom (and ideally ) wildcard certificates for Synology NAS using acme.sh and its DNS-01 challenge method. Synology only supports the creating certificates using the HTTP(s) challenge method.

For me, to use acme.sh for my synology, this ONLY required a special script to update DNS to create temporary acme-challenge TXT records following the methods as prescribed by acme.sh. As I am with the Internet Hosting company called bhosted (bhosted.nl) - which also hosts my DNS - , and there was no dsn script available for this provider, I developed a script that execute the DNS challenge API calls that are required for acme.sh.

**Please note that this repo only contains the DNS script that should be used as part of acme.sh.**

 For generic information using acme.sh - the main script to request and manage (letsencrypt) certificates, see github https://github.com/acmesh-official/acme.sh 

 For using acme.sh on Synology NAS, I also used this article: https://lippertmarkus.com/2020/03/14/synology-le-dns-auto-renew/


# How to use the DNS script in acme.sh:

- Download and install/activate acme.sh on your device.
- follow the instructions to add the dns-bhnl.sh to the proper location in the acme.sh folder. I added it to folder ../acme.sh/dnsapi/
- Before running your acme.sh script for the first time to request your certificate, set the following environment variables:
    - export BHNL_Account=\<your bhosted userID\> 
    - export BHNL_Password=\<your bhosted hashed password\> # see bhosted.nl for more info. 
    - export BHNL_sld=\<your sublevel domain\> # e.g mydomain
    - export BHNL_tld=\<your top level domain\> # e.g. nl
- register you public IP address in the bhosted control panel (see bhosted.nl for more info)
- Call acme.sh using parameter --dns dns_bhnl (and all other parameters you need for your domain)

My issue request for my wildcard certificate looked like this:

```bash
cd /usr/local/share/acme.sh
# set environment variables for your DNS provider and your used DNS API
export BHNL_Account=mycaccount
export BHNL_Password=MYHASHEDPASSWORD
export BHNL_sld=mydomain
export BHNL_tld=com
./acme.sh --issue -d "mydomain.com" -d "*.mydomain.com" --dns dns_bhnl --home $PWD --server letsencrypt
```

followed by a deployment on my synology NAS:

```bash
# set deployment options, see https://github.com/acmesh-official/acme.sh/wiki/deployhooks#20-deploy-the-cert-into-synology-dsm
export SYNO_Scheme="http"  # Can be set to HTTPS, defaults to HTTP
export SYNO_Hostname="mysynology.local"  # Specify if not using on localhost
export SYNO_Port="myport"  # Port of DSM WebUI, defaults to 5000 for HTTP and 5001 for HTTPS
export SYNO_Username="mydamin"
export SYNO_Password="myadminpassword"
export SYNO_Certificate="my certificate (wildcart created with acme.sh)"  # description text shown in Control Panel ➡ Security ➡ Certificate
export SYNO_Create=1  # create certificate if it doesn't exist
export SYNO_DID="myMFA-did"
./acme.sh -d "mydomain.com" --deploy --deploy-hook synology_dsm --home $PWD
```

And that worked! I assigned the wildcart certificate the "default" attribute in DSM and allocated the certificate to all my websites. I also scheduled a "renew" action using the Synology DSM Task Scheduler (see https://lippertmarkus.com/2020/03/14/synology-le-dns-auto-renew/
)
