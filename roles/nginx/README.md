# Nginx Role

This role installs and manages the base Nginx package on Debian-based hosts. It provides optional hooks for supplying a custom `nginx.conf`, removes the default site when requested, and ensures the service is enabled and running. Other roles (for example `umami_nginx`) can layer site-specific configuration on top once the base service is present.

## Prerequisites
- **Inventory entry**: Update `inventory/hosts.yml` so `ansible_host` points at the real server address and the SSH user (default `deploy`) matches your access method.
- **Optional config template**: Leave `nginx_main_config_template` at its default (`null`) to keep the upstream `nginx.conf`. If you need a custom main config, add a Jinja2 template under `roles/nginx/templates/` (or another accessible role path) and set `nginx_main_config_template` to that filename in your inventory or group vars.
- **Extra modules**: Extend `nginx_extra_packages` when additional Debian packages (for example `nginx-extras` or specific dynamic modules) are required.
- **Downstream roles**: When layering Certbot, Umami, or other site roles, follow their documentation for the extra group variables and secrets they require; the base nginx install does not depend on them.

## Variables
| Variable | Default | Description |
| --- | --- | --- |
| `nginx_package_name` | `nginx` | Base package name to install. |
| `nginx_extra_packages` | `[]` | Additional packages/modules to install alongside Nginx. |
| `nginx_remove_default_site` | `true` | Removes `/etc/nginx/sites-enabled/default` when true. |
| `nginx_service_name` | `nginx` | Service unit name to manage. |
| `nginx_main_config_template` | `null` | Optional template file to copy to `/etc/nginx/nginx.conf`. |

## Usage
1. Confirm the target host is defined in the inventory and adjust optional variables (such as `nginx_main_config_template` or `nginx_extra_packages`) as needed.
2. (Optional) Provide a custom `nginx.conf` template and set `nginx_main_config_template` accordingly.
3. Run a quick syntax check before touching the host: `ANSIBLE_LOCAL_TEMP=./.ansible/tmp ansible-playbook --syntax-check main.yml`.
4. Apply the role on its own with `ansible-playbook main.yml --tags nginx`, or run the full play to configure the rest of the stack.

## Handlers
- `Reload Nginx`: Reloads the service when configuration files change.

## Idempotency Notes
The role relies on standard Ansible modules (`apt`, `template`, `file`, `service`) and is safe to re-run; no tasks issue unnecessary restarts unless configuration files change.
