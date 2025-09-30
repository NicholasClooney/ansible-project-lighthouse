# Locales Role

Ensures required UTF-8 locales are available on Debian-based hosts by enabling entries in `/etc/locale.gen` and running `locale-gen`.

## Defaults
- `locales_to_generate`: `['en_US.UTF-8', 'en_GB.UTF-8', 'en_AU.UTF-8']`
- `locales_locale_file`: `/etc/locale.gen`
- `locales_generate_command`: `/usr/sbin/locale-gen`

## Usage
Override `locales_to_generate` in group vars or host vars when additional locales are needed:

```yaml
group_vars/debian_lighthouse/main.yml:
  locales_to_generate:
    - en_US.UTF-8
    - en_NZ.UTF-8
```

The role installs the `locales` package and only runs `locale-gen` when locale entries are changed, keeping subsequent runs idempotent.
