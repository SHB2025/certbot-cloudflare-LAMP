# Automatska SSL konfiguracija za Apache preko Cloudflare DNS-a | Bash skripta (Linux/Ubuntu)
Generate SSL certificate with cloudflare proxy.

# --- Upozorenje ---
⚠️  VAŽNO UPOZORENJE: Nikada ne koristite Globalni Cloudflare API Token!
Koristite isključivo tzv. 'Scoped API Token' sa ograničenim pravima (npr. DNS edit, Zone read).
Globalni token daje pristup SVIM zonama i može kompromitovati cijeli nalog ako procuri.

# --- Warning ---
⚠️ IMPORTANT WARNING: Never use the Global Cloudflare API Token!
Use only the so-called 'Scoped API Token' with limited rights (e.g. DNS edit, Zone read).
The Global Token gives access to ALL zones and can compromise the entire account if leaked.

## 📦 Preduvjeti

- Ubuntu 20.04 / 22.04 / 24.04
- Već instaliran **Apache** (LAMP stack)
- Cloudflare DNS upravljanje za domenu
- Validan **API Token** sa DNS edit dozvolama

---

## 🛠️ Instalacija i pokretanje

# Preuzmi skriptu
    sudo wget https://raw.githubusercontent.com/SHB2025/certbot-cloudflare-LAMP/refs/heads/main/certbot-cloudflare-LAMP.sh

# Dodaj dozvole za izvršavanje
    sudo chmod +x certbot-cloudflare-LAMP.sh

# Pokreni skriptu
    sudo ./certbot-cloudflare-LAMP.sh

# 🔐 certbot-cloudflare-LAMP.sh

Automatizovana bash skripta za generisanje **Let's Encrypt SSL certifikata** koristeći **Cloudflare DNS verifikaciju** na **Apache serveru (LAMP)** okruženju.

---

## ✨ Karakteristike

- ✅ Automatska instalacija Certbot i Cloudflare DNS plugina
- ✅ Unos i sigurno čuvanje Cloudflare API tokena
- ✅ Generisanje SSL certifikata za domenu i www poddomenu
- ✅ Kreiranje ili prilagođavanje Apache konfiguracije
- ✅ Aktivacija SSL, HSTS, i naprednih sigurnosnih postavki
- ✅ Automatski cronjob za obnavljanje certifikata

---

⚙️ Kako radi
Skripta provjerava i instalira potrebne pakete (certbot, python3-certbot-dns-cloudflare)

Traži unos Cloudflare API tokena i domene

Generiše i aktivira SSL certifikate

Kreira Apache konfiguraciju ako ne postoji

Aktivira cronjob za automatsko obnavljanje certifikata

📁 Putanje i fajlovi
credentials: /etc/certbot/credentials

Apache conf: /etc/apache2/sites-available/ime-domene.conf

SSL cert: /etc/letsencrypt/live/ime-domene/

🔐 Napomena o sigurnosti
Cloudflare API token se čuva s dozvolom chmod 600 u /etc/certbot/credentials. Preporučuje se da token ima minimalne potrebne dozvole za DNS zone.

📅 Automatski renew
Skripta automatski postavlja cron zadatak za dnevno obnavljanje SSL certifikata:
0 3 * * * certbot renew --quiet --dns-cloudflare --dns-cloudflare-credentials /etc/certbot/credentials && sleep 30 && systemctl reload apache2

📢 Autor

👨‍💻 Kreirao: SolutionHubBosnia
