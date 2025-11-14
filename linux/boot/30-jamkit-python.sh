#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG ---
REPO_URL="https://github.com/NIRaspberryJam/jamkit-python.git"
TARGET_DIR="/opt/jamkit-python"
PYTHON_BIN="python3"          # change if you need a specific interpreter
PIP_BIN="$PYTHON_BIN -m pip"  # convenience
# --------------

echo "[jamkit] Using repo:    $REPO_URL"
echo "[jamkit] Target folder: $TARGET_DIR"

PARENT_DIR="$(dirname "$TARGET_DIR")"

# Ensure parent exists
if [ ! -d "$PARENT_DIR" ]; then
  echo "[jamkit] Creating parent directory: $PARENT_DIR"
  mkdir -p "$PARENT_DIR"
fi

# Clone or update
if [ ! -d "$TARGET_DIR" ]; then
  echo "[jamkit] Repo folder not found. Cloning..."
  git clone "$REPO_URL" "$TARGET_DIR"
elif [ ! -d "$TARGET_DIR/.git" ]; then
  echo "[jamkit] ERROR: $TARGET_DIR exists but is not a git repo."
  echo "        Please move or remove it, then re-run this script."
  exit 1
else
  echo "[jamkit] Repo already present. Fetching & pulling latest..."
  cd "$TARGET_DIR"
  git fetch --all --tags
  git pull --ff-only
fi

# Install / update jamkit as an editable package
cd "$TARGET_DIR"

echo "[jamkit] Installing jamkit in editable mode..."
pip install --break-system-packages -e .

echo "[jamkit] Done. You should now be able to do:"
echo "    from jamkit.turtle import Grid"