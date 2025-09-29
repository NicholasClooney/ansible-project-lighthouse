#!/usr/bin/env bash
set -euo pipefail

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "Cannot determine distro (missing /etc/os-release)" >&2
  exit 1
fi

case "${ID:-}" in
  debian|ubuntu)
    sudo apt update
    sudo apt install -y ansible
    ;;
  fedora)
    sudo dnf install -y ansible
    ;;
  rhel|centos|rocky|almalinux)
    sudo dnf install -y epel-release
    sudo dnf install -y ansible
    ;;
  arch|manjaro)
    sudo pacman -Sy --noconfirm ansible
    ;;
  *)
    echo "Unsupported distro: ${ID:-unknown}. Install Ansible manually." >&2
    exit 1
    ;;
esac

ansible --version
