# 🚀 Debian 13 Migration Plan (Personal Blog + Proxy + Analytics)

This document consolidates the full migration plan for moving to a fresh **Debian 13** droplet, including setup of Nginx, V2Ray, Certbot, Tailscale, and Umami (with Postgres).

---

## 1. Provision Droplet

* Create a **Debian 13 (Trixie)** droplet in the region closest to users.
* Size: **1 GB RAM recommended** (512 MB possible with swap + tuning).
* SSH in via DO console initially.

Update base system:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget rsync unzip htop ufw git docker.io docker-compose-plugin
sudo systemctl enable --now docker
```

---

## 2. Firewall (UFW)

```bash
sudo ufw reset
# Allow only web traffic
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
# Block SSH on public (we’ll use Tailscale)
sudo ufw deny 22/tcp
sudo ufw enable
sudo ufw status verbose
```

---

## 3. Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

* Log in to join Tailnet.
* Verify SSH access via Tailscale IP / MagicDNS.

---

## 4. Nginx

```bash
sudo apt install -y nginx
```

Sync configs from old server if needed:

```bash
rsync -avz root@OLD_SERVER:/etc/nginx/ /etc/nginx/
sudo nginx -t && sudo systemctl restart nginx
```

---

## 5. V2Ray

Install:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
```

Copy config:

```bash
rsync -avz root@OLD_SERVER:/etc/v2ray/ /etc/v2ray/
sudo systemctl restart v2ray
```

---

## 6. Certbot

```bash
sudo apt install -y certbot python3-certbot-nginx
```

Issue TLS certificates:

```bash
sudo certbot --nginx -d yourdomain.com -d analytics.yourdomain.com
```

Enable auto-renew:

```bash
( crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet" ) | crontab -
```

---

## 7. Umami + Postgres (Docker Compose)

### Create working directory

```bash
sudo mkdir -p /opt/umami && cd /opt/umami
```

### `.env`

```bash
POSTGRES_USER=umami
POSTGRES_PASSWORD=change-me
POSTGRES_DB=umami
HASH_SALT=$(openssl rand -hex 32)
DATABASE_URL=postgresql://umami:change-me@postgres:5432/umami
```

### `postgres.conf` (tuned for 1 GB)

```conf
shared_buffers = 128MB
effective_cache_size = 256MB
work_mem = 8MB
maintenance_work_mem = 64MB
max_connections = 25
wal_level = replica
max_wal_size = 256MB
min_wal_size = 64MB
autovacuum = on
```

### `docker-compose.yml`

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: umami-postgres
    restart: unless-stopped
    env_file: .env
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./postgres.conf:/etc/postgresql/postgresql.conf:ro
    command: ["postgres","-c","config_file=/etc/postgresql/postgresql.conf"]

  umami:
    image: ghcr.io/umami-software/umami:postgresql-latest
    container_name: umami-app
    restart: unless-stopped
    depends_on:
      - postgres
    env_file: .env
    ports:
      - "127.0.0.1:3000:3000"

volumes:
  pgdata:
```

Start:

```bash
docker compose up -d
```

---

## 8. Nginx for Umami (Split Exposure)

`/etc/nginx/sites-available/umami`:

```nginx
server {
  server_name analytics.yourdomain.com;

  # Public tracking endpoints
  location = /script.js {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
  }
  location = /api/collect {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    limit_except POST { deny all; }
  }

  # Dashboard (Tailscale-only)
  location / {
    allow 100.64.0.0/10;  # Tailnet subnet
    deny all;
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
  }
}
```

Enable:

```bash
sudo ln -s /etc/nginx/sites-available/umami /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

Certbot:

```bash
sudo certbot --nginx -d analytics.yourdomain.com
```

---

## 9. Blog Integration

Insert tracking snippet into blog `<head>` (prod only):

```html
<script async defer data-website-id="YOUR-UUID"
        src="https://analytics.yourdomain.com/script.js"></script>
```

---

## 10. Backups

Daily Postgres dump:

```bash
sudo mkdir -p /var/backups/umami
sudo tee /usr/local/bin/umami-backup.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ts=$(date +%F)
docker exec umami-postgres pg_dump -U umami umami | gzip -9 > /var/backups/umami/umami-$ts.sql.gz
find /var/backups/umami -type f -mtime +14 -delete
EOF

sudo chmod +x /usr/local/bin/umami-backup.sh
( crontab -l 2>/dev/null; echo "15 3 * * * /usr/local/bin/umami-backup.sh" ) | crontab -
```

---

## 11. Swap (for low-memory instances)

```bash
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 12. Testing & Cutover

* Access Umami dashboard via Tailscale IP → confirm login, password change, website added.
* Confirm `https://analytics.yourdomain.com/script.js` loads publicly.
* Check `/api/collect` accepts requests.
* Confirm V2Ray proxy works.
* Once verified, **update DNS A/AAAA records** to point to the new droplet.
* Keep old server as fallback for 1–2 days, then destroy.

---

✅ With this setup:

* Nginx + V2Ray + Certbot run natively.
* Umami + Postgres run inside Docker with tuned memory.
* Certs auto-renew.
* Dashboard stays private via Tailscale, while only tracking endpoints are public.
* Backups are automated.
* Firewall keeps SSH closed to the world.
