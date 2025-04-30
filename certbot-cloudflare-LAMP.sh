#!/bin/bash

# --- BOJE ---
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m" # No Color

# Provjera da li je Certbot instaliran
if ! command -v certbot &> /dev/null
then
    echo "Certbot nije instaliran. Instaliram Certbot..."
    sudo apt update -y
    sudo apt install certbot -y
else
    echo "Certbot je već instaliran."
fi

# Provjera da li je python3-certbot-dns-cloudflare instaliran
if ! dpkg -l | grep -q python3-certbot-dns-cloudflare
then
    echo "Paket python3-certbot-dns-cloudflare nije instaliran. Instaliram..."
    sudo apt install python3-certbot-dns-cloudflare -y
else
    echo "Paket python3-certbot-dns-cloudflare je već instaliran."
fi

# --- Kreiranje /etc/certbot direktorija ako ne postoji ---
if [ ! -d "/etc/certbot" ]; then
  echo -e "${YELLOW}Direktorij /etc/certbot ne postoji. Kreiram ga...${NC}"
  sudo mkdir -p /etc/certbot
fi


# --- Cloudflare credentials fajl ---
CLOUDFLARE_CREDENTIALS="/etc/certbot/credentials"

# --- Unos Cloudflare API tokena ---
echo -e "${BLUE}Unesite Cloudflare API Token:${NC}"
read CLOUDFLARE_API_TOKEN

# --- Spremanje API tokena ---
echo -e "${YELLOW}Spremam Cloudflare API token u fajl $CLOUDFLARE_CREDENTIALS${NC}"
echo "dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN" | sudo tee $CLOUDFLARE_CREDENTIALS > /dev/null

# Postavljanje dozvola za sigurnost
sudo chmod 600 $CLOUDFLARE_CREDENTIALS

# --- Unos domene ---
echo -e "${BLUE}Unesite naziv domene ili poddomene za generisanje SSL certifikata (npr. primjer.com):${NC}"
read DOMAIN

# --- Provjera da li već postoji Apache host fajl za domenu ---
EXISTING_CONF=$(sudo grep -ril "ServerName $DOMAIN" /etc/apache2/sites-available/)

if [ -n "$EXISTING_CONF" ]; then
  echo -e "${YELLOW}Već postoji Apache konfiguracija za ovu domenu:${NC} $EXISTING_CONF"
  echo -e "${BLUE}Želite li:${NC}"
  echo -e "  [1] Koristiti postojeći fajl"
  echo -e "  [2] Ukloniti postojeći i kreirati novi fajl"
  echo -e "  [3] Prekinuti skriptu"
  read -p "Unesite opciju (1/2/3): " CHOICE

  case $CHOICE in
    1)
      APACHE_CONF="$EXISTING_CONF"
      ;;
    2)
      sudo rm -f "$EXISTING_CONF"
      echo -e "${GREEN}Stari host fajl obrisan.${NC}"
      ;;
    3)
      echo -e "${RED}Prekidam skriptu na zahtjev korisnika.${NC}"
      exit 1
      ;;
    *)
      echo -e "${RED}Neispravan izbor. Prekidam.${NC}"
      exit 1
      ;;
  esac
fi

# --- Prikaz dostupnih webroot direktorija ---
echo -e "\n${BLUE}Pronađeni webroot direktoriji:${NC}"
AVAILABLE_WEBROOTS=()

INDEX=1
for DIR in /var/www/*/ ; do
  echo "[$INDEX] $DIR"
  AVAILABLE_WEBROOTS+=("$DIR")
  ((INDEX++))
done

# --- Izbor webroot direktorija ---
echo -e "\n${BLUE}Unesi broj željenog direktorija sa liste ili upiši puni path ručno:${NC}"
read WEBROOT_CHOICE

if [[ "$WEBROOT_CHOICE" =~ ^[0-9]+$ ]]; then
  if ((WEBROOT_CHOICE > 0 && WEBROOT_CHOICE <= ${#AVAILABLE_WEBROOTS[@]})); then
    WEBROOT="${AVAILABLE_WEBROOTS[$((WEBROOT_CHOICE-1))]}"
  else
    echo -e "${RED}Neispravan izbor broja! Prekidam.${NC}"
    exit 1
  fi
else
  WEBROOT="$WEBROOT_CHOICE"
fi

# --- Provjera webroot direktorija ---
if [ ! -d "$WEBROOT" ]; then
  echo -e "${RED}Direktorij '$WEBROOT' ne postoji! Prekidam.${NC}"
  exit 1
fi

echo -e "${GREEN}Odabrani webroot:${NC} $WEBROOT"

# --- Generisanje SSL certifikata ---
echo -e "\n${YELLOW}Pokrećem certbot za $DOMAIN i www.$DOMAIN...${NC}"
sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials "$CLOUDFLARE_CREDENTIALS" -d "$DOMAIN" -d "www.$DOMAIN" --dns-cloudflare-propagation-seconds 30

if [ $? -ne 0 ]; then
  echo -e "${RED}Greška pri generisanju SSL certifikata! Prekidam.${NC}"
  exit 1
fi

# Definiraj put do fajla
SSL_OPTIONS_FILE="/etc/letsencrypt/options-ssl-apache.conf"

# Kreiranje DH parametara ako ne postoji
if [ ! -f "/etc/ssl/certs/dhparam.pem" ]; then
    echo -e "${YELLOW}Generišem Diffie-Hellman parametre. Ovo može potrajati...${NC}"
    sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
fi

sudo a2enmod ssl
sudo a2enmod headers

# Provjeri da li fajl postoji
if [ ! -f "$SSL_OPTIONS_FILE" ]; then
    # Ako fajl ne postoji, kreiram ga sa preporučenim postavkama
    echo "Fajl $SSL_OPTIONS_FILE ne postoji. Kreiram fajl sa sigurnosnim postavkama za SSL."

    # Kreiram fajl s osnovnim postavkama (možeš dodati više postavki prema potrebama)
    sudo bash -c 'cat > /etc/letsencrypt/options-ssl-apache.conf <<EOF
# SSL/TLS optimizirane postavke za Apache
# SSL/TLS optimizirane postavke za Apache
# Ove postavke osiguravaju visoku sigurnost i kompatibilnost s modernim klijentima

# Svi SSL/TLS protokoli su omogućeni, ali isključuju se SSLv2 i SSLv3 (koji su nesigurni)
SSLProtocol all -SSLv2 -SSLv3

# Podesite redoslijed ciphers prema preferencijama servera (SSLHonorCipherOrder je obavezno uključen)
SSLHonorCipherOrder on

# Omogući Forward Secrecy
# Korištenje jakih parametara za Diffie-Hellman
SSLOpenSSLConfCmd DHParameters "/etc/ssl/certs/dhparam.pem"

# Preporučeni SSL/TLS postavke za PFS (Perfect Forward Secrecy)
SSLSessionTickets off

# Zahtijevajte jaku autentifikaciju (eng. "strict requirement")
SSLOptions +StrictRequire

# Moderni enkripcijski skupovi
SSLCipherSuite TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256

# Podesite siguran TLS session cache
SSLSessionCache shmcb:/var/run/apache2/ssl_scache(512000)

# Omogući HTTP Strict Transport Security (HSTS) sa maksimalnim vremenom od 1 godine
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"

# Onemogućite SSL kompresiju, koji je ranjiv na "CRIME" napad
SSLCompression off

# Podesite vrijeme za SSL session (ne predugo da ne omogući napade)
SSLSessionCacheTimeout 300

EOF'

    echo "Fajl $SSL_OPTIONS_FILE je uspješno kreiran."
else
    echo "Fajl $SSL_OPTIONS_FILE već postoji."
fi

# Restartovanje Apache servisa
echo "Restartujem Apache servis..."
sudo systemctl restart apache2

# Provjera statusa Apache servisa
echo "Provjeravam status Apache servisa..."
STATUS=$(systemctl is-active apache2)

if [ "$STATUS" != "active" ]; then
    echo "Greška: Apache servis nije uspješno pokrenut!"
    exit 1
else
    echo "Apache servis je uspješno pokrenut."
fi

# --- Kreiranje Apache konfiguracije ako nije već definisana ---
if [ -z "$APACHE_CONF" ]; then
  APACHE_CONF="/etc/apache2/sites-available/$DOMAIN.conf"

  echo -e "\n${YELLOW}Kreiram Apache konfiguraciju: $APACHE_CONF${NC}"

  # Kreiranje Apache konfiguracijskog fajla
  sudo bash -c "cat > $APACHE_CONF" <<EOF
# Preusmjeravanje HTTP na HTTPS
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    Redirect permanent / https://$DOMAIN/
</VirtualHost>

<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot $WEBROOT

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem

    <Directory $WEBROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
</IfModule>
EOF

  # Aktivacija konfiguracije
  sudo a2ensite "$DOMAIN.conf"

  # Reload Apache da primijeni novu konfiguraciju
  echo -e "${BLUE}Ponovno učitavanje Apache konfiguracije...${NC}"
  sudo systemctl reload apache2

  # Poruka o uspjehu
  echo -e "\n${GREEN}Apache konfiguracija za $DOMAIN uspješno kreirana.${NC}"
fi


# --- Aktivacija sajta i reload Apache ---
echo -e "\n${YELLOW}Aktiviram sajt i reloadujem Apache...${NC}"

sudo a2ensite "$(basename $APACHE_CONF)"

# Test Apache konfiguracije prije reload-a
if sudo apache2ctl configtest | grep -q "Syntax OK" && ! sudo apache2ctl configtest | grep -q "AH00558"; then
  sudo systemctl reload apache2
  echo -e "${GREEN}Apache reload uspješan!${NC}"
else
  echo -e "${RED}Greška u Apache konfiguraciji! Provjeri ručno.${NC}"
  exit 1
fi

# --- Postavljanje automatskog obnavljanja certifikata ---
echo -e "\n${YELLOW}Provjera cronjob-a za automatski renew SSL certifikata...${NC}"
CRON_EXISTS=$(sudo crontab -l 2>/dev/null | grep -c "certbot renew")

if [ "$CRON_EXISTS" -eq 0 ]; then
  echo -e "${GREEN}Postavljam novi cronjob...${NC}"
  (sudo crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --dns-cloudflare --dns-cloudflare-credentials "$CLOUDFLARE_CREDENTIALS" && sleep 30 && systemctl reload apache2
") | sudo crontab -
else
  echo -e "${GREEN}Cronjob već postoji. Preskačem.${NC}"
fi

# --- REZIME OPERACIJE ---
echo -e "\n${BLUE}============================================================${NC}"
echo -e "${GREEN}                  SSL CERTIFIKAT - REZIME                   ${NC}"
echo -e "${BLUE}============================================================${NC}"
echo -e "${YELLOW}Apache host fajl:${NC}          $APACHE_CONF"
echo -e "${YELLOW}Lokacija SSL certifikata:${NC}  /etc/letsencrypt/live/$DOMAIN/"
echo -e "${YELLOW}Automatski renew:${NC}          Svakih 24h (cron @ 03:00h)"
echo -e "${BLUE}------------------------------------------------------------${NC}"
echo -e "${YELLOW}VAŽNO:${NC} Ukoliko u budućnosti mijenjate webroot ili konfiguraciju,"
echo -e "       ručno ažurirajte host fajl: $APACHE_CONF"
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}INSTALACIJA JE USPJEŠNO ZAVRŠENA!${NC}"
echo -e "${BLUE}============================================================${NC}\n"
