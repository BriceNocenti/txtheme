# PURPOSE: the @font-face block -- the course typeface, delivered.
# ROLE: read by emit_prose_scss(), so the faces travel inside the one stylesheet that already
#   carries the typography. Nothing else in the package knows about a font.
# KEY CONSTRAINTS:
#   - BASE64, not a path. A `url("fonts/x.woff2")` would have to be resolved by pkgdown, by Quarto's
#     extension copier and by pandoc's `embed-resources` -- three different rules, each with its own
#     way of silently not finding the file. A data: URI has no path to get wrong, works offline, and
#     costs ~0.15 MB in a course page that already weighs five.
#   - The five faces are SUBSET (dev/subset_fonts.sh): 3.3 MB of TrueType becomes 112 kB of woff2.
#   - `font-display: swap` -- the text is readable while the face loads, which for a page a student
#     opens from a USB stick is the difference between a blank second and none.
# WARNING: what this replaces was four @font-face rules pointing at raw.githubusercontent.com, in
#   ~/github/formations_stat/style.css -- a third party in the render path of every course page,
#   serving a file GitHub does not promise to keep at that URL, and nothing at all offline.
# See: R/emit-scss.R (emit_prose_scss), inst/prose/prose.scss (the family it declares).

# The faces, and what each one IS: a @font-face is a family plus two axes, and nothing else.
# DejaVu Sans CONDENSED is not decoration -- tab_css() asks for it first for table text, because a
# crosstab of eight columns is read across, and a condensed face is what keeps it on one screen.
TX_FONTS <- tx_grid(tx_tribble(
  ~file,                               ~family,                 ~weight,  ~style,
  "DejaVuSans.woff2",                  "DejaVu Sans",           "normal", "normal",
  "DejaVuSans-Bold.woff2",             "DejaVu Sans",           "bold",   "normal",
  "DejaVuSansCondensed.woff2",         "DejaVu Sans Condensed", "normal", "normal",
  "DejaVuSansCondensed-Bold.woff2",    "DejaVu Sans Condensed", "bold",   "normal",
  "DejaVuSansCondensed-Oblique.woff2", "DejaVu Sans Condensed", "normal", "italic"
))

emit_font_faces <- function(path = ".") {
  dir <- file.path(path, "inst", "fonts")
  unlist(lapply(names(TX_FONTS), function(f) {
    r   <- TX_FONTS[[f]]
    p   <- file.path(dir, f)
    raw <- readBin(p, "raw", file.info(p)$size)
    c("@font-face {",
      sprintf('  font-family: "%s";', r$family),
      sprintf("  font-weight:  %s;", r$weight),
      sprintf("  font-style:   %s;", r$style),
      "  font-display: swap;",
      sprintf('  src: url(data:font/woff2;base64,%s) format("woff2");', tx_base64(raw)),
      "}")
  }))
}

# Base R exports no base64 encoder that takes a raw vector and hands back a string, and txtheme has
# no Imports to borrow one from -- so, the table version. Vectorised over the whole file at once,
# and deterministic, which is what build_theme(check = TRUE) rests on.
TX_B64 <- c(LETTERS, letters, 0:9, "+", "/")

tx_base64 <- function(x) {
  n   <- length(x)
  pad <- (3L - n %% 3L) %% 3L
  m   <- matrix(as.integer(c(x, as.raw(rep(0L, pad)))), nrow = 3L)
  i   <- rbind(bitwShiftR(m[1, ], 2L),
               bitwOr(bitwShiftL(bitwAnd(m[1, ],  3L), 4L), bitwShiftR(m[2, ], 4L)),
               bitwOr(bitwShiftL(bitwAnd(m[2, ], 15L), 2L), bitwShiftR(m[3, ], 6L)),
               bitwAnd(m[3, ], 63L))
  out <- TX_B64[as.vector(i) + 1L]
  if (pad) out[seq.int(length(out) - pad + 1L, length(out))] <- "="
  paste(out, collapse = "")
}
