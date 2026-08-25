#!/usr/bin/env bash
# Renders all raster brand assets from the vector masters. Repeatable — never
# hand-edit the generated PNGs. Requires rsvg-convert (preferred) or ImageMagick.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=assets/brand
RES=android/app/src/main/res
DIST=dist
mkdir -p "$DIST"

render() { # render <svg> <size> <out>
  if command -v rsvg-convert >/dev/null; then
    rsvg-convert -w "$2" -h "$2" "$1" -o "$3"
  else
    convert -background none "$1" -resize "$2x$2" "$3"
  fi
}

# Play Store 512x512 (opaque)
render "$SRC/fingenius_mark_dark.svg" 512 "$DIST/play_store_icon_512.png"

# Legacy launcher mipmaps (API 24-25); adaptive icons cover API 26+
declare -A DPIS=( [mdpi]=48 [hdpi]=72 [xhdpi]=96 [xxhdpi]=144 [xxxhdpi]=192 )
for dpi in "${!DPIS[@]}"; do
  size=${DPIS[$dpi]}
  mkdir -p "$RES/mipmap-$dpi"
  render "$SRC/fingenius_mark_dark.svg" "$size" "$RES/mipmap-$dpi/ic_launcher.png"
  # Round variant: circle-masked
  convert "$RES/mipmap-$dpi/ic_launcher.png" \
    \( +clone -alpha extract -fill black -colorize 100 -fill white \
       -draw "circle $((size/2)),$((size/2)) $((size/2)),1" \) \
    -alpha off -compose CopyOpacity -composite \
    "$RES/mipmap-$dpi/ic_launcher_round.png"
done

# Splash logo (transparent mark)
mkdir -p "$RES/drawable-xxhdpi"
render "$SRC/fingenius_mark.svg" 360 "$RES/drawable-xxhdpi/splash_logo.png"

echo "Brand assets rendered."
