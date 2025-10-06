#!/usr/bin/env bash
# Common env for boot helpers
set -Eeuo pipefail
umask 022

JAM_USER="jam"
JAM_HOME="/home/${JAM_USER}"

# Desktop whitelist file (one filename per line, e.g., Jam Docs.desktop)
DESKTOP_WHITELIST_FILE="/opt/jam-gitops/boot/allowed_shortcuts.txt"

log()  { printf "[boot] %(%FT%T%z)T %s\n" -1 "$*"; }
warn() { log "WARN: $*"; }

ensure_dirs() {
  install -d -m 0755 -o "${JAM_USER}" -g "${JAM_USER}" \
    "${JAM_HOME}/Desktop" "${JAM_HOME}/Documents" "${JAM_HOME}/Downloads" \
    "${JAM_HOME}/Pictures" "${JAM_HOME}/Videos" "${JAM_HOME}/Music" \
    "${JAM_HOME}/Templates" "${JAM_HOME}/Public" "${JAM_HOME}/Examples"
}
