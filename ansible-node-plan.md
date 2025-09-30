# Ansible Node Setup Plan

## Checklist
1. [x] Create/validate `inventory/hosts.yml` entry for `debian_lighthouse` group.
2. [x] Add `group_vars/debian_lighthouse/main.yml` with domains, emails, and Umami vars.
3. [x] Define `group_vars/debian_lighthouse/vault.yml` (sensitive values like Umami hash salt) and document vault usage.
4. [x] Implement `initialize` role (system update, required packages, docker enablement) while avoiding duplicates already covered by `core`.
5. [x] Implement `firewall` role (UFW reset, rules, enable).
6. [x] Implement `swapfile` role (optional via vars, now activates via `swapon`).
7. [x] Implement locale management role.
8. [x] Implement web stack roles: `nginx`, `v2ray`, `certbot`, `umami_nginx`.
9. [ ] Implement `docker_umami` role (compose stack, configs, service management).
10. [ ] Implement `backups` role (script + cron).
11. [ ] Assemble main playbook invoking roles in dependency order with handlers.
12. [ ] Update `README.md` with run instructions and required secrets.
13. [x] Add ansible-lint configuration and document lint workflow.
14. [ ] Draft and publish running blog recap of the automation work.

## Plan Overview
- Build an idempotent Ansible play that provisions a fresh Debian 13 droplet for the blog, proxy, and analytics stack, aligning with the documented migration plan while skipping any migration of existing data.
- Reuse existing `core`, `deploy_user`, and `ssh_hardening` roles before introducing the new roles that cover firewalling, web proxying, certificate management, and analytics services.
- Centralize configuration via inventory group variables and keep sensitive values encrypted with Ansible Vault.
- Assume Tailscale (or other remote access tooling) is pre-installed and connected manually before running this playbook.

## Role Breakdown
- **`initialize`**: Run apt upgrade, install required packages not already installed by `core` (`curl`, `wget`, `unzip`, `htop`, `ufw`, `docker.io`), enable Docker service.
- **`firewall`**: Reset UFW state, allow 80/443, deny 22, enable firewall and verify status.
- **`swapfile`**: Create/manage optional 1 GB swapfile controlled by variable.
- **`locales`**: Ensure required UTF-8 locales are activated via `locale-gen`, configurable via inventory vars.
- **`nginx`**: Install Nginx, deploy templated site configs (main site + Umami proxy pieces), manage reloads.
- **`v2ray`**: Install via upstream `go.sh` installer, template config, restart service.
- **`certbot`**: Install Certbot and Nginx plugin, optionally request certificates, rely on the packaged systemd timer for renewals.
- **`docker_umami`**: Prepare `/opt/umami`, template `.env`, `docker-compose.yml`, optional `postgres.conf`, ensure compose stack running.
- **`umami_nginx`**: Provide analytics nginx site with restricted dashboard access (configurable subnet/IP allowlist) and public tracking endpoints, enable site, reload service.
- **`backups`**: Deploy Postgres dump script and cron job cleaning old backups.

## Main Playbook Flow
- Target inventory group `debian_lighthouse`.
- Pre-tasks: include `core`, `deploy_user`, `ssh_hardening` as-needed.
- Role order: `initialize → locales → firewall → swapfile → nginx → v2ray → certbot → docker_umami → umami_nginx → backups` with handlers for service restarts.
- Use centralized variables for domains, access control allowlists, certbot email, Umami secrets.

## Project Structure
- `inventory/hosts.yml`: define new droplet host/group.
- `group_vars/debian_lighthouse/main.yml`: non-secret configuration.
- `group_vars/debian_lighthouse/vault.yml`: secrets encrypted with Vault.
- `roles/<role_name>/`: each role will be added with `tasks/`, `templates/`, `handlers/`, `defaults/` when implemented.
- `main.yml`: orchestrating playbook invoking roles.
- `README.md`: execution instructions, vault usage, dependency notes.
- `scripts/` (optional): helper scripts for vault management or service checks.

## Parked Ideas
- Automate remote-access integration later if the manual step becomes repetitive.
- Handle multi-domain certificate issuance strategy (single role vs. dedicated sub-role).
- Introduce Molecule or lightweight test harness for role validation in CI/local.
