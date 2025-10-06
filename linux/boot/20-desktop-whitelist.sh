#!/usr/bin/env bash
set -Eeuo pipefail
source /opt/jam-gitops/boot/00-env.sh

ensure_dirs

log "Enforcing Desktop whitelist"

# Build whitelist set
declare -A ALLOW=()
if [[ -f "$DESKTOP_WHITELIST_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    ALLOW["$line"]=1
  done < "$DESKTOP_WHITELIST_FILE"
fi

shopt -s nullglob
for f in "${JAM_HOME}/Desktop/"*; do
  base="$(basename "$f")"
  # Only police user-visible items (ignore dotfiles)
  if [[ "$base" == .* ]]; then
    continue
  fi
  if [[ -z "${ALLOW[$base]+x}" ]]; then
    log "Removing unapproved Desktop item: $base"
    rm -rf --one-file-system "$f" || true
  fi
done
shopt -u nullglob

# Re-apply perms
chown -R "${JAM_USER}:${JAM_USER}" "${JAM_HOME}/Desktop" || true
log "Desktop whitelist enforced"
