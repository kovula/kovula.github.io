#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob

SRC_DIR="$PWD"
DIST_SYMLINK="dist"
EXPECTED_TARGET="docs"

# Ensure repo uses version-controlled hooks
if [ "$(git config --get core.hooksPath)" != ".githooks" ]; then
    echo "[setup] Setting git hooksPath to .githooks"
    git config core.hooksPath .githooks
fi


if [ ! -L "$DIST_SYMLINK" ]; then
    echo "[error] dist/ must be a symlink (expected: dist -> docs)"
    exit 1
fi
DIST_REAL="$(readlink "$DIST_SYMLINK")"
if [ "$DIST_REAL" != "$EXPECTED_TARGET" ]; then
    echo "[error] dist/ must point exactly to './docs' (got: '$DIST_REAL')"
    exit 1
fi
DIST_REAL_PATH="$PWD/$DIST_REAL"
case "$DIST_REAL_PATH" in
    "$PWD"/*) ;;
    *)
        echo "[error] dist/ resolved outside project directory!"
        exit 1
        ;;
esac

echo "[build] dist/ correctly points to: $DIST_REAL_PATH"


echo "[build] Cleaning output directory…"
rm -rf "$DIST_REAL_PATH"
mkdir -p "$DIST_REAL_PATH"

FAVICON_SOURCE="$SRC_DIR/icon.svg"

if [ ! -f "$FAVICON_SOURCE" ]; then
    echo "[error] Favicon source '${FAVICON_SOURCE}' not found."
    exit 1
fi

echo "[build] Generating favicon and touch icons…"

# Base SVG variants
cp "$FAVICON_SOURCE" "$DIST_REAL_PATH/favicon.svg"
cp "$FAVICON_SOURCE" "$DIST_REAL_PATH/mask-icon.svg"

# Raster PNG outputs
rsvg-convert -w 180 -h 180 "$FAVICON_SOURCE" -o "$DIST_REAL_PATH/apple-touch-icon.png"
rsvg-convert -w 512 -h 512 "$FAVICON_SOURCE" -o "$DIST_REAL_PATH/android-chrome-512x512.png"

# Multi-resolution ICO
magick -background transparent \
    -define 'icon:auto-resize=16,24,32,64' \
    "$DIST_REAL_PATH/android-chrome-512x512.png" \
    "$DIST_REAL_PATH/favicon.ico"

for src in "$SRC_DIR"/*.html "$SRC_DIR"/*.css "$SRC_DIR"/play.js "$SRC_DIR"/kovula.svg; do
    [ -e "$src" ] || continue
    filename="$(basename "$src")"

    echo "[build] Minifying $filename…"
    minify -o "$DIST_REAL_PATH/$filename" "$src"
done

mkdir -p "$DIST_REAL_PATH/fonts"
for src in "$SRC_DIR"/fonts/*.woff2; do
    [ -e "$src" ] || continue
    filename="$(basename "$src")"
    echo "[build] Copying fonts $filename…"
    cp "$src" "$DIST_REAL_PATH/fonts/$filename"
done

mkdir -p "$DIST_REAL_PATH/audio"
for src in "$SRC_DIR"/audio/*.mp3; do
    [ -e "$src" ] || continue
    filename="$(basename "$src")"
    echo "[build] Copying audio $filename…"
    cp "$src" "$DIST_REAL_PATH/audio/$filename"
done

if [ -f "$SRC_DIR/CNAME" ]; then
    echo "[build] Copying CNAME…"
    cp "$SRC_DIR/CNAME" "$DIST_REAL_PATH/CNAME"
fi

if [ -f "$SRC_DIR/robots.txt" ]; then
    echo "[build] Copying robots.txt…"
    cp "$SRC_DIR/robots.txt" "$DIST_REAL_PATH/robots.txt"
fi

# ---------------------------------------------------------------------------

echo "[build] Done."
echo "[build] Output available in: $DIST_REAL_PATH"
