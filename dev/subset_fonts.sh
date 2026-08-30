#!/usr/bin/env bash
# PURPOSE: rebuild inst/fonts/*.woff2 from the installed DejaVu TrueType faces.
# ROLE: run by hand, almost never -- the .woff2 files are committed, and a font does not change.
#   build_theme() base64-encodes whatever is in inst/fonts into the prose stylesheet.
# WHY SUBSET: the five full .ttf faces are 3.3 MB; subset to latin plus the typographic characters
#   the courses actually use, they are 112 kB, which is ~0.15 MB once base64'd into a document.
# Requires: fonttools with brotli (uv run --with 'fonttools[woff]' takes care of both).
set -euo pipefail
SRC=${1:-/usr/local/share/fonts/windows}
OUT=$(dirname "$0")/../inst/fonts
# latin-1 + the punctuation the courses set: curly quotes, dashes, ellipsis, narrow no-break space,
# the maths signs tabxplor prints (≤ ≥ × ·) and sigma, which the regression tables name.
UNICODES='U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0192,U+2000-206F,U+2074,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD,U+0300-036F,U+2018-201F,U+2026,U+202F,U+2264,U+2265,U+00D7,U+00B7,U+03C3'
for f in DejaVuSans DejaVuSans-Bold DejaVuSansCondensed DejaVuSansCondensed-Bold DejaVuSansCondensed-Oblique; do
  pyftsubset "$SRC/$f.ttf" --unicodes="$UNICODES" --layout-features='*' \
             --flavor=woff2 --output-file="$OUT/$f.woff2"
  printf '%-32s %6.1f kB\n' "$f.woff2" "$(stat -c%s "$OUT/$f.woff2" | awk '{print $1/1024}')"
done
