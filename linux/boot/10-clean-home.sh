#!/usr/bin/env bash
set -Eeuo pipefail
source /opt/jam-gitops/boot/00-env.sh

ensure_dirs

log "Cleaning standard user folders"
# Clear caches
rm -rf "${JAM_HOME}/.cache/"* 2>/dev/null || true

# Wipe common content folders (NOT dotfiles)
for d in Documents Downloads Pictures Videos Music Templates Public Examples; do
  rm -rf "${JAM_HOME}/${d}/"* 2>/dev/null || true
done

# Keep folder structure intact
ensure_dirs

# Fix ownership
chown -R "${JAM_USER}:${JAM_USER}" "${JAM_HOME}"
log "Home cleanup complete"
