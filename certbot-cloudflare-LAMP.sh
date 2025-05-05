#!/bin/bash

# --- BOJE ---
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
CYAN="\033[1;36m"
NC="\e[0m" # No Color

# Provjera da li je Certbot instaliran
# Checking if Certbot is installed
if ! command -v certbot &> /dev/null
then
    echo "Certbot nije instaliran. Instaliram Certbot..."
    sudo apt update -y
    sudo apt install certbot -y
else
    echo "Certbot je već instaliran."
fi

# Provjera da li je python3-certbot-dns-cloudflare instaliran
# Checking if python3-certbot-dns-cloudflare is installed
if ! dpkg -l | grep -q python3-certbot-dns-cloudflare
then
    echo "Paket python3-certbot-dns-cloudflare nije instaliran. Instaliram..."
    sudo apt install python3-certbot-dns-cloudflare -y
else
    echo "Paket python3-certbot-dns-cloudflare je već instaliran."
fi

# --- Kreiranje /etc/certbot direktorija ako ne postoji ---
# --- Creating /etc/certbot directory if it doesn't exist ---
if [ ! -d "/etc/certbot" ]; then
  echo -e "${YELLOW}Direktorij /etc/certbot ne postoji. Kreiram ga...${NC}"
  sudo mkdir -p /etc/certbot
fi


# --- Cloudflare credentials fajl ---
CLOUDFLARE_CREDENTIALS="/etc/certbot/credentials"

# Funkcija za unos API tokena sa prikazom zvjezdica
# API token input function with asterisk display
read_password_with_stars() {
    local prompt="$1"
    local password=""
    local char

    echo -en "$prompt"
    while IFS= read -r -s -n1 char; do
        # Enter prekida unos
        [[ $char == $'\0' || $char == $'\n' ]] && break
        # Backspace detekcija
        if [[ $char == $'\x7f' ]]; then
            if [ -n "$password" ]; then
                password="${password%?}"
                echo -ne "\b \b"
            fi
        else
            password+="$char"
            echo -n "*"
        fi
    done
    echo
    CLOUDFLARE_API_TOKEN="$password"
}

# --- Upozorenje ---
# --- Warning ---
echo -e "${RED}⚠️  VAŽNO UPOZORENJE: Nikada ne koristite Globalni Cloudflare API Token!${NC}"
echo -e "${RED}Koristite isključivo tzv. 'Scoped API Token' sa ograničenim pravima (npr. DNS edit, Zone read).${NC}"
echo -e "${RED}Globalni token daje pristup SVIM zonama i može kompromitovati cijeli nalog ako procuri.${NC}"
echo -e "${RED}⚠️ IMPORTANT WARNING: Never use the Global Cloudflare API Token!${NC}"
echo -e "${RED}Only use the so-called 'Scoped API Token' with limited rights (e.g. DNS edit, Zone read).${NC}"
echo -e "${RED}The Global Token gives access to ALL zones and can compromise the entire account if leaked.${NC}"

# --- Unos ---
# --- Input ---
read_password_with_stars "${CYAN}Unesite Cloudflare API Token/Enter the Cloudflare API Token:${NC} "

# --- Spremanje API tokena ---
# --- Saving API Token ---
echo -e "${YELLOW}Spremam Cloudflare API token u fajl $CLOUDFLARE_CREDENTIALS${NC}"
echo "dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN" | sudo tee $CLOUDFLARE_CREDENTIALS > /dev/null

# Postavljanje dozvola za sigurnost
# Setting security permissions
sudo chmod 600 $CLOUDFLARE_CREDENTIALS

# --- Unos domene ili poddomene ---
# --- Enter domain or subdomain ---
echo -e "${CYAN}Unesite naziv domene ili poddomene za generisanje SSL certifikata (npr. primjer.com)/Enter the domain or subdomain name to generate the SSL certificate (e.g. example.com):${NC}"
read DOMAIN

# --- Provjera da li već postoji Apache host fajl za domenu ---
# --- Checking if an Apache host file already exists for the domain ---
EXISTING_CONF=$(sudo grep -ril "ServerName $DOMAIN" /etc/apache2/sites-available/)

if [ -n "$EXISTING_CONF" ]; then
  echo -e "${YELLOW}Već postoji Apache konfiguracija za ovu domenu:${NC} $EXISTING_CONF"
  echo -e "${CYAN}Želite li:${NC}"
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
# --- Display available webroot directories ---
echo -e "\n${CYAN}Pronađeni webroot direktoriji:${NC}"
AVAILABLE_WEBROOTS=()

INDEX=1
for DIR in /var/www/*/ ; do
  echo "[$INDEX] $DIR"
  AVAILABLE_WEBROOTS+=("$DIR")
  ((INDEX++))
done

# --- Izbor webroot direktorija ---
# --- Choosing a webroot directory ---
echo -e "\n${CYAN}Unesi broj željenog direktorija sa liste ili upiši puni path ručno:${NC}"
read WEBROOT_CHOICE

if [[ "$WEBROOT_CHOICE" =~ ^[0-9]+$ ]]; then
  if ((WEBROOT_CHOICE > 0 && WEBROOT_CHOICE <= ${#AVAILABLE_WEBROOTS[@]})); then
    WEBROOT="${AVAILABLE_WEBROOTS[$((WEBROOT_CHOICE-1))]}"
  else
    echo -e "${RED}Neispravan izbor broja! Prekidan.${NC}"
    exit 1
  fi
else
  WEBROOT="$WEBROOT_CHOICE"
fi

# --- Provjera webroot direktorija ---
# --- Checking webroot directory ---
if [ ! -d "$WEBROOT" ]; then
  echo -e "${RED}Direktorij '$WEBROOT' ne postoji! Prekidam.${NC}"
  exit 1
fi

echo -e "${GREEN}Odabrani webroot:${NC} $WEBROOT"

# --- Generisanje SSL certifikata ---
# --- Generating SSL certificate ---
echo -e "\n${YELLOW}Pokrećem certbot za $DOMAIN i www.$DOMAIN...${NC}"
sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials "$CLOUDFLARE_CREDENTIALS" -d "$DOMAIN" -d "www.$DOMAIN" --dns-cloudflare-propagation-seconds 30

if [ $? -ne 0 ]; then
  echo -e "${RED}Greška pri generisanju SSL certifikata! Prekidan.${NC}"
  exit 1
fi

# Definiraj put do fajla
# Define the file path
SSL_OPTIONS_FILE="/etc/letsencrypt/options-ssl-apache.conf"

# Kreiranje DH parametara ako ne postoji
# Creating DH parameters if none exist
if [ ! -f "/etc/ssl/certs/dhparam.pem" ]; then
    echo -e "${YELLOW}Generišem Diffie-Hellman parametre. Ovo može potrajati...${NC}"
    sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
fi

sudo a2enmod ssl
sudo a2enmod headers

# Provjeri da li fajl postoji
# Check if the file exists
if [ ! -f "$SSL_OPTIONS_FILE" ]; then
    # Ako fajl ne postoji, kreiraj ga sa preporučenim postavkama
    echo "Fajl $SSL_OPTIONS_FILE ne postoji. Kreiram fajl sa sigurnosnim postavkama za SSL."

    # Kreiraj fajl s osnovnim postavkama (možeš dodati više postavki prema potrebama)
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

# Moderni šifri skupovi
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

# Putanja do glavnog Apache konfiguracijskog fajla
# Path to the main Apache configuration file
APACHE2_CONF="/etc/apache2/apache2.conf"

# Provjera da li fajl postoji
# Check if the file exists
if [[ -f "$SSL_OPTIONS_FILE" ]]; then
    # Provjera da li je već uključen
    # Checking if it is already on
    if ! grep -q "IncludeOptional $SSL_OPTIONS_FILE" "$APACHE2_CONF"; then
        echo "Dodajem IncludeOptional $SSL_OPTIONS_FILE u $APACHE2_CONF"
        echo -e "\n# Uključivanje Let's Encrypt SSL opcija\nIncludeOptional $SSL_OPTIONS_FILE" >> "$APACHE2_CONF"
    else
        echo "$SSL_OPTIONS_FILE je već uključen u $APACHE2_CONF"
    fi
else
    echo "Greška: $SSL_OPTIONS_FILE ne postoji! Pokreni certbot prvo."
fi

# Restartovanje Apache servisa
# Restart Apache service
echo "Restartujem Apache servis..."
sudo systemctl restart apache2

# Provjera statusa Apache servisa
# Checking the status of the Apache service
echo "Provjeravam status Apache servisa..."
STATUS=$(systemctl is-active apache2)

if [ "$STATUS" != "active" ]; then
    echo "Greška: Apache servis nije uspješno pokrenut!"
    exit 1
else
    echo "Apache servis je uspješno pokrenut."
fi

# --- Kreiranje Apache konfiguracije ako nije već definisana ---
# --- Create Apache configuration if not already defined ---
if [ -z "$APACHE_CONF" ]; then
  APACHE_CONF="/etc/apache2/sites-available/$DOMAIN.conf"

  echo -e "\n${YELLOW}Kreiram Apache konfiguraciju: $APACHE_CONF${NC}"

  # Kreiranje Apache konfiguracijskog fajla
  # Creating an Apache configuration file
  sudo bash -c "cat > $APACHE_CONF" <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot $WEBROOT

    <Directory $WEBROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
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

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-ssl-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-ssl-access.log combined
</VirtualHost>
</IfModule>

EOF

  # Aktivacija konfiguracije
  # Activating configuration
  sudo a2ensite "$DOMAIN.conf"

  # Reload Apache da primijeni novu konfiguraciju
  # Reload Apache to apply the new configuration
  echo -e "${CYAN}Ponovno učitavanje Apache konfiguracije...${NC}"
  sudo systemctl reload apache2

  # Poruka o uspjehu
  # Success message
  echo -e "\n${GREEN}Apache konfiguracija za $DOMAIN uspješno kreirana.${NC}"
  echo -e "\n${GREEN}Apache configuration for $DOMAIN created successfully.${NC}"
fi

# Postavi ServerName localhost
# Set ServerName to localhost

echo -e "\nDodajem globalni ServerName za Apache..."
sudo bash -c 'echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf'
sudo a2enconf servername
sudo systemctl reload apache2
echo -e "\e[32mGlobalni ServerName konfigurisan. Upozorenje će biti uklonjeno.\e[0m"


# --- Aktivacija sajta i reload Apache ---
# --- Activate the site and reload Apache ---
echo -e "\n${YELLOW}Aktiviram sajt i provjeravam konfiguraciju Apache-a...${NC}"

sudo a2ensite "$(basename $APACHE_CONF)"

# Test Apache konfiguracije prije reload-a
# Test Apache configuration before reload
if sudo apache2ctl configtest; then
    echo -e "${GREEN}Apache konfiguracija je ispravna. Reloadujem Apache...${NC}"
    sudo systemctl reload apache2
    echo -e "${GREEN}SSL certifikat i Apache konfiguracija za $DOMAIN su uspješno postavljeni.${NC}"
else
    echo -e "${RED}Greška u Apache konfiguraciji! Provjerite konfiguracijski fajl: $APACHE_CONF${NC}"
    exit 1
fi


# --- Postavljanje automatskog obnavljanja certifikata ---
# --- Setting up automatic certificate renewal ---
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
echo -e "\n${CYAN}============================================================${NC}"
echo -e "${GREEN}                  SSL CERTIFIKAT - REZIME                   ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo -e "${YELLOW}Apache host fajl:${NC}          $APACHE_CONF"
echo -e "${YELLOW}Lokacija SSL certifikata:${NC}  /etc/letsencrypt/live/$DOMAIN/"
echo -e "${YELLOW}Automatski renew:${NC}          Svakih 24h (cron @ 03:00h)"
echo -e "${CYAN}------------------------------------------------------------${NC}"
echo -e "${YELLOW}VAŽNO:${NC} Ukoliko u budućnosti mijenjate webroot ili konfiguraciju,"
echo -e "       ručno ažurirajte host fajl: $APACHE_CONF"
echo -e "${CYAN}============================================================${NC}"
echo -e "${GREEN}INSTALACIJA JE USPJEŠNO ZAVRŠENA!${NC}"
echo -e "${CYAN}============================================================${NC}\n"
# --- Preporuka za Cloudflare SSL postavke ---
echo -e "${YELLOW}PREPORUČENO: Postavite Cloudflare SSL na 'Full SSL (Strict)' i aktivirajte cloudflare redirect HTTP na HTTPS za maksimalnu sigurnost.${NC}"
# --- Upozorenje ---
echo -e "${RED}⚠️  VAŽNO UPOZORENJE: Nikada ne koristite Globalni Cloudflare API Token!${NC}"
echo -e "${RED}Koristite isključivo tzv. 'Scoped API Token' sa ograničenim pravima (npr. DNS edit, Zone read).${NC}"
echo -e "${RED}Globalni token daje pristup SVIM zonama i može kompromitovati cijeli nalog ako procuri.${NC}"

# --- OPERATION SUMMARY ---
echo -e "\n${CYAN}====================================================================${NC}"
echo -e "${GREEN} SSL CERTIFICATE - SUMMARY ${NC}"
echo -e "${CYAN}====================================================================${NC}"
echo -e "${YELLOW}Apache host file:${NC} $APACHE_CONF"
echo -e "${YELLOW}SSL Certificate Location:${NC} /etc/letsencrypt/live/$DOMAIN/"
echo -e "${YELLOW}Automatically renew:${NC} Every 24h (cron @ 03:00h)"
echo -e "${CYAN}------------------------------------------------------------${NC}"
echo -e "${YELLOW}IMPORTANT:${NC} If you change webroot or configuration in the future,"
echo -e " manually update hosts file: $APACHE_CONF"
echo -e "${CYAN}====================================================================${NC}"
echo -e "${GREEN}INSTALLATION COMPLETED SUCCESSFULLY!${NC}"
echo -e "${CYAN}====================================================================${NC}\n"
# --- Recommendation for Cloudflare SSL settings ---
echo -e "${YELLOW}RECOMMENDED: Set Cloudflare SSL to 'Full SSL (Strict)' and enable cloudflare redirect HTTP to HTTPS for maximum security.${NC}"
# --- Warning ---
echo -e "${RED}⚠️ IMPORTANT WARNING: Never use the Global Cloudflare API Token!${NC}"
echo -e "${RED}Use only the so-called 'Scoped API Token' with limited rights (e.g. DNS edit, Zone read).${NC}"
echo -e "${RED}The Global Token gives access to ALL zones and can compromise the entire account if leaked.${NC}"
