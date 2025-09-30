# Repository Guidelines

## Project Structure & Module Organization
- `main.yml` orchestrates role execution for the `debian_lighthouse` group.
- `roles/` contains Ansible roles (`core`, `deploy_user`, `initialize`, `locales`, `firewall`, `swapfile`, `nginx`, `v2ray`, `certbot`, `umami_nginx`). Each role follows the defaults/tasks/handlers layout.
- `group_vars/debian_lighthouse/` stores environment defaults; `*.template` files are templates, live copies are ignored.
- `inventory/hosts.yml.template` is the sample inventory. Copy to `inventory/hosts.yml` for local runs.
- `ansible-node-plan.md` tracks outstanding automation work; update it when delivering new capabilities.

## Build, Test, and Development Commands
- `./scripts/install-ansible.sh`: install controller-side dependencies.
- `ANSIBLE_LOCAL_TEMP=./.ansible/tmp ansible-playbook --syntax-check main.yml`: quick validation without touching hosts (macOS sandbox-safe temp dir).
- `ANSIBLE_LOCAL_TEMP=./.ansible/tmp ANSIBLE_GALAXY_CACHE_DIR=./.ansible/galaxy_cache ./scripts/lint.sh`: run ansible-lint with local caches.
- To exercise a role: `ansible-playbook -i inventory/hosts.yml main.yml --tags <role>` (add `--check` during development).

## Coding Style & Naming Conventions
- YAML files: 2-space indentation, lower_snake_case variables, quotes only when necessary.
- Role variables live under `roles/<name>/defaults/main.yml`; inventory overrides go in `group_vars`.
- Configuration templates in existing roles live under `templates/` and are rendered with `ansible.builtin.template`.

## Testing Guidelines
- No automated CI yet; rely on `ansible-lint` and `--syntax-check` before commits.
- For runtime validation, run targeted playbook commands with `--check` or `--diff`.
- Consider Molecule scenarios for new roles if adding non-trivial logic (not yet present).

## Commit & Pull Request Guidelines
- Follow conventional commits (`feat(role): …`, `fix(role): …`, `docs: …`, `chore: …`).
- Each logical change gets its own commit; documentation updates accompany code when relevant.
- Pull requests should summarize changes, list impacted roles/files, include testing evidence (lint, syntax check, runtime notes), and reference plan items or issues.

## Security & Configuration Tips
- Never commit populated `inventory/hosts.yml`, `group_vars/debian_lighthouse/main.yml`, or `vault.yml`; use the provided templates.
- Encrypt secrets with `ansible-vault encrypt group_vars/debian_lighthouse/vault.yml` before sharing.
- Prefer macOS-safe temp/cache overrides (`ANSIBLE_LOCAL_TEMP`, `ANSIBLE_GALAXY_CACHE_DIR`) during local runs.
