# PURPOSE: the cross-grid checks, run at namespace load -- txtheme's foreign keys.
# ROLE: what makes "every fact is stated once, in one grid" enforceable rather than a convention. A
#   rename that breaks a reference fails the INSTALL, not a website build three repos away.
# KEY CONSTRAINTS:
#   - Cheap by construction, and free where it matters: pkgdown reads a shipped file with
#     system_file() and never loads this namespace, so nothing here runs on a consumer's CI.
#   - Every check names the grid, the row and the cell -- a load error is read by whoever edited a
#     grid, and it must say which cell to look at.
# See: R/aaa-palette.R for the grids, R/build-theme.R for the checks that need the generator.

# The 31 token types skylighting defines, and pandoc's `.theme` files enumerate. Vendored, because
# it is the vocabulary the whole code theme is a mapping ONTO: a token we invent reaches no consumer,
# and one we forget is silently left at the reader's default.
SKYLIGHTING_TOKENS <- c(
  "Alert", "Annotation", "Attribute", "BaseN", "BuiltIn", "Char", "Comment", "CommentVar",
  "Constant", "ControlFlow", "DataType", "DecVal", "Documentation", "Error", "Extension", "Float",
  "Function", "Import", "Information", "Keyword", "Normal", "Operator", "Other", "Preprocessor",
  "RegionMarker", "SpecialChar", "SpecialString", "String", "Variable", "VerbatimString", "Warning")

.tx_stop <- function(...) stop("txtheme grids: ", ..., call. = FALSE)

# Re-derive what a row records, and refuse a cell that no longer matches its own colour. This is the
# whole discipline: a coordinate is a MEASUREMENT of the hex beside it, never an intention about it.
# Run once PER MODE, so the light half is held to the same standard as the dark one -- a light hex
# with no coordinate beside it would be exactly the drift this check exists to refuse.
.tx_check_mode <- function(name, row, mode) {
  hex <- row[[mode]]
  if (tx_empty(hex)) return(invisible())            # a mode a colour does not declare
  if (!grepl("^#[0-9A-Fa-f]{6}$", hex))
    .tx_stop("'", name, "': `", mode, "` is not a #RRGGBB hex: ", hex)

  rec_cell <- row[[paste0(mode, "_oklch")]]
  if (tx_empty(rec_cell))
    .tx_stop("'", name, "': `", mode, "` is ", hex, " with no `", mode, "_oklch` beside it")
  got <- hex_oklch(hex)
  rec <- as.numeric(strsplit(trimws(rec_cell), " +")[[1]])
  if (length(rec) != 3L)
    .tx_stop("'", name, "': `", mode, "_oklch` must be three numbers, got '", rec_cell, "'")
  d <- abs(c(got[1] - rec[1], got[2] - rec[2], ((got[3] - rec[3] + 180) %% 360) - 180))
  if (any(d > c(5e-3, 5e-3, 0.5)))
    .tx_stop("'", name, "': `", mode, "_oklch` records ", rec_cell, " but ", hex, " is ",
             sprintf("%.3f %.3f %.1f", got[1], got[2], got[3]))

  spec <- row[[paste0(mode, "_spec")]]
  if (tx_empty(spec)) return(invisible())
  s <- strsplit(trimws(spec), " +")[[1]]
  built <- switch(s[1],
    oklch = oklch_hex(as.numeric(s[2]), as.numeric(s[3]), as.numeric(s[4])),
    tint  = hex_tint(TX_PALETTE[[s[2]]][[mode]], as.numeric(s[3])),
    .tx_stop("'", name, "': `", mode, "_spec` starts with an unknown verb '", s[1],
             "' (oklch / tint)"))
  if (!identical(toupper(built), toupper(hex)))
    .tx_stop("'", name, "': `", mode, "_spec` '", spec, "' builds ", built, ", not ", hex)
  invisible()
}

.tx_check_colour <- function(name, row) {
  if (tx_empty(row$dark)) .tx_stop("'", name, "': every colour declares a `dark` hex")
  for (m in TX_MODES) .tx_check_mode(name, row, m)
  invisible()
}

tx_check_grids <- function() {
  # --- TX_PALETTE ---------------------------------------------------------------------------------
  if (anyDuplicated(names(TX_PALETTE))) .tx_stop("TX_PALETTE has a duplicated `name`")
  clash <- intersect(names(TX_PALETTE), BRAND_ROLES)
  if (length(clash))
    .tx_stop("TX_PALETTE names a colour after a brand ROLE: ", paste(clash, collapse = ", "),
             ". Quarto promotes such a palette entry to that role in BOTH modes, silently -- ",
             "rename the colour (the SLOT that paints links may still be called `link`).")
  for (nm in names(TX_PALETTE)) .tx_check_colour(nm, TX_PALETTE[[nm]])

  # --- TX_SLOTS -----------------------------------------------------------------------------------
  if (anyDuplicated(names(TX_SLOTS))) .tx_stop("TX_SLOTS has a duplicated `slot`")
  for (nm in names(TX_SLOTS)) {
    r <- TX_SLOTS[[nm]]
    for (k in c("colour", paste0("colour_", TX_MODES)))
      if (!tx_empty(r[[k]]) && !r[[k]] %in% names(TX_PALETTE))
        .tx_stop("slot '", nm, "': `", k, "` = '", r[[k]], "' is in no TX_PALETTE row")
    if (!r$emit %in% c("chrome", "heading", "prose", "annotation"))
      .tx_stop("slot '", nm, "': `emit` = '", r$emit, "' is not a generator stage")
    if (!tx_empty(r$ground) && !r$ground %in% names(TX_PALETTE))
      .tx_stop("slot '", nm, "': `ground` = '", r$ground, "' is in no TX_PALETTE row")
    n_paint <- sum(!vapply(r[c("bs_var", "css_var", "selector")], tx_empty, logical(1)))
    if (n_paint != 1L)
      .tx_stop("slot '", nm, "': exactly one of bs_var / css_var / selector is filled, found ", n_paint)
    if (!tx_empty(r$selector) && tx_empty(r$prop))
      .tx_stop("slot '", nm, "': a `selector` row needs a `prop`")
    for (v in c(r$bs_var, r$bs_rgb)) if (!tx_empty(v) && !v %in% BS_DARK_VARS)
      .tx_stop("slot '", nm, "': '", v, "' is not one of the ", length(BS_DARK_VARS),
               " properties bootstrap ", BS_VERSION, " emits in dark mode")
  }

  # --- TX_BRAND -----------------------------------------------------------------------------------
  for (nm in names(TX_BRAND)) {
    if (!nm %in% BRAND_ROLES) .tx_stop("TX_BRAND: '", nm, "' is not a brand colour role")
    if (!TX_BRAND[[nm]]$colour %in% names(TX_PALETTE))
      .tx_stop("brand role '", nm, "': `colour` = '", TX_BRAND[[nm]]$colour, "' is in no TX_PALETTE row")
  }

  # --- TX_TOKENS ----------------------------------------------------------------------------------
  if (!setequal(names(TX_TOKENS), SKYLIGHTING_TOKENS))
    .tx_stop("TX_TOKENS is not skylighting's 31 tokens: missing ",
             paste(setdiff(SKYLIGHTING_TOKENS, names(TX_TOKENS)), collapse = ", "), "; extra ",
             paste(setdiff(names(TX_TOKENS), SKYLIGHTING_TOKENS), collapse = ", "))
  cls <- tx_field(TX_TOKENS, "class")
  if (!identical(names(TX_TOKENS)[is.na(cls)], "Normal"))
    .tx_stop("TX_TOKENS: Normal is the only token with no two-letter class (it IS `pre code`)")
  if (anyDuplicated(cls[!is.na(cls)])) .tx_stop("TX_TOKENS has a duplicated `class`")
  if (any(nchar(cls[!is.na(cls)]) != 2L)) .tx_stop("TX_TOKENS: a `class` is not two letters")
  for (nm in names(TX_TOKENS)) if (!TX_TOKENS[[nm]]$colour %in% names(TX_PALETTE))
    .tx_stop("token '", nm, "': `colour` = '", TX_TOKENS[[nm]]$colour, "' is in no TX_PALETTE row")
  for (nm in names(TX_TOKENS)) .tx_check_rstudio_selector(paste0("token '", nm, "'"), TX_TOKENS[[nm]]$ace)

  # --- TX_ACE / TX_ANSI ---------------------------------------------------------------------------
  if (anyDuplicated(names(TX_ACE))) .tx_stop("TX_ACE has a duplicated `slot`")
  for (nm in names(TX_ACE)) {
    r <- TX_ACE[[nm]]
    if (!r$colour %in% names(TX_PALETTE))
      .tx_stop("ace slot '", nm, "': `colour` = '", r$colour, "' is in no TX_PALETTE row")
    if (tx_empty(r$prop)) .tx_stop("ace slot '", nm, "': every row needs a `prop`")
    if (!tx_empty(r$value) && !grepl("{c}", r$value, fixed = TRUE))
      .tx_stop("ace slot '", nm, "': a `value` must say where the colour goes, with {c}")
    .tx_check_rstudio_selector(paste0("ace slot '", nm, "'"), r$selector)
    if (grepl("ace_paren_color_", r$selector, fixed = TRUE) &&
        !grepl("^body \\.ace_paren\\.ace_paren_color_[0-6]$", r$selector))
      .tx_stop("ace slot '", nm, "': a rainbow parenthesis is written `body .ace_paren.ace_paren_color_N`, ",
               "which out-specifies RStudio's own `.editor_dark .ace_paren_color_N` -- anything less ",
               "loses to it and the colour never shows")
  }
  if (!identical(sort(as.integer(names(TX_ANSI))), 0:15))
    .tx_stop("TX_ANSI is not the sixteen ANSI colours 0 to 15")
  for (nm in names(TX_ANSI)) if (!TX_ANSI[[nm]]$colour %in% names(TX_PALETTE))
    .tx_stop("ANSI colour ", nm, ": `colour` = '", TX_ANSI[[nm]]$colour, "' is in no TX_PALETTE row")

  invisible(TRUE)
}

# The classes an RStudio theme may name. Posit guarantees `ace_*` and `rstheme_*` and documents the
# terminal's `terminal` / `xterm*`; everything else "is subject to change at anytime" -- and did:
# `.rstudio-themes-flat` vanished in 2022.02 and broke every theme that leaned on it. The three
# exact names are the ones every theme RStudio bundles still carries, so they break with RStudio's
# own themes or not at all.
RSTUDIO_CLASSES <- list(prefix = c("ace_", "rstheme_", "terminal", "xterm"),
                        exact  = c("nocolor", "rstudio-themes-dark-menus", "focus"))

.tx_check_rstudio_selector <- function(where, selector) {
  if (tx_empty(selector)) return(invisible())
  cls <- regmatches(selector, gregexpr("\\.[A-Za-z_][A-Za-z0-9_-]*", selector))[[1]]
  cls <- substring(cls, 2L)
  ok  <- cls %in% RSTUDIO_CLASSES$exact |
    Reduce(`|`, lapply(RSTUDIO_CLASSES$prefix, startsWith, x = cls), logical(length(cls)))
  if (!all(ok))
    .tx_stop(where, ": the RStudio selector names ", paste0(".", cls[!ok], collapse = ", "),
             ", a class RStudio does not promise to keep (see RSTUDIO_CLASSES)")
  invisible()
}

.onLoad <- function(libname, pkgname) {
  tx_check_grids()
}
