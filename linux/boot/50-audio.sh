#!/usr/bin/env bash
set -euo pipefail
source /opt/jam-gitops/boot/00-env.sh

ASOUNDRC="$JAM_HOME/.asoundrc"

cat > "$ASOUNDRC" <<'EOF'
pcm.!default {
    type hw
    card "Audio"
}

ctl.!default {
    type hw
    card "Audio"
}
EOF

chmod 644 "$ASOUNDRC"

log "Written $ASOUNDRC (ALSA default -> card 2)"
