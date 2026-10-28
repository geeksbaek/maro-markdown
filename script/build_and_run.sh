#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MaroMarkdown"
DISPLAY_NAME="Maro Markdown"
BUNDLE_ID="io.github.geeksbaek.maromarkdown"
MIN_SYSTEM_VERSION="27.0"
APP_VERSION="1.1.1"
BUILD_NUMBER="3"
BUILD_CONFIGURATION="${MARO_BUILD_CONFIGURATION:-debug}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"

mkdir -p "$ROOT_DIR/work/ModuleCache" "$DIST_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/work/ModuleCache"

SWIFT_OPTIONS=(
  --disable-sandbox
  --cache-path "$ROOT_DIR/work/swiftpm-cache"
  --config-path "$ROOT_DIR/work/swiftpm-config"
  --security-path "$ROOT_DIR/work/swiftpm-security"
  --scratch-path "$ROOT_DIR/work/.build"
)

# The installed app in /Applications shares the process name, so only stop
# processes whose executable is this development bundle.
dev_app_pids() {
  local pid
  for pid in $(pgrep -x "$APP_NAME" || true); do
    if [[ "$(ps -o comm= -p "$pid" 2>/dev/null)" == "$APP_MACOS/$APP_NAME" ]]; then
      echo "$pid"
    fi
  done
}

stop_dev_app() {
  local pid
  for pid in $(dev_app_pids); do
    kill "$pid" 2>/dev/null || true
  done
}

cd "$ROOT_DIR"
swift build "${SWIFT_OPTIONS[@]}" -c "$BUILD_CONFIGURATION"
BUILD_DIR="$(swift build "${SWIFT_OPTIONS[@]}" -c "$BUILD_CONFIGURATION" --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_DIR/$APP_NAME" "$APP_MACOS/$APP_NAME"
chmod +x "$APP_MACOS/$APP_NAME"

copy_resource_bundle() {
  local bundle="$BUILD_DIR/$1.bundle"
  if [[ ! -d "$bundle" ]]; then
    echo "Missing SwiftPM resource bundle: $bundle" >&2
    exit 1
  fi
  /usr/bin/ditto "$bundle" "$2/$1.bundle"
}

copy_resource_bundle MaroMarkdown_MaroMarkdown "$APP_RESOURCES"
copy_resource_bundle MaroMarkdown_MaroRenderer "$APP_RESOURCES"

# Quick Look preview extension (Finder space bar). SwiftPM cannot build app
# extensions, so the executable is wrapped in an .appex here.
QL_NAME="MaroQuickLook"
QL_BUNDLE="$APP_CONTENTS/PlugIns/$QL_NAME.appex"
mkdir -p "$QL_BUNDLE/Contents/MacOS" "$QL_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$QL_NAME" "$QL_BUNDLE/Contents/MacOS/$QL_NAME"
copy_resource_bundle MaroMarkdown_MaroRenderer "$QL_BUNDLE/Contents/Resources"

cat >"$QL_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$QL_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID.quicklook</string>
  <key>CFBundleName</key><string>$DISPLAY_NAME Quick Look</string>
  <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.quicklook.preview</string>
    <key>NSExtensionPrincipalClass</key><string>$QL_NAME.PreviewViewController</string>
    <key>NSExtensionAttributes</key>
    <dict>
      <key>QLIsDataBasedPreview</key><false/>
      <key>QLSupportsSearchableItems</key><false/>
      <key>QLSupportedContentTypes</key>
      <array><string>net.daringfireball.markdown</string></array>
    </dict>
  </dict>
</dict></plist>
PLIST

# Extensions must be sandboxed; the previewed file is granted by Quick Look.
QL_ENTITLEMENTS="$ROOT_DIR/Sources/MaroQuickLook/MaroQuickLook.entitlements"

if [[ -f "$ROOT_DIR/Sources/MaroMarkdown/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Sources/MaroMarkdown/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleDocumentTypes</key>
  <array><dict>
    <key>CFBundleTypeName</key><string>Markdown Document</string>
    <key>CFBundleTypeRole</key><string>Editor</string>
    <key>LSHandlerRank</key><string>Alternate</string>
    <key>LSItemContentTypes</key><array><string>net.daringfireball.markdown</string></array>
    <key>CFBundleTypeExtensions</key><array><string>md</string><string>markdown</string><string>mdown</string></array>
  </dict></array>
</dict></plist>
PLIST

/usr/bin/plutil -lint "$APP_CONTENTS/Info.plist" "$QL_BUNDLE/Contents/Info.plist"

if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  # Debug symbols record absolute build paths (the builder's home folder), so release
  # executables are stripped before signing, and the build fails if any path remains.
  for executable in "$APP_MACOS/$APP_NAME" "$QL_BUNDLE/Contents/MacOS/$QL_NAME"; do
    /usr/bin/strip -S -x "$executable"
    if /usr/bin/grep -a -q -F "$ROOT_DIR" "$executable" || /usr/bin/grep -a -q -F "$HOME" "$executable"; then
      echo "Release executable still contains a local build path: $executable" >&2
      exit 1
    fi
  done
fi

# Sign inside-out: the extension first, then the app that contains it.
/usr/bin/codesign --force --sign - --entitlements "$QL_ENTITLEMENTS" "$QL_BUNDLE"
/usr/bin/codesign --force --sign - "$APP_BUNDLE"

open_app() {
  stop_dev_app
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    stop_dev_app
    lldb -- "$APP_MACOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    [[ -n "$(dev_app_pids)" ]]
    ;;
  --build-only|build-only)
    echo "Built $APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--build-only]" >&2
    exit 2
    ;;
esac
