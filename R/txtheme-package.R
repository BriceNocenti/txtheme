#' txtheme: one palette for pkgdown, Quarto and the editor
#'
#' A colour is decided once, in one declared grid (`R/aaa-palette.R`), and every consumer reads what
#' [build_theme()] writes from it: a pkgdown site through `template: package: txtheme`, a Quarto
#' document through the bundled extension, and the editor through a ready `textMateRules` block.
#'
#' The exported functions are of two kinds: [build_theme()], [txtheme_file()] and [use_brand()] drive
#' the framework; [oklch_hex()], [hex_oklch()], [max_chroma()], [oklch_ramp()], [oklch_ladder()],
#' [apca()] and [contrast()] are the colour maths the palette was designed with, base R only, usable
#' anywhere.
#'
#' @keywords internal
"_PACKAGE"
