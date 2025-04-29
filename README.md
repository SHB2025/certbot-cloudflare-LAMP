# Automatska SSL konfiguracija za Apache preko Cloudflare DNS-a | Bash skripta (Linux/Ubuntu)
Generate SSL certificate with cloudflare proxy.

## 📦 Preduvjeti

- Ubuntu 20.04 / 22.04 / 24.04
- Već instaliran **Apache** (LAMP stack)
- Cloudflare DNS upravljanje za domenu
- Validan **API Token** sa DNS edit dozvolama

---

## 🛠️ Instalacija i pokretanje

```bash
# Preuzmi skriptu
wget https://raw.githubusercontent.com/SHB2025/certbot-cloudflare-LAMP/refs/heads/main/certbot-cloudflare-LAMP.sh

# Dodaj dozvole za izvršavanje
chmod +x certbot-cloudflare-LAMP.sh

# Pokreni skriptu
./certbot-cloudflare-LAMP.sh

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


