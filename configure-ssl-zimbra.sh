#!/bin/bash

# SSL certificate installation in Zimbra
# with SSL certificate provided by Let's Encrypt (letsencrypt.org)
# Author: Subhash (serverkaka.com)

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

read -p 'letsencrypt_email [xx@xx.xx]: ' letsencrypt_email
read -p 'mail_server_url [xx.xx.xx]: ' mail_server_url

# Check All variable have a value
if [ -z $mail_server_url ] || [ -z $letsencrypt_email ]
then
      echo run script again please insert all value. do not miss any value
else

# Installation start
# Stop the jetty or nginx service at Zimbra level
su - zimbra -c 'zmproxyctl stop'
su - zimbra -c 'zmmailboxdctl stop'

# Install git and letsencrypt
cd /opt/
apt-get install git
git clone https://github.com/letsencrypt/letsencrypt
cd letsencrypt

# Get SSL certificate
./letsencrypt-auto certonly --standalone --non-interactive --agree-tos --email $letsencrypt_email -d $mail_server_url --hsts
cd /etc/letsencrypt/live/$mail_server_url
cat <<EOF >>chain.pem
-----BEGIN CERTIFICATE-----
MIIDSjCCAjKgAwIBAgIQRK+wgNajJ7qJMDmGLvhAazANBgkqhkiG9w0BAQUFADA/
MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT
DkRTVCBSb290IENBIFgzMB4XDTAwMDkzMDIxMTIxOVoXDTIxMDkzMDE0MDExNVow
PzEkMCIGA1UEChMbRGlnaXRhbCBTaWduYXR1cmUgVHJ1c3QgQ28uMRcwFQYDVQQD
Ew5EU1QgUm9vdCBDQSBYMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AN+v6ZdQCINXtMxiZfaQguzH0yxrMMpb7NnDfcdAwRgUi+DoM3ZJKuM/IUmTrE4O
rz5Iy2Xu/NMhD2XSKtkyj4zl93ewEnu1lcCJo6m67XMuegwGMoOifooUMM0RoOEq
OLl5CjH9UL2AZd+3UWODyOKIYepLYYHsUmu5ouJLGiifSKOeDNoJjj4XLh7dIN9b
xiqKqy69cK3FCxolkHRyxXtqqzTWMIn/5WgTe1QLyNau7Fqckh49ZLOMxt+/yUFw
7BZy1SbsOFU5Q9D8/RhcQPGX69Wam40dutolucbY38EVAjqr2m7xPi71XAicPNaD
aeQQmxkqtilX4+U9m5/wAl0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNV
HQ8BAf8EBAMCAQYwHQYDVR0OBBYEFMSnsaR7LHH62+FLkHX/xBVghYkQMA0GCSqG
SIb3DQEBBQUAA4IBAQCjGiybFwBcqR7uKGY3Or+Dxz9LwwmglSBd49lZRNI+DT69
ikugdB/OEIKcdBodfpga3csTS7MgROSR6cz8faXbauX+5v3gTt23ADq1cEmv8uXr
AvHRAosZy5Q6XkjEGB5YGV8eAlrwDPGxrancWYaLbumR9YbK+rlmM6pZW87ipxZz
R8srzJmwN0jP41ZL9c8PDHIyh8bwRLtTcm1D9SZImlJnt1ir/md2cXjbDaJWFBM5
JDGFoqgCWjBH4d1QB7wCCZAA62RjYJsWvIjJEubSfZGL+T0yjWW06XyxV3bqxbYo
Ob8VZRzI9neWagqNdwvYkQsEjgfbKbYK7p2CNTUQ
-----END CERTIFICATE-----
EOF

# Verify commercial certificate
mkdir /opt/zimbra/ssl/letsencrypt
cp /etc/letsencrypt/live/$mail_server_url/* /opt/zimbra/ssl/letsencrypt/
chown zimbra:zimbra /opt/zimbra/ssl/letsencrypt/*
ls -la /opt/zimbra/ssl/letsencrypt/
su - zimbra -c 'cd /opt/zimbra/ssl/letsencrypt/ && /opt/zimbra/bin/zmcertmgr verifycrt comm privkey.pem cert.pem chain.pem'

# Deploy the new Let's Encrypt SSL certificate
cp -a /opt/zimbra/ssl/zimbra /opt/zimbra/ssl/zimbra.$(date "+%Y%m%d")
cp /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/zimbra/commercial/commercial.key
sudo chown zimbra:zimbra /opt/zimbra/ssl/zimbra/commercial/commercial.key
su - zimbra -c 'cd /opt/zimbra/ssl/letsencrypt/ && /opt/zimbra/bin/zmcertmgr deploycrt comm cert.pem chain.pem'

# Restart Zimbra
su - zimbra -c 'zmcontrol restart'

# setting auto https redirect
cd /opt && touch https-redirect.sh && chown zimbra:zimbra https-redirect.sh && chmod +x https-redirect.sh
cat <<EOF >>/opt/https-redirect.sh
zmprov ms $mail_server_url zimbraReverseProxyMailMode redirect
EOF
su - zimbra -c '/opt/https-redirect.sh'
rm /opt/https-redirect.sh
fi
