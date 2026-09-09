#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

run() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

run install -m 0755 llama-swap /usr/local/bin/llama-swap
run install -m 0644 _llama-swap /usr/local/share/zsh/site-functions/_llama-swap
run install -m 0644 llama-swap-sddm.service /etc/systemd/system/llama-swap-sddm.service

run systemctl daemon-reload
run systemctl enable --now llama-swap-sddm.service
systemctl status --no-pager llama-swap-sddm.service || true
