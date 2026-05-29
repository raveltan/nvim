#!/bin/sh

REMOTE_HOST="dev@rtanjaya.syd1.fln-dev.net"

# Run SSH and test htop
ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$HOME/.ssh/id_ed25519" "$REMOTE_HOST" '
    if pgrep muppet >/dev/null; then
        echo "  devbox PROVISIONING"
    else
        echo "✔︎  devbox UP"
    fi
' 2>/dev/null || echo "✖︎ devbox DOWN"
