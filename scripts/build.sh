#!/bin/bash
# Compila Detox y monta build/Detox.app y build/detoxd. Sin sudo.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product detoxd
swift build -c release --product Detox
BIN=$(swift build -c release --show-bin-path)

rm -rf build && mkdir -p build/Detox.app/Contents/MacOS build/Detox.app/Contents/Resources
cp "$BIN/Detox" build/Detox.app/Contents/MacOS/Detox
cp packaging/Info.plist build/Detox.app/Contents/Info.plist
cp "$BIN/detoxd" build/detoxd

# Icono: el sello de Pais Solutions, solo redimensionado.
ICONSET=build/AppIcon.iconset
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s packaging/AppIcon-source.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) packaging/AppIcon-source.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o build/Detox.app/Contents/Resources/AppIcon.icns
rm -rf "$ICONSET"

# Firma: identidad estable si existe (así macOS no vuelve a pedir permisos), si no ad hoc.
IDENTITY="${DETOX_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Apple Development/ {print $2; exit}')}"
IDENTITY="${IDENTITY:--}"
codesign --force --sign "$IDENTITY" --identifier com.detox.daemon build/detoxd
codesign --force --sign "$IDENTITY" --identifier com.detox.app build/Detox.app
echo "Listo: build/Detox.app y build/detoxd (firma: $([ "$IDENTITY" = "-" ] && echo "ad hoc" || echo "Apple Development"))."
echo "Ahora instala con: sudo scripts/install.sh"
