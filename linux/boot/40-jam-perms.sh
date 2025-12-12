#!/usr/bin/env bash
set -euo pipefail

log "setting jam user permissions"

usermod -aG i2c,spi,gpio,video,input jam