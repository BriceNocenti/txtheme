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
.tx_check_colour <- function(name, row) {
  hex <- row$dark
  if (!grepl("^#[0-9A-Fa-f]{6}$", hex)) .tx_stop("'", name, "': `dark` is not a #RRGGBB hex: ", hex)
  if (!tx_empty(row$light) && !grepl("^#[0-9A-Fa-f]{6}$", row$light))
    .tx_stop("'", name, "': `light` is not a #RRGGBB hex: ", row$light)

  got <- hex_oklch(hex)
  rec <- as.numeric(strsplit(trimws(row$oklch), " +")[[1]])
  if (length(rec) != 3L) .tx_stop("'", name, "': `oklch` must be three numbers, got '", row$oklch, "'")
  d <- abs(c(got[1] - rec[1], got[2] - rec[2], ((got[3] - rec[3] + 180) %% 360) - 180))
  if (any(d > c(5e-3, 5e-3, 0.5)))
    .tx_stop("'", name, "': `oklch` records ", row$oklch, " but ", hex, " is ",
             sprintf("%.3f %.3f %.1f", got[1], got[2], got[3]))

  if (tx_empty(row$spec)) return(invisible())
  s <- strsplit(trimws(row$spec), " +")[[1]]
  built <- switch(s[1],
    oklch = oklch_hex(as.numeric(s[2]), as.numeric(s[3]), as.numeric(s[4])),
    tint  = hex_tint(TX_PALETTE[[s[2]]]$dark, as.numeric(s[3])),
    .tx_stop("'", name, "': `spec` starts with an unknown verb '", s[1], "' (oklch / tint)"))
  if (!identical(toupper(built), toupper(hex)))
    .tx_stop("'", name, "': `spec` '", row$spec, "' builds ", built, ", not ", hex)
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
    if (!r$colour %in% names(TX_PALETTE))
      .tx_stop("slot '", nm, "': `colour` = '", r$colour, "' is in no TX_PALETTE row")
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

  invisible(TRUE)
}

.onLoad <- function(libname, pkgname) {
  tx_check_grids()
}
