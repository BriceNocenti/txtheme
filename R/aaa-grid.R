# PURPOSE: how a declared fact table is WRITTEN, and the fold that turns the written grid into the
#   shape every reader indexes.
# ROLE: the package's one shared mechanism. A fact table states each fact once, in one row; this file
#   says what that row looks like on the page and hands back a named list of named lists.
# KEY CONSTRAINTS:
#   - This file sorts FIRST in C collation, and must: a grid is folded at SOURCE time.
#   - BASE R ONLY, here and everywhere. This is the whole reason the package has no Imports:
#     pkgdown never loads txtheme's R code (it reads a shipped file with system.file()), so on a
#     website build the package only has to INSTALL. Pulling tibble/vctrs/rlang in for the shape of
#     tribble() would tax every consumer's CI for something nothing R-side ever runs.
#   - A NULL cell means "this row has no such field" and is DROPPED, so `%||%` reads keep working;
#     NA means the field is declared and empty, and is kept.
# See: R/aaa-palette.R for the three grids this folds, dev/design.md for the framework.

# THE GRID RULE -- one row per fact, fields in one fixed order, aligned in columns, a column
# dictionary immediately above, nothing about a row stated anywhere else. A row may run long: it is
# a grid, not prose, and it is read unwrapped.

# tribble()'s shape without tribble(): column names first as one-sided formulas, then the cells,
# row-major. Returns a named list of columns, which tx_grid() folds.
tx_tribble <- function(...) {
  args <- list(...)
  is_h <- vapply(args, function(a) inherits(a, "formula") && length(a) == 2L, logical(1))
  n_h  <- if (length(is_h)) sum(cumprod(is_h)) else 0L        # the leading run of ~name arguments
  if (n_h == 0L) stop("tx_tribble(): the column names come first, as one-sided formulas (~name).")
  nms   <- vapply(args[seq_len(n_h)], function(f) as.character(f[[2L]]), character(1))
  cells <- args[-seq_len(n_h)]
  if (length(cells) %% n_h != 0L)
    stop("tx_tribble(): ", length(cells), " cells is not a multiple of the ", n_h, " columns (",
         paste(nms, collapse = ", "), ").")
  out <- lapply(seq_len(n_h), function(j) {
    col <- cells[seq(j, length(cells), by = n_h)]
    if (all(vapply(col, function(v) is.atomic(v) && length(v) == 1L, logical(1)))) unlist(col) else col
  })
  names(out) <- nms
  out
}

# Fold a written grid into the named list of named lists every reader indexes. `key` names the
# column holding the row names.
tx_grid <- function(x, key = 1L) {
  keys <- as.character(x[[key]])
  cols <- setdiff(names(x), names(x)[[key]])
  rows <- lapply(seq_along(keys), function(i) {
    r <- lapply(cols, function(cn) { v <- x[[cn]]; if (is.list(v)) v[[i]] else v[[i]] })
    names(r) <- cols
    r[!vapply(r, is.null, logical(1))]
  })
  names(rows) <- keys
  rows
}

# Read one field down a folded grid, as a vector. NA where the row has no such field.
tx_field <- function(grid, field) {
  out <- lapply(grid, function(r) if (is.null(r[[field]])) NA else r[[field]])
  if (all(vapply(out, function(v) is.atomic(v) && length(v) == 1L, logical(1)))) unlist(out) else out
}

# The rows of a folded grid whose `field` equals `value` -- what replaces a switch() in the emitters.
tx_where <- function(grid, field, value) {
  keep <- vapply(grid, function(r) isTRUE(r[[field]] %in% value), logical(1))
  grid[keep]
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# A cell that was written but left empty. NA and "" both mean "no value here".
tx_empty <- function(x) is.null(x) || length(x) != 1L || is.na(x) || !nzchar(as.character(x))
