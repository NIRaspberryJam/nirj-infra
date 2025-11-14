#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/jam-gitops"

# Install VS Code extensions
"${BASE_DIR}/scripts/install_vscode_extension.sh" ms-python.python

echo "Linux GitOps update successful."