#!/bin/bash
# Desinstala Detox. Se niega mientras haya bloqueos en marcha.
set -euo pipefail

[ "$EUID" -eq 0 ] || { echo "Ejecuta: sudo scripts/uninstall.sh"; exit 1; }
BIN=/Library/PrivilegedHelperTools/com.detox.daemon
[ -x "$BIN" ] || { echo "Detox no está instalado."; exit 1; }

"$BIN" --can-uninstall || exit 1

USER_NAME="${SUDO_USER:-$(stat -f %Su /dev/console)}"
USER_UID=$(id -u "$USER_NAME")
USER_HOME=$(dscl . -read "/Users/$USER_NAME" NFSHomeDirectory | awk '{print $2}')

launchctl bootout "gui/$USER_UID/com.detox.app" 2>/dev/null || true
launchctl bootout system/com.detox.daemon 2>/dev/null || true
"$BIN" --cleanup
rm -f "$BIN" /Library/LaunchDaemons/com.detox.daemon.plist "$USER_HOME/Library/LaunchAgents/com.detox.app.plist" /var/run/detox.sock
rm -rf /Applications/Detox.app "/Library/Application Support/Detox"
echo "Detox desinstalado. /etc/hosts ha quedado como estaba."
