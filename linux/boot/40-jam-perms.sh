#!/usr/bin/env bash
set -euo pipefail
source /opt/jam-gitops/boot/00-env.sh

log "setting jam user permissions"

usermod -aG i2c,spi,gpio,video,input jam