# PURPOSE: the RStudio theme writer -- one `.rstheme` file, plain CSS, that RStudio installs with
#   rstudioapi::addTheme() and nothing else.
# ROLE: the fourth consumer of TX_TOKENS (its `ace` column) and the only reader of TX_ACE / TX_ANSI.
#   A word takes the colour of the same skylighting token on a page, so the courses' code blocks and
#   the students' RStudio agree by construction, not by a second palette kept in step by hand.
# KEY CONSTRAINTS:
#   - PLAIN CSS, NEVER A .tmTheme OR A .scss. A tmTheme is converted at import, which needs the
#     `xml2` package on the student's machine and loses detail (RStudio's R names are `identifier`
#     tokens, which no tmTheme `variable` scope reaches); a `.scss` needs `sass`. A `.rstheme` is read
#     as it stands by every RStudio since 1.2.
#   - THE TWO HEADER LINES COME FIRST. RStudio reads `rs-theme-name` and `rs-theme-is-dark` with a
#     regex over the file; without the second, a dark theme is taken for a LIGHT one and the panes,
#     the menus and the links stay light around a dark editor, with only a line in RStudio's log.
#   - One line per rule, as every other writer here, so build_theme(check = TRUE) diffs cleanly.
# See: R/aaa-palette.R (TX_TOKENS$ace, TX_ACE, TX_ANSI), dev/design.md section 5.2.

# The name RStudio lists the theme under, and the one a script checks with getThemeInfo()$editor.
# Lower-cased, it is also RStudio's KEY: a user theme with the name of a bundled one replaces it.
tx_rstheme_name <- function(mode = "dark") if (mode == "dark") "txtheme" else paste("txtheme", mode)

# The 240 fixed xterm colours after the sixteen of TX_ANSI: the 6x6x6 cube, then the grey ramp.
tx_xterm_256 <- function() {
  lv   <- c(0, 95, 135, 175, 215, 255)
  cube <- expand.grid(b = lv, g = lv, r = lv)[, c("r", "g", "b")]
  grey <- 8 + 10 * (0:23)
  rgb  <- rbind(as.matrix(cube), cbind(grey, grey, grey))
  sprintf("#%02x%02x%02x", rgb[, 1], rgb[, 2], rgb[, 3])
}

# Not a colour, so not a row: the layering and the text attributes every bundled theme carries. The
# z-indexes keep the marker layer (selection, active line) UNDER the text.
TX_RSTHEME_STATIC <- c(
  ".ace_layer { z-index: 3; }",
  ".ace_layer.ace_print-margin-layer { z-index: 2; }",
  ".ace_layer.ace_marker-layer { z-index: 1; }",
  '.terminal { font-feature-settings: "liga" 0; position: relative; user-select: none; -ms-user-select: none; -webkit-user-select: none; }',
  ".xtermBold { font-weight: bold; }",
  ".xtermBlur { filter: brightness(75%); }",
  ".xtermUnderline { text-decoration: underline; }",
  ".xtermBlink { text-decoration: blink; }",
  ".xtermHidden { visibility: hidden; }",
  ".xtermItalic { font-style: italic; }",
  ".xtermStrike { text-decoration: line-through; }")

# TX_ACE folded into rules, one per selector in first-appearance order -- the shape
# tx_selector_rules() gives the page's own slots.
tx_ace_rules <- function(mode = "dark") {
  sel <- vapply(TX_ACE, function(r) r$selector, character(1))
  vapply(unique(sel), function(k) {
    decls <- character(0)
    for (r in TX_ACE[sel == k]) {
      v <- tx_value(r, mode)
      if (!tx_empty(r$value)) v <- sub("{c}", v, r$value, fixed = TRUE)
      decls <- c(decls, sprintf("%s: %s;", r$prop, v))
      if (!tx_empty(r$style)) decls <- c(decls, paste0(sub(";\\s*$", "", r$style), ";"))
    }
    sprintf("%s { %s }", k, paste(decls, collapse = " "))
  }, character(1), USE.NAMES = FALSE)
}

# The syntax tokens: every TX_TOKENS row with an `ace` selector, in the order of the other writers.
tx_ace_token_rules <- function(mode = "dark") {
  toks <- Filter(function(nm) !tx_empty(TX_TOKENS[[nm]]$ace), tx_tokens_by_class())
  vapply(toks, function(nm) {
    t <- TX_TOKENS[[nm]]
    dec <- paste0("color: ", tx_hex(t$colour, mode), ";")
    if (!tx_empty(t$style)) dec <- paste(dec, paste0(sub(";\\s*$", "", t$style), ";"))
    sprintf("%s { %s } /* %s */", t$ace, dec, nm)
  }, character(1), USE.NAMES = FALSE)
}

tx_xterm_rules <- function(mode = "dark") {
  ansi <- vapply(as.character(0:15), function(i) tx_hex(TX_ANSI[[i]]$colour, mode), character(1))
  hex  <- c(ansi, tx_xterm_256())
  i    <- seq_along(hex) - 1L
  c(sprintf(".xtermColor%d { color: %s !important; }", i, hex),
    sprintf(".xtermBgColor%d { background-color: %s; }", i, hex))
}

emit_rstheme <- function(mode = "dark") {
  c(sprintf("/* rs-theme-name: %s */", tx_rstheme_name(mode)),
    sprintf("/* rs-theme-is-dark: %s */", if (mode == "dark") "TRUE" else "FALSE"),
    tx_banner(c("", paste0("The ", mode, " RStudio theme: the courses' code colours, in the editor the ",
                           "students write in."),
                "Install: rstudioapi::addTheme(\"txtheme.rstheme\", apply = TRUE). Plain CSS, so no",
                "conversion and no package beyond rstudioapi."), style = "/*"),
    "", "/* the editor, its markers and its popups */", tx_ace_rules(mode),
    "", "/* the syntax tokens -- TX_TOKENS' `ace` column, the page's own colours */", tx_ace_token_rules(mode),
    "", "/* layering and text attributes */", TX_RSTHEME_STATIC,
    "", "/* the terminal: sixteen ANSI colours from the palette, then the fixed xterm 256 */",
    tx_xterm_rules(mode))
}
