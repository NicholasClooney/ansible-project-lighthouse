# V2Ray Role

This role installs V2Ray using the upstream convenience script, deploys a controller-managed `config.json`, and optionally copies extra assets such as shared Nginx site definitions. Configuration files are copied verbatim; you provide the finished artifacts and specify their destinations.

## Required Inputs
- **Controller config**: Place an existing `config.json` under `roles/v2ray/files/` (default name `config.json`) or set `v2ray_config_src` to any readable path on the controller. The role copies it to `v2ray_config_path` (default `/usr/local/etc/v2ray/config.json`).
- **Inventory entry**: Ensure the target host is listed in `inventory/hosts.yml` with valid SSH connectivity.

## Optional Variables
| Variable | Default | Purpose |
| --- | --- | --- |
| `v2ray_config_src` | `config.json` | Controller-side path to copy to `v2ray_config_path`. Relative paths search this role’s `files/` directory. |
| `v2ray_config_path` | `/usr/local/etc/v2ray/config.json` | Destination path on the host. |
| `v2ray_extra_files` | `[]` | List of `{src, dest, owner, group, mode}` objects for arbitrary supporting files (no handlers triggered). |
| `v2ray_nginx_files` | `[]` | Same structure as above but intended for Nginx configuration files; changes notify the role’s `Reload Nginx` handler. |
| `v2ray_nginx_service_name` | `nginx` | Service name used by the `Reload Nginx` handler. |

## Example
```yaml
# group_vars/debian_lighthouse/main.yml
v2ray_config_src: config.json
v2ray_nginx_files:
  - src: nginx/default.conf
    dest: /etc/nginx/conf.d/default.conf
    owner: root
    group: root
    mode: '0644'
  - src: nginx/ssl.conf
    dest: /etc/nginx/snippets/ssl.conf
    mode: '0644'
```
Drop the corresponding files under `roles/v2ray/files/nginx/`. The role copies them and, when changes occur, reloads Nginx so the new configuration takes effect.

## Handlers
- `Restart V2Ray`: Restarts the service after configuration updates or fresh installs.
- `Reload Nginx`: Reloads the web server when `v2ray_nginx_files` change.

## Usage Notes
- Run `ansible-playbook main.yml --tags v2ray` (with any required vault credentials) after populating the files. Pair it with the `nginx` role earlier in the play so the service and directories exist before V2Ray copies its site definitions.
- If you do not need Nginx assets, leave `v2ray_nginx_files` empty and the handler will not fire.
