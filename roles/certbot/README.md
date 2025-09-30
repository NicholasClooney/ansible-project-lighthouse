# Certbot Role

This role installs Certbot and issues certificates using the standalone challenge flow. It briefly stops nginx (or any services listed in `certbot_standalone_services`) so Certbot can bind port 80/443, then restarts them when issuance completes.

## Prerequisites
- DNS `A`/`AAAA` records for every entry in `certbot_domains` must already point at the target host, otherwise the Let’s Encrypt challenge will fail.
- Ensure SSH access and sudo privileges are configured for the inventory host.

## Key Variables
| Variable | Default | Purpose |
| --- | --- | --- |
| `certbot_domains` | `[]` | Domains to request certificates for. Provide the complete list (duplicates are fine). |
| `certbot_issue_certificates` | `false` | Toggle certificate issuance on or off. |
| `certbot_email` | `certbot_admin_email` | Registration/notification email. |
| `certbot_standalone_services` | `['nginx']` | Services stopped while Certbot runs standalone. |

## Usage
```yaml
# group_vars/debian_lighthouse/main.yml
certbot_issue_certificates: true
certbot_domains:
  - "analytics.example.com"
  - "example.com"
certbot_admin_email: "certbot@example.com"
certbot_standalone_services:
  - nginx
```
Then run:
```bash
ANSIBLE_LOCAL_TEMP=./.ansible/tmp \
ANSIBLE_GALAXY_CACHE_DIR=./.ansible/galaxy_cache \
ansible-playbook -i inventory/hosts.yml main.yml --tags certbot
```

## Migrating Existing Certificates

Copying `/etc/letsencrypt/` with naive tools can silently break renewals because the `live/<domain>/` directory is a set of symlinks into `archive/<domain>/`. If you copy files without preserving those links, Certbot reports errors such as “expected cert.pem to be a symlink”. Use one of the approaches below to move certificates safely between hosts.

### Tar over SSH (preserves symlinks)
Run these from your workstation. Replace hostnames as needed.

```bash
# On the destination host (new server) remove any partial copy first
ssh root@debian "rm -rf /etc/letsencrypt/live /etc/letsencrypt/archive /etc/letsencrypt/renewal"
ssh root@debian "mkdir -p /etc/letsencrypt"

# Stream tar between old → new host, preserving symlinks and permissions
ssh root@ubuntu "cd /etc/letsencrypt && tar czf - live archive renewal" \
  | ssh root@debian "cd /etc/letsencrypt && tar xzf -"

# Sanity check
ssh root@debian "find /etc/letsencrypt/live -maxdepth 2 -printf '%M %u:%g %p\\n'"
ssh root@debian "certbot renew --dry-run"
```

### `scp -3` (quick copy per domain)
If you only need one or two domains, you can pull them through your workstation with recursive `scp` while keeping symlinks intact by copying both `live/` and `archive/` plus the renewal file:

```bash
scp -3 -r root@ubuntu:/etc/letsencrypt/live/www.example.com \
         root@debian:/etc/letsencrypt/live/
scp -3 -r root@ubuntu:/etc/letsencrypt/archive/www.example.com \
         root@debian:/etc/letsencrypt/archive/
scp -3 root@ubuntu:/etc/letsencrypt/renewal/www.example.com.conf \
        root@debian:/etc/letsencrypt/renewal/
```

Repeat for any additional domains. Afterwards, verify ownership (`root:root`) and run `certbot renew --dry-run` to confirm the renewal configs remain valid.
