#!/bin/bash
# 맥 한국인 필수 설정.app 빌드 · 서명 · 공증 → dist/MacKoreanEssentials.zip
# 사용법: ./launcher/build.sh   (공증 없이: NOTARIZE=0)
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="맥 한국인 필수 설정"
OUT="dist"; APP="$OUT/$NAME.app"
rm -rf "$OUT"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for arch in arm64 x86_64; do swiftc -O -target "$arch-apple-macos12.0" launcher/main.swift -o "$OUT/l-$arch"; done
lipo -create "$OUT"/l-* -output "$APP/Contents/MacOS/MacKoreanEssentials"; rm "$OUT"/l-*
cp install.command "$APP/Contents/Resources/"; cp -R quick-actions "$APP/Contents/Resources/"
if [ -f launcher/icon-1024.png ]; then
  IS="$OUT/AppIcon.iconset"; mkdir -p "$IS"
  for s in 16 32 128 256 512; do sips -z $s $s launcher/icon-1024.png --out "$IS/icon_${s}x${s}.png" >/dev/null; sips -z $((s*2)) $((s*2)) launcher/icon-1024.png --out "$IS/icon_${s}x${s}@2x.png" >/dev/null; done
  iconutil -c icns "$IS" -o "$APP/Contents/Resources/AppIcon.icns"; rm -rf "$IS"
fi
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>com.seoriarts.mac-korean-essentials</string>
  <key>CFBundleExecutable</key><string>MacKoreanEssentials</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PL
SIGN_ID=$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2; exit}')
codesign --force --deep --options runtime --timestamp --sign "$SIGN_ID" "$APP"
ZIP="$OUT/MacKoreanEssentials.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
if [ "${NOTARIZE:-1}" = "1" ]; then
  xcrun notarytool submit "$ZIP" --keychain-profile notary --wait
  xcrun stapler staple "$APP"; rm "$ZIP"; ditto -c -k --keepParent "$APP" "$ZIP"
  spctl --assess --type execute --verbose "$APP"
fi
echo "완료: $ZIP"
