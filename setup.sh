#!/usr/bin/env bash
# Deep Research skill — one-time setup
# Usage (new machine):
#   git clone -b feat/minimize-restore https://github.com/andylizf/playwright-cli.git ~/.deep-research/playwright-cli
#   cd ~/.deep-research/playwright-cli && npm install
#   bash macos/setup.sh
# Usage (already cloned):
#   bash ~/.deep-research/playwright-cli/macos/setup.sh
set -euo pipefail

DIR="$HOME/.deep-research"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$DIR/browser-profile"

# ── 1. Patched playwright-cli (local) ──
if [ ! -f "$DIR/playwright-cli/playwright-cli.js" ]; then
  echo "==> Installing patched playwright-cli..."
  git clone -b feat/minimize-restore https://github.com/andylizf/playwright-cli.git "$DIR/playwright-cli"
  (cd "$DIR/playwright-cli" && npm install)
elif [ ! -d "$DIR/playwright-cli/node_modules" ]; then
  echo "==> Installing playwright-cli dependencies..."
  (cd "$DIR/playwright-cli" && npm install)
else
  echo "==> playwright-cli already installed"
fi

# ── 2. APFS clone Chrome + re-sign ──
SYS_CHROME="/Applications/Google Chrome.app"
if [ ! -d "$SYS_CHROME" ]; then
  echo "ERROR: Google Chrome not found at $SYS_CHROME" >&2
  exit 1
fi

# Re-clone if system Chrome is newer than our copy
if [ ! -d "$DIR/Chrome.app" ] || \
   [ "$SYS_CHROME/Contents/MacOS/Google Chrome" -nt "$DIR/Chrome.app/Contents/MacOS/Google Chrome" ]; then
  echo "==> Cloning Chrome (APFS copy-on-write)..."
  rm -rf "$DIR/Chrome.app"
  /bin/cp -Rc "$SYS_CHROME" "$DIR/Chrome.app"
  echo "==> Re-signing Chrome binary..."
  xattr -cr "$DIR/Chrome.app"
  codesign --force --sign - "$DIR/Chrome.app/Contents/MacOS/Google Chrome"
else
  echo "==> Chrome clone up to date"
fi

# ── 3. Compile DYLD hook ──
if [ ! -f "$DIR/window_suppress.dylib" ] || \
   [ "$SKILL_DIR/window_suppress.m" -nt "$DIR/window_suppress.dylib" ]; then
  echo "==> Compiling window_suppress.dylib..."
  cc -dynamiclib -framework AppKit -framework Foundation \
     -o "$DIR/window_suppress.dylib" "$SKILL_DIR/window_suppress.m"
else
  echo "==> window_suppress.dylib up to date"
fi

# ── 4. Compile window_alpha tool ──
if [ ! -f "$DIR/window_alpha" ] || \
   [ "$SKILL_DIR/window_alpha.m" -nt "$DIR/window_alpha" ]; then
  echo "==> Compiling window_alpha..."
  cc -framework CoreGraphics -framework CoreFoundation \
     -o "$DIR/window_alpha" "$SKILL_DIR/window_alpha.m"
else
  echo "==> window_alpha up to date"
fi

# ── 5. Create config ──
if [ ! -f "$DIR/cli.config.json" ]; then
  echo "==> Creating cli.config.json..."
  cat > "$DIR/cli.config.json" << 'EOF'
{"browser":{"browserName":"chromium","launchOptions":{"channel":"chrome","headless":false,"args":["--start-minimized"]},"isolated":false}}
EOF
else
  echo "==> cli.config.json exists"
fi

echo ""
echo "Setup complete. Files in $DIR:"
ls -1 "$DIR/"
