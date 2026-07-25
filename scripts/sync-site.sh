#!/bin/bash
# Sync the Loadout landing page into the personal website repo, which is
# the single deploy for ovsh.github.io/loadout/. Run after editing site/.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/../site" && pwd)"
DEST="$HOME/Documents/code/personal-website/loadout"
mkdir -p "$DEST/assets/fonts" "$DEST/assets/sim"
cp "$SRC/index.html" "$DEST/"
cp "$SRC/assets/appicon.png" "$SRC/assets/og.jpg" "$DEST/assets/"
cp "$SRC/assets/sim/"*.webp "$DEST/assets/sim/"
cp "$SRC/assets/fonts/archivo-var.woff2" "$DEST/assets/fonts/"
# Drop deploy-side assets the page no longer references
rm -f "$DEST/assets/menubar.png" "$DEST/assets/library.png" \
      "$DEST/assets/popover.png" "$DEST/assets/bulk.png"
echo "Synced site/ -> $DEST (commit and push personal-website to deploy)"
