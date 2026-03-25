#!/usr/bin/env bash
# Deep Research skill — one-time setup
# Usage:
#   git clone https://github.com/andylizf/deep-research-skill.git ~/.tmp/deep-research-skill
#   bash ~/.tmp/deep-research-skill/setup.sh
set -euo pipefail

DIR="$HOME/.deep-research"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$DIR/browser-profile"

# ── 1. Install official playwright-cli locally + apply patches ──
if [ ! -f "$DIR/playwright-cli/node_modules/playwright-core/lib/server/browserType.js" ]; then
  echo "==> Installing @playwright/cli locally..."
  mkdir -p "$DIR/playwright-cli"
  (cd "$DIR/playwright-cli" && npm init -y --silent && npm install @playwright/cli --silent)
fi

# Apply patches (idempotent — checks before applying)
for patchfile in "$SKILL_DIR"/start-minimized-*.patch; do
  [ -f "$patchfile" ] || continue
  name="$(basename "$patchfile")"
  if (cd "$DIR/playwright-cli" && patch -p0 --dry-run < "$patchfile" >/dev/null 2>&1); then
    echo "==> Applying $name..."
    (cd "$DIR/playwright-cli" && patch -p0 < "$patchfile")
  else
    echo "==> $name already applied or version changed, skipping"
  fi
done

# Create launcher symlink
ln -sf "$DIR/playwright-cli/node_modules/.bin/playwright-cli" "$DIR/pw"

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
