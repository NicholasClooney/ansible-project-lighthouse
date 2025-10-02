# Recharging Project Lighthouse with Ansible

This post documents the early milestones in rebuilding **Project Lighthouse** on a Debian 13 droplet using Ansible. The goal is to capture not just *what* changed, but the exact files, tasks, and commands that make the automation reproducible.

## Why Refresh the Stack Now
We are migrating the blog/proxy/analytics stack to a brand-new Debian 13 (Trixie) droplet. Rather than hand-configuring yet another server, we want a single playbook that can be run against any fresh instance to bootstrap the same environment: hardened SSH, proxy services, analytics, certificates, and backups. Automating the base layer first lets us iterate on higher-level roles (Nginx, V2Ray, Umami) without worrying about snowflake hosts.

## Anchoring on the Existing Core Role
The project already shipped with a `roles/core` role that establishes our baseline CLI experience. It installs the tools we live in—`tmux`, `fish`, `mosh`, `git`, `tailscale`, `vim`, `rsync`—and makes fish the default shell. Keeping this role untouched means we continue to inherit the expected shell behavior when the new host comes online.

```yaml
# roles/core/tasks/main.yml
- name: Install core CLI packages
  become: true
  ansible.builtin.package:
    name:
      - tmux
      - fish
      - mosh
      - git
      - tailscale
      - vim
      - rsync
    state: present

- name: Set fish as default shell for current user
  become: true
  ansible.builtin.user:
    name: "{{ ansible_user_id }}"
    shell: /usr/bin/fish
```

This context influenced later choices: the new `initialize` role deliberately avoids reinstalling packages already handled by `core` so we keep the dependency surface lean.

## Building a Deploy User with Optional Key Sync
Before we can trust automation, we need a non-root user that owns deployments. The `roles/deploy_user` role ensures a `deploy` user (or any overridden name) exists, is part of the `sudo` group, and can run privileged commands without prompting. The key tasks are:

```yaml
# roles/deploy_user/tasks/main.yml
- name: Ensure deploy user exists
  become: true
  ansible.builtin.user:
    name: "{{ deploy_user_name_effective }}"
    home: "/home/{{ deploy_user_name_effective }}"
    shell: /usr/bin/fish
    create_home: true
    groups: sudo
    append: true

- name: Configure passwordless sudo for deploy user
  become: true
  ansible.builtin.copy:
    dest: "/etc/sudoers.d/{{ deploy_user_name_effective }}"
    content: "{{ deploy_user_name_effective }} ALL=(ALL) NOPASSWD:ALL\n"
    owner: root
    group: root
    mode: '0440'
    validate: 'visudo -cf %s'
```

The role also contains a lint-driven improvement: syncing `/root/.ssh` into the deploy user’s home is now optional. A new default (`roles/deploy_user/defaults/main.yml`) keeps it disabled, which is perfect when Tailscale handles all SSH entry points:

```yaml
deploy_user_sync_root_keys: false
```

When set to `true`, the copy happens in an idempotent, module-driven way instead of invoking `rsync`:

```yaml
- name: Sync root SSH keys to deploy user
  become: true
  ansible.builtin.copy:
    src: /root/.ssh/
    dest: "/home/{{ deploy_user_name_effective }}/.ssh/"
    owner: "{{ deploy_user_name_effective }}"
    group: "{{ deploy_user_name_effective }}"
    mode: preserve
    remote_src: true
  when:
    - deploy_user_sync_root_keys | bool
    - root_ssh_dir.stat.exists | default(false)
```

Finally, the role validates its own work by running `sudo -n whoami` as the deploy user and asserting that the output is `root`. That quick smoke test catches sudoers mistakes before we ever reach production.

## A Structured Inventory and Group Vars
Originally, the inventory was a single INI-style line (`127.0.0.1 ansible_connection=local`). We replaced it with a YAML template at `inventory/hosts.yml.template`:

```yaml
---
all:
  children:
    debian_lighthouse:
      hosts:
        lighthouse:
          ansible_host: 0.0.0.0  # replace with droplet IP or hostname
          ansible_user: root
```

The template is committed to git, while `inventory/hosts.yml` is ignored so each operator can fill in the actual droplet IP locally. Alongside it, we added `group_vars/debian_lighthouse/main.yml.template` to centralize non-secret configuration, and `group_vars/debian_lighthouse/vault.yml.template` for secrets. For example, `main.yml.template` defines the domains, Certbot email, Umami defaults, and a future allowlist for the analytics dashboard:

```yaml
analytics_domain: "analytics.example.com"
certbot_admin_email: "admin@example.com"
nginx_dashboard_allowlist:
  - "127.0.0.1/32"  # update with remote access CIDRs or IPs
```

This templating strategy gives us the best of both worlds: shared defaults in version control, individualized overrides on disk, and a clear path to encrypt real secrets with `ansible-vault`.

## The Initialize Role: Upgrades and Docker
With the inventory squared away, we wrote a dedicated `initialize` role (`roles/initialize`) whose job is to make a fresh Debian host production-ready. The defaults enumerate the packages we still need because `core` doesn’t touch them:

```yaml
# roles/initialize/defaults/main.yml
initialize_packages:
  - curl
  - wget
  - unzip
  - htop
  - ufw
  - docker.io
```

The main tasks perform three actions in order:

```yaml
# roles/initialize/tasks/main.yml
- name: Upgrade base system packages
  become: true
  ansible.builtin.apt:
    update_cache: true
    upgrade: "{{ initialize_upgrade_type }}"
    cache_valid_time: "{{ initialize_cache_valid_time }}"

- name: Install initialize package set
  become: true
  ansible.builtin.apt:
    name: "{{ initialize_packages }}"
    state: present

- name: Ensure Docker service is running
  become: true
  ansible.builtin.service:
    name: docker
    state: started
    enabled: true
```

We default `initialize_upgrade_type` to `dist`, effectively running `apt-get dist-upgrade`. That decision is documented inline so operators can switch to `yes` (classic safe upgrade) if they want to avoid dependency changes. Finally, the top-level `main.yml` play includes this role right after the long-lived `core` and `deploy_user` roles:

```yaml
roles:
  - core
  - deploy_user
  - initialize
```

Running `ansible-playbook -i inventory/hosts.yml main.yml --limit debian_lighthouse --tags initialize` now upgrades the host, installs the missing packages, and ensures Docker is enabled in a single step.

## Protecting Secrets with Templates and Ignores
To avoid accidental leaks, the working copies of the inventory and group vars are ignored via `.gitignore`:

```gitignore
# Local Ansible configuration copies
inventory/hosts.yml
group_vars/debian_lighthouse/main.yml
group_vars/debian_lighthouse/vault.yml
.ansible/
```

Each developer runs:

```bash
cp inventory/hosts.yml.template inventory/hosts.yml
cp group_vars/debian_lighthouse/main.yml.template group_vars/debian_lighthouse/main.yml
cp group_vars/debian_lighthouse/vault.yml.template group_vars/debian_lighthouse/vault.yml
ansible-vault encrypt group_vars/debian_lighthouse/vault.yml
```

Once the vault file is encrypted, the playbook prompts for a Vault password (`--ask-vault-pass`). These conventions let the team sync the repo without committing real credentials while still sharing sane defaults.

## Linting as an Everyday Guardrail
Pure YAML validation wasn’t enough—we wanted automated guidance for module usage, idempotency, and style. The repo now ships with `ansible-lint` tooling:

```bash
pip install -r requirements-dev.txt
./scripts/lint.sh
```

The root `.ansible-lint` enables the production profile and excludes the Vault file so the linter doesn’t stall on encrypted content:

```yaml
profile: production
exclude_paths:
  - group_vars/debian_lighthouse/vault.yml
```

During setup, the linter flagged that we were using `rsync` in the `deploy_user` role—a classic “command-instead-of-module” smell. The fix was to switch to the built-in `ansible.builtin.copy` module and gate the behavior behind a new `deploy_user_sync_root_keys` boolean (default `false` since Tailscale handles SSH most of the time). Linting isn’t just bureaucracy; it has already pushed us toward safer, idempotent patterns.

## Faster Iteration with Tags
A full playbook run is overkill when you only changed one role. To keep remote iterations quick, we documented how to run just the `initialize` role:

```bash
ansible-playbook -i inventory/hosts.yml main.yml \
  --limit debian_lighthouse \
  --tags initialize
```

The inverse (`--skip-tags initialize`) will come in handy once other roles are in place. This workflow is invaluable while we stagger development of firewall rules, swap management, and the web stack.

## Reworking Swap Management After Production Feedback
Once the first droplet run completed we hit a regression: activating swap via the `ansible.posix.mount` module fails on Debian 13 because `mount` cannot coerce the file into a `swap` filesystem. The error surfaced during a playbook run against the live host:

```
fatal: [lighthouse]: FAILED! => {"changed": false, "msg": "Error mounting none: mount: /home/deploy/none: unknown filesystem type 'swap'.\n       dmesg(1) may have more information after failed mount system call."}
```

The fix was to follow the traditional `mkswap`/`swapon` flow directly. The role still provisions the file (via `fallocate` or `dd`) and sets strict permissions, but enabling now shells out to `swapon` after confirming the file is not already active. We probe `/proc/swaps` exactly once at the top of the role, reuse the result to short-circuit idempotent runs, and continue managing the fstab entry separately so the swap file persists across reboots:

```yaml
# roles/swapfile/tasks/main.yml
- name: Check if swapfile is currently active
  become: true
  ansible.builtin.command:
    argv:
      - grep
      - -F
      - -q
      - "{{ swapfile_path }} "
      - /proc/swaps
  register: swapfile_active_check
  changed_when: false
  failed_when: false

- name: Activate swapfile
  become: true
  ansible.builtin.command:
    argv:
      - swapon
      - "{{ swapfile_path }}"
  when:
    - swapfile_enabled
    - swapfile_active_check.rc != 0
  changed_when: swapfile_active_check.rc != 0
```

Disabling follows the same pattern with `swapoff` guarded by the probe result. Besides eliminating the kernel error, the change makes test reruns faster because no shell commands execute when the file is already active. The `ansible-node-plan.md` checklist now calls out the `swapon` upgrade so future readers know why the role diverges from older mount-based snippets.
