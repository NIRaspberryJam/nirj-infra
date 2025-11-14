#!/usr/bin/env bash
# Install a VS Code extension for the 'jam' user
# Usage: install_vscode_extension <extension-id>

set -Eeuo pipefail

EXT="$1"
TARGET_USER="jam"

log() {
    printf "[vscode-ext] %(%FT%T%z)T %s\n" -1 "$*"
}

if [[ -z "${EXT:-}" ]]; then
    log "ERROR: No extension ID provided"
    exit 1
fi

if ! command -v code >/dev/null 2>&1; then
    log "VS Code not installed; skipping extension install for '${EXT}'"
    exit 0
fi

log "Installing VS Code extension '${EXT}' for user '${TARGET_USER}'"

# Run as the jam user
sudo -u "${TARGET_USER}" bash -lc "
    code --install-extension ${EXT} --force >/dev/null 2>&1
"

if sudo -u "${TARGET_USER}" bash -lc "code --list-extensions | grep -qx '${EXT}'"; then
    log "Successfully installed '${EXT}'"
else
    log "WARNING: Extension '${EXT}' did not appear in extension list!"
fi
