#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p 'Easy Snap.app/Contents/MacOS' 'Easy Snap.app/Contents/Resources' .module-cache
cp AppIcon.icns 'Easy Snap.app/Contents/Resources/AppIcon.icns'
xcrun swiftc -module-cache-path "$PWD/.module-cache" -target arm64-apple-macosx14.0 main.swift WindowAccess.swift -o 'Easy Snap.app/Contents/MacOS/EasySnap' -framework AppKit -framework ApplicationServices
cat > 'Easy Snap.app/Contents/Info.plist' <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>EasySnap</string>
<key>CFBundleIdentifier</key><string>local.easysnap.mac</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>Easy Snap</string>
<key>CFBundleDisplayName</key><string>Easy Snap</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - 'Easy Snap.app'
'Easy Snap.app/Contents/MacOS/EasySnap' --self-test
