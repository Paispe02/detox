#!/bin/bash
# Instala Detox. Ejecutar con sudo, después de scripts/build.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

[ "$EUID" -eq 0 ] || { echo "Ejecuta: sudo scripts/install.sh"; exit 1; }
[ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ] || { echo "Ejecútalo con sudo desde tu usuario, no como root."; exit 1; }
[ -d build/Detox.app ] && [ -f build/detoxd ] || { echo "Primero compila: scripts/build.sh"; exit 1; }

USER_UID=$(id -u "$SUDO_USER")
USER_HOME=$(dscl . -read "/Users/$SUDO_USER" NFSHomeDirectory | awk '{print $2}')

# Servicio de sistema
launchctl bootout system/com.detox.daemon 2>/dev/null || true
install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools /Library/Logs/Detox
install -o root -g wheel -m 755 build/detoxd /Library/PrivilegedHelperTools/com.detox.daemon
install -o root -g wheel -m 644 packaging/com.detox.daemon.plist /Library/LaunchDaemons/com.detox.daemon.plist
launchctl bootstrap system /Library/LaunchDaemons/com.detox.daemon.plist

# App
launchctl bootout "gui/$USER_UID/com.detox.app" 2>/dev/null || true
rm -rf /Applications/Detox.app
cp -R build/Detox.app /Applications/Detox.app
chown -R "$SUDO_USER":admin /Applications/Detox.app

# Arranque de la app en tu sesión
AGENT="$USER_HOME/Library/LaunchAgents/com.detox.app.plist"
install -d -o "$SUDO_USER" -m 755 "$USER_HOME/Library/LaunchAgents"
install -o "$SUDO_USER" -m 644 packaging/com.detox.app.plist "$AGENT"
launchctl bootstrap "gui/$USER_UID" "$AGENT"

echo "Detox instalado."
