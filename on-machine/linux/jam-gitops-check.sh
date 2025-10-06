#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="NIRaspberryJam"
REPO_NAME="nirj-infra"
BRANCH="main"
PLATFORM_DIR="linux"

BASE_DIR="/opt/jam-gitops"
LOCAL_VERSION_FILE="$BASE_DIR/version.txt"
TMP_DIR="$(mktemp -d)"
ZIP_PATH="$TMP_DIR/repo.zip"
EXTRACT_DIR="$TMP_DIR/extract"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/refs/heads/${BRANCH}/${PLATFORM_DIR}/version.txt"
ZIP_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${BRANCH}.zip"

log() { echo "[jam-gitops] $(date -Is) $*"; }

# small startup delay
sleep 10

# Run on every boot, no matter if the version has changed
if [[ -x "/opt/jam-gitops/boot.sh" ]]; then
  echo "[jam-gitops] $(date -Is) running pre-check boot.sh"
  /opt/jam-gitops/boot.sh 2>&1 | systemd-cat -t jam-gitops-boot
fi

# fetch remote version
if ! REMOTE_VERSION="$(curl -fsSL "$REMOTE_VERSION_URL" | tr -d '\r')"; then
  log "WARN: could not retrieve remote version"
  exit 0
fi

LOCAL_VERSION=""
if [[ -f "$LOCAL_VERSION_FILE" ]]; then
  LOCAL_VERSION="$(tr -d '\r' < "$LOCAL_VERSION_FILE" || true)"
fi

if [[ "$LOCAL_VERSION" == "$REMOTE_VERSION" ]] && [[ -d "$BASE_DIR" ]]; then
  log "Up-to-date (version $LOCAL_VERSION)"
  exit 0
fi

log "Update needed: local='$LOCAL_VERSION' remote='$REMOTE_VERSION' → downloading"

# download zip
curl -fSL "$ZIP_URL" -o "$ZIP_PATH"

# extract
mkdir -p "$EXTRACT_DIR"
unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR"

# path becomes nirj-infra-main/linux
SRC_DIR="$EXTRACT_DIR/${REPO_NAME}-${BRANCH}/${PLATFORM_DIR}"
if [[ ! -d "$SRC_DIR" ]]; then
  log "ERROR: expected folder missing: $SRC_DIR"
  exit 1
fi

# stage and atomic swap
STAGE_DIR="$TMP_DIR/stage"
mkdir -p "$STAGE_DIR"
cp -a "$SRC_DIR/." "$STAGE_DIR/"
chmod +x "$STAGE_DIR/main.sh" 2>/dev/null || true

if [[ -d "$BASE_DIR" ]]; then
  rm -rf "${BASE_DIR}.bak" 2>/dev/null || true
  mv "$BASE_DIR" "${BASE_DIR}.bak"
fi
mkdir -p "$(dirname "$BASE_DIR")"
mv "$STAGE_DIR" "$BASE_DIR"
echo -n "$REMOTE_VERSION" > "$LOCAL_VERSION_FILE"

# run main.sh (idempotent)
if [[ -x "$BASE_DIR/main.sh" ]]; then
  log "Running main.sh"
  "$BASE_DIR/main.sh"
else
  log "WARNING: $BASE_DIR/main.sh not found or not executable"
fi

log "Update complete to version $REMOTE_VERSION"

# Run boot.sh again in case anything has changed
if [[ -x "$BASE_DIR/boot.sh" ]]; then
  echo "[jam-gitops] $(date -Is) running post-update boot.sh"
  "$BASE_DIR/boot.sh" 2>&1 | systemd-cat -t jam-gitops-boot
fi

# cleanup best-effort
rm -rf "${BASE_DIR}.bak" "$TMP_DIR" || true