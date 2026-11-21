#!/bin/bash
# Crea build/Detox-<versión>.pkg: un instalador que deja el build en
# /Library/Application Support/Detox/installer y ejecuta scripts/install.sh. Sin sudo.
set -euo pipefail
cd "$(dirname "$0")/.."

# Firma ad hoc: el certificado de desarrollo lleva datos personales y no sirve para distribuir.
DETOX_SIGN_IDENTITY=- scripts/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' packaging/Info.plist)

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
DEST="$STAGE/root/Library/Application Support/Detox/installer"
mkdir -p "$DEST/build" "$STAGE/scripts"
cp -R build/Detox.app build/detoxd "$DEST/build/"
cp -R packaging scripts "$DEST/"
cat > "$STAGE/scripts/postinstall" <<'EOF'
#!/bin/bash
set -euo pipefail
cd "/Library/Application Support/Detox/installer"
CONSOLE_USER=$(stat -f %Su /dev/console)
[ "$CONSOLE_USER" != root ] || { echo "Instala Detox desde una sesión de usuario."; exit 1; }
SUDO_USER="$CONSOLE_USER" scripts/install.sh
EOF
chmod 755 "$STAGE/scripts/postinstall"
xattr -cr "$STAGE/root"  # sin atributos extendidos: si no, el paquete lleva ficheros ._*
export COPYFILE_DISABLE=1

# Sin reubicar: si el Mac ya tiene un Detox.app, el instalador no debe escribir encima de ese.
pkgbuild --analyze --root "$STAGE/root" "$STAGE/components.plist" >/dev/null
plutil -replace 0.BundleIsRelocatable -bool NO "$STAGE/components.plist"
pkgbuild --root "$STAGE/root" --component-plist "$STAGE/components.plist" --scripts "$STAGE/scripts" \
  --identifier com.detox.pkg --version "$VERSION" --install-location / "build/Detox-$VERSION.pkg"
echo "Listo: build/Detox-$VERSION.pkg"
