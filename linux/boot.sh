#!/usr/bin/env bash
# Jam per-boot tasks (runs on every boot, regardless of version)
# Safe to run multiple times
set -Eeuo pipefail
umask 022

BASE_DIR="/opt/jam-gitops"
BOOT_DIR="${BASE_DIR}/boot"
LOG_TAG="jam-gitops-boot"

log()  { printf "[boot] %(%FT%T%z)T %s\n" -1 "$*" | systemd-cat -t "$LOG_TAG"; }
warn() { log "WARN: $*"; }

if [[ -d "$BOOT_DIR" ]]; then
  while IFS= read -r -d '' f; do
    if [[ -x "$f" ]]; then
      log "running: ${f##*/}"
      "$f" || warn "script failed: $f"
    else
      warn "skipping non-executable: $f"
    fi
  done < <(find "$BOOT_DIR" -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)
else
  warn "boot dir missing: $BOOT_DIR"
fi

log "per-boot tasks complete"
exit 0