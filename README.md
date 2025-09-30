# Project Lighthouse

Ansible automation for rebuilding the Project Lighthouse droplet on Debian 13. The playbook bootstraps baseline tooling (shell preferences, deploy user) and now adds an `initialize` role that upgrades the OS, installs the remaining base packages, and ensures Docker is enabled for downstream services.

## Repository Layout
- `inventory/hosts.yml.template` – Template inventory for the `debian_lighthouse` group; copy to `inventory/hosts.yml` (ignored) for local customization.
- `group_vars/debian_lighthouse/main.yml.template` – Template for non-secret variables (domains, Certbot config, Umami defaults, swap sizing); copy to `main.yml` locally.
- `group_vars/debian_lighthouse/vault.yml.template` – Template for sensitive values; copy to `vault.yml`, fill in secrets, then encrypt with Ansible Vault.
- `roles/initialize/` – Packages/dist-upgrade/Docker setup for the new node.
- `roles/core/`, `roles/deploy_user/` – Existing roles that manage CLI tooling and the deploy account.
- `ansible-node-plan.md` – Work plan & checklist as the remaining roles are implemented.
- `main.yml` – Entry-point play that will be extended with the new roles as they come online.

> Note: `.gitignore` excludes the live copies (`inventory/hosts.yml`, `group_vars/debian_lighthouse/main.yml`, `group_vars/debian_lighthouse/vault.yml`) so you can tweak local configuration without committing secrets.

## Requirements
- Ansible 2.15+ (controller machine).
- SSH access to the target host (root or a sudo-capable user). Remote-access tooling such as Tailscale should already be installed manually.
- Python available on the target (default on Debian 13).
- `ansible-lint` for static checks (install via `pip install -r requirements-dev.txt` or `pipx install ansible-lint`).

## Before You Run the Playbook
1. **Create local config from templates** (if not already present):
   ```bash
   cp inventory/hosts.yml.template inventory/hosts.yml
   cp group_vars/debian_lighthouse/main.yml.template group_vars/debian_lighthouse/main.yml
   cp group_vars/debian_lighthouse/vault.yml.template group_vars/debian_lighthouse/vault.yml
   ```
2. **Inventory** – Edit `inventory/hosts.yml` with the real droplet IP/hostname and SSH user.
3. **Group vars** – Adjust values in `group_vars/debian_lighthouse/main.yml` to match your domains, email, access allowlist, etc.
4. **Secrets** – Fill out `group_vars/debian_lighthouse/vault.yml` with real passwords/salts, then encrypt it:
   ```bash
   ansible-vault encrypt group_vars/debian_lighthouse/vault.yml
   ```
5. **SSH access** – Confirm you can log in non-interactively (SSH key or appropriate auth) because the playbook connects over SSH.

## Running the Playbook
Run the full playbook against the `debian_lighthouse` group:
```bash
ansible-playbook -i inventory/hosts.yml main.yml --limit debian_lighthouse
```

If you encrypted `vault.yml`, supply the password at runtime:
```bash
ansible-playbook -i inventory/hosts.yml main.yml --limit debian_lighthouse --ask-vault-pass
```

By default the play gathers facts and runs the `core`, `deploy_user`, and `initialize` roles (with additional roles to be added as they are completed). Use `--tags` or `--skip-tags` as needed once more roles are in place.

## Linting & Validation
Install tooling:
```bash
pip install -r requirements-dev.txt
```

Run the Ansible linter from the repo root:
```bash
./scripts/lint.sh
```

Pass extra paths or flags as needed, e.g. `./scripts/lint.sh roles/initialize`.

## Next Steps
Follow `ansible-node-plan.md` for the outstanding work items (firewall, swapfile, web stack, Umami services, backups, and documentation updates). Each completed milestone should be checked off in that file and reflected in this README.
