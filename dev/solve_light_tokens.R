# PURPOSE: how the LIGHT half of the six code-theme hues was obtained, kept runnable.
# ROLE: not part of the package. TX_PALETTE records the RESULT (a hex, its coordinate, its spec);
#   this is the search that produced it, so the numbers can be re-derived rather than trusted.
# Usage: Rscript dev/solve_light_tokens.R   (from the package root)
#
# THE RULE: hold the CHROMA and let the LIGHTNESS follow the hue.
#   A flat lightness cannot work, and the reason is the sRGB ceiling: at L 0.52 the green and the
#   cyan are already AT it (100 % of what the hue can hold) while the pink still has room, so a
#   flat-L palette silently flattens exactly the hues that needed the help. Every hand-made light
#   palette has the other shape -- Flexoki 600 spans L 0.45-0.63, Atom One Light L 0.52-0.71 --
#   and this is that shape, derived: ask each hue for C = 0.145 and take the FIRST lightness that
#   can hold it, walking up from 0.40.
#
# WHAT THAT COSTS, stated because it is a real trade and it was made with the rendering in hand:
#   the cyan can only hold 0.145 high up (L 0.72), so it comes out bright -- APCA 40 against the
#   code ground, where the other five sit at 63-84. It was read on the page and kept: `DataType` is
#   a rare token in R, it is set in italics, and the alternative was a cyan so grey it stopped
#   being a hue. Contrast is not the only thing a code theme is for.
devtools::load_all(".", quiet = TRUE)

GROUND <- "#F4F4EF"   # code-page, light
TARGET <- 0.145       # the chroma every hue is asked for

solve_hue <- function(dark_hex, target = TARGET, floor_L = 0.42, ceil_L = 0.72) {
  H  <- hex_oklch(dark_hex)[[3]]
  Ls <- seq(floor_L, ceil_L, by = 0.002)
  cm <- vapply(Ls, max_chroma, numeric(1), H = H)
  i  <- which(cm >= target)[1]
  L  <- if (is.na(i)) Ls[which.max(cm)] else Ls[i]
  oklch_hex(L, min(target, 0.93 * max_chroma(L, H)), H)
}

report <- function(nm, hex) {
  m <- hex_oklch(hex)
  cat(sprintf('%-13s "%s"  spec "oklch %.3f %.3f %.1f"  oklch "%.3f %.3f %5.1f"   APCA %.1f\n',
              nm, hex, m[1], m[2], m[3], m[1], m[2], m[3], abs(apca(hex, GROUND))))
}

for (nm in c("keyword", "string", "constant", "datatype", "inline-code", "accent"))
  report(nm, solve_hue(TX_PALETTE[[nm]]$dark))

# The link's hover state is the accent one step down, as on the dark side it is one step up.
acc <- solve_hue(TX_PALETTE$accent$dark)
report("accent-hover", oklch_hex(hex_oklch(acc)[[1]] - 0.07, hex_oklch(acc)[[2]], hex_oklch(acc)[[3]]))

# The two greys are placed by their RELATION to the prose, not by contrast: on a dark page the
# comment sits below the ink and the punctuation just above it, so on a light page both sit above
# the ink, the comment further -- a comment recedes, and the italics carry the rest.
report("comment",     oklch_hex(0.580, 0.008, hex_oklch(TX_PALETTE$comment$dark)[[3]]))
report("punctuation", oklch_hex(0.520, 0.004, hex_oklch(TX_PALETTE$punctuation$dark)[[3]]))
