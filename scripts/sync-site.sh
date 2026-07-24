#!/bin/bash
# Sync the Loadout landing page into the personal website repo, which is
# the single deploy for ovsh.github.io/loadout/. Run after editing site/.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/../site" && pwd)"
DEST="$HOME/Documents/code/personal-website/loadout"
mkdir -p "$DEST/assets/fonts"
cp "$SRC/index.html" "$DEST/"
cp "$SRC/assets/appicon.png" "$SRC/assets/menubar.png" \
   "$SRC/assets/library.png" "$SRC/assets/popover.png" \
   "$SRC/assets/bulk.png" "$DEST/assets/"
cp "$SRC/assets/fonts/archivo-var.woff2" "$DEST/assets/fonts/"
echo "Synced site/ -> $DEST (commit and push personal-website to deploy)"
