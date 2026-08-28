# PURPOSE: the colour maths a palette is designed with -- OKLCH <-> sRGB, the gamut ceiling, and the
#   two contrast models.
# ROLE: the package's exported API, and the one true source for this maths: tabxplor's own dev
#   previews (dev/heading_ladders.R) attach these functions rather than keeping a second copy.
# KEY CONSTRAINTS:
#   - BASE R ONLY. A theme package must install anywhere, on any CI, in seconds -- see R/aaa-grid.R
#     for the dependency arithmetic. Everything here is solve(), matrix() and sprintf().
#   - Out-of-gamut colours lose CHROMA, never lightness or hue, as CSS Color 4 specifies: that is
#     what keeps a ladder's steps even when one rung asks for more saturation than sRGB can show.
#   - A recorded coordinate must be READ BACK off the hex, never the asked-for one. R/aaa-palette.R
#     records both and .onLoad() checks them against each other.
# See: dev/design.md section 7.1 for the palette these were used to choose.

# === SECTION: OKLCH <-> sRGB ======================================================================
# A port of the Ottosson matrices.

.M1 <- matrix(c(0.8189330101, 0.3618667424, -0.1288597137,
                0.0329845436, 0.9293118715,  0.0361456387,
                0.0482003018, 0.2643662691,  0.6338517070), 3, 3, byrow = TRUE)
.M2 <- matrix(c(0.2104542553,  0.7936177850, -0.0040720468,
                1.9779984951, -2.4285922050,  0.4505937099,
                0.0259040371,  0.7827717662, -0.8086757660), 3, 3, byrow = TRUE)
.RGB2XYZ <- matrix(c(0.4124564, 0.3575761, 0.1804375,
                     0.2126729, 0.7151522, 0.0721750,
                     0.0193339, 0.1191920, 0.9503041), 3, 3, byrow = TRUE)

#' sRGB transfer function, and its inverse
#'
#' The gamma encoding sRGB puts between a linear light value and the number stored in a hex.
#'
#' @param c Numeric, in `[0, 1]`. Linear light for `srgb_encode()`, an encoded channel for
#'   `srgb_linear()`.
#' @return A numeric of the same shape as `c`.
#' @examples
#' srgb_encode(srgb_linear(0.5))
#' @export
srgb_encode <- function(c) ifelse(c <= 0.0031308, 12.92 * c, 1.055 * c^(1 / 2.4) - 0.055)

#' @rdname srgb_encode
#' @export
srgb_linear <- function(c) ifelse(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055)^2.4)

.oklch_rgb <- function(L, C, H) {
  ab  <- c(L, C * cos(H * pi / 180), C * sin(H * pi / 180))
  lms <- solve(.M2, ab)^3
  as.vector(solve(.RGB2XYZ) %*% solve(.M1, lms))
}

#' Is an OKLCH colour inside sRGB?
#'
#' @param L,C,H Lightness (`0`-`1`), chroma, hue in degrees.
#' @param eps Tolerance on each linear-RGB channel.
#' @return `TRUE` or `FALSE`.
#' @examples
#' in_gamut(0.95, 0.10, 100)   # the heading ladder's top rung
#' in_gamut(0.95, 0.30, 100)   # no such colour
#' @export
in_gamut <- function(L, C, H, eps = 1e-4) {
  v <- .oklch_rgb(L, C, H)
  all(v >= -eps & v <= 1 + eps)
}

#' An OKLCH colour as a hex string
#'
#' Gamut-maps by reducing CHROMA only, as CSS Color 4 does, so a colour that cannot be shown becomes
#' the most saturated one at the same lightness and hue that can.
#'
#' @inheritParams in_gamut
#' @return An uppercase `"#RRGGBB"` string.
#' @examples
#' oklch_hex(0.95, 0.10, 100)
#' @export
oklch_hex <- function(L, C, H) {
  if (!in_gamut(L, C, H)) {                        # binary-search the chroma back into sRGB
    lo <- 0; hi <- C
    for (i in 1:40) { mid <- (lo + hi) / 2; if (in_gamut(L, mid, H)) lo <- mid else hi <- mid }
    C <- lo
  }
  v <- pmax(0, pmin(1, .oklch_rgb(L, C, H)))
  sprintf("#%02X%02X%02X", round(srgb_encode(v[1]) * 255),
          round(srgb_encode(v[2]) * 255), round(srgb_encode(v[3]) * 255))
}

#' What a hex colour actually is, in OKLCH
#'
#' The read-back that keeps every reported coordinate honest.
#'
#' @param hex A `"#RRGGBB"` string.
#' @return A named numeric of three: `L`, `C`, `H`.
#' @examples
#' hex_oklch("#CDCBBC")
#' @export
hex_oklch <- function(hex) {
  v   <- srgb_linear(strtoi(substring(hex, c(2, 4, 6), c(3, 5, 7)), 16L) / 255)
  lms <- (.M1 %*% (.RGB2XYZ %*% v))^(1 / 3)
  lab <- as.vector(.M2 %*% lms)
  c(L = lab[1], C = sqrt(lab[2]^2 + lab[3]^2),
    H = (atan2(lab[3], lab[2]) * 180 / pi) %% 360)   # `%%` binds tighter than `/` -- parenthesise
}

#' A hex colour as its decimal channels
#'
#' The form a CSS custom property's `-rgb` twin takes: `"205,203,188"`.
#'
#' @inheritParams hex_oklch
#' @return A length-1 character.
#' @examples
#' hex_rgb("#CDCBBC")
#' @export
hex_rgb <- function(hex) paste(strtoi(substring(hex, c(2, 4, 6), c(3, 5, 7)), 16L), collapse = ",")

#' Mix a colour toward white
#'
#' Bootstrap's own `tint-color()`, in gamma-encoded sRGB: it is how Bootstrap 5.3 derives
#' `$link-hover-color` from `$link-color` in dark mode, at `amount = 0.2`.
#'
#' @inheritParams hex_oklch
#' @param amount Fraction of the way to white, `0`-`1`.
#' @return A lowercase `"#rrggbb"` string.
#' @examples
#' hex_tint("#6ea8fe", 0.2)   # bootstrap's own dark link hover, #8bb9fe
#' @export
hex_tint <- function(hex, amount = 0.2) {
  v <- strtoi(substring(hex, c(2, 4, 6), c(3, 5, 7)), 16L)
  sprintf("#%02x%02x%02x", round(v[1] + amount * (255 - v[1])),
          round(v[2] + amount * (255 - v[2])), round(v[3] + amount * (255 - v[3])))
}

# === SECTION: the gamut ceiling ===================================================================
# The one fact every ramp is designed against: CHROMA IS BOUNDED, and the bound depends on BOTH L and
# H. A ramp that ignores it does not fail loudly -- it silently records a chroma it does not have.

# Ottosson's forward matrices, folded. .oklch_rgb() reaches the same numbers through three solve()s
# per call, which costs ~180 matrix inversions per ceiling; a generator evaluates thousands, so the
# ceiling takes this path instead -- measured 28x faster before memoisation.
# WARNING: the published constants are rounded, so this agrees with .oklch_rgb() to 7e-4 on linear
#   RGB and moves max_chroma() by up to 2.3e-4 -- a sixteenth of one hex quantum, and no hex changes,
#   since oklch_hex() still gamut-maps through the solve() path. The test suite asserts both.
.ok_lrgb <- function(L, C, H) {
  hr <- H * pi / 180; a <- C * cos(hr); b <- C * sin(hr)
  l <- (L + 0.3963377774 * a + 0.2158037573 * b)^3
  m <- (L - 0.1055613458 * a - 0.0638541728 * b)^3
  s <- (L - 0.0894841775 * a - 1.2914855480 * b)^3
  c( 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
}

.maxC_cache <- new.env(parent = emptyenv())

#' The most chroma sRGB can show
#'
#' `oklch_hex()` clamps to this silently; `max_chroma()` is what lets a caller SEE the clamp instead.
#' A palette must never record a chroma it does not actually have.
#'
#' @param L Lightness, `0`-`1`.
#' @param H Hue in degrees.
#' @return A length-1 numeric. Hard-capped at `0.4`: a hue whose true ceiling exceeds it returns ~0.4.
#' @examples
#' max_chroma(0.95, 100)   # 0.107 -- which is why the ladder's top rung asks for 0.10
#' max_chroma(0.96, 100)
#' @export
max_chroma <- function(L, H) {
  key <- sprintf("%.4f_%.2f", L, H %% 360)
  hit <- .maxC_cache[[key]]
  if (!is.null(hit)) return(hit)
  lo <- 0; hi <- 0.4
  for (i in 1:30) { m <- (lo + hi) / 2
    v <- .ok_lrgb(L, m, H)
    if (all(v >= -1e-4 & v <= 1 + 1e-4)) lo <- m else hi <- m }
  assign(key, lo, envir = .maxC_cache)
  lo
}

#' Where a hue holds its most chroma
#'
#' The sRGB cusp -- the map a ramp is designed against. Cusp lightness runs from L 0.90 at cyan to
#' 0.46 at violet, which is why a ramp that RISES in lightness cannot keep a hue order without going
#' pale.
#'
#' @inheritParams max_chroma
#' @return A named numeric of two: `L` and `C` at the cusp.
#' @examples
#' oklch_cusp(100)
#' @export
oklch_cusp <- function(H) {
  Ls <- seq(0.03, 0.99, by = 0.002)
  Cs <- vapply(Ls, max_chroma, numeric(1), H = H)
  i  <- which.max(Cs)
  c(L = Ls[i], C = Cs[i])
}

# === SECTION: ramps ===============================================================================

#' A ramp whose chroma is a fraction of the ceiling
#'
#' Asking for a chroma that does not exist becomes impossible rather than merely reported. The
#' `L`/`C`/`H` attributes are READ BACK off the hexes, so a ramp cannot record a coordinate it does
#' not have -- neither the asked-for one nor a rounding of it.
#'
#' @param L,H Lightness and hue per rung; recycled to the longest.
#' @param frac Chroma as a fraction of each rung's own ceiling.
#' @return A character vector of hexes, with `L`, `C`, `H`, `frac` and `cmax` attributes.
#' @examples
#' oklch_ramp(seq(0.95, 0.84, length.out = 6), 0.8, 100)
#' @export
oklch_ramp <- function(L, frac, H) {
  n <- max(length(L), length(frac), length(H))
  L <- rep_len(L, n); frac <- rep_len(frac, n); H <- rep_len(H, n)
  cmax <- vapply(seq_len(n), function(i) max_chroma(L[i], H[i]), numeric(1))
  hex  <- vapply(seq_len(n), function(i) oklch_hex(L[i], frac[i] * cmax[i], H[i]), character(1))
  got  <- vapply(hex, hex_oklch, numeric(3))
  structure(hex, L = got[1, ], C = got[2, ], H = H, frac = frac, cmax = cmax, names = NULL)
}

#' A ramp anchored at both ends
#'
#' `f1` and `f4` are fractions of the ceiling AT THEIR OWN RUNG, and the rungs between follow a
#' geometric line, because a ladder is read as a ratio.
#'
#' WARNING: use this, not a constant fraction, for any ramp that moves in hue. The ceiling is not
#' monotone along a hue path -- on the warm side red at L 0.69 holds 0.196 where orange at L 0.76
#' holds 0.155 -- so one fraction of each rung's own ceiling can make rung 2 LESS saturated than
#' rung 1, inverting the ladder while looking like the honest choice.
#'
#' @param L,H Lightness and hue per rung; recycled to the longest.
#' @param f1,f4 Chroma at the first and last rung, as a fraction of that rung's own ceiling.
#' @return A character vector of hexes, with `L`, `C`, `H` and `cmax` attributes.
#' @examples
#' oklch_ladder(seq(0.95, 0.84, length.out = 6), 100, f1 = 0.95, f4 = 0.5)
#' @export
oklch_ladder <- function(L, H, f1, f4) {
  n <- max(length(L), length(H)); L <- rep_len(L, n); H <- rep_len(H, n)
  cmax <- vapply(seq_len(n), function(i) max_chroma(L[i], H[i]), numeric(1))
  C1   <- f1 * cmax[1]; C4 <- f4 * cmax[n]
  C    <- pmin(C1 * (C4 / C1)^seq(0, 1, length.out = n), cmax)
  hex  <- vapply(seq_len(n), function(i) oklch_hex(L[i], C[i], H[i]), character(1))
  got  <- vapply(hex, hex_oklch, numeric(3))
  structure(hex, L = got[1, ], C = got[2, ], H = H, cmax = cmax, names = NULL)
}

# === SECTION: contrast ============================================================================

.rel_lum <- function(hex) {
  v <- srgb_linear(strtoi(substring(hex, c(2, 4, 6), c(3, 5, 7)), 16L) / 255)
  sum(v * c(0.2126, 0.7152, 0.0722))
}

#' WCAG 2.x contrast ratio
#'
#' Kept for the light half and for reporting. Use [apca()] for anything dark: WCAG 2.x overstates
#' contrast for dark colours badly enough that its own authors say it cannot guide a dark theme.
#'
#' @param a,b Two `"#RRGGBB"` strings.
#' @return A ratio between 1 and 21.
#' @examples
#' contrast("#CDCBBC", "#21252b")
#' @export
contrast <- function(a, b) {
  l <- sort(c(.rel_lum(a), .rel_lum(b)), decreasing = TRUE)
  (l[1] + 0.05) / (l[2] + 0.05)
}

.apca_Y <- function(hex) {
  v <- (strtoi(substring(hex, c(2, 4, 6), c(3, 5, 7)), 16L) / 255)^2.4
  Y <- sum(v * c(0.2126729, 0.7151522, 0.0721750))
  if (Y < 0.022) Y + (0.022 - Y)^1.414 else Y            # soft-clamp the near-black end
}

#' APCA-W3 lightness contrast
#'
#' APCA-W3 0.98G, signed: POSITIVE is dark text on a light ground, NEGATIVE the reverse. The scale to
#' read it on: Lc 90 fluent body text, 75 body columns, 60 content, 45 headlines, 30 spot-readable,
#' 15 invisible.
#'
#' @param text,bg Two `"#RRGGBB"` strings.
#' @return A signed number, rounded to one decimal.
#' @examples
#' apca("#888888", "#ffffff")   # 63.1, Myndex's own reference vector
#' apca("#CDCBBC", "#21252b")
#' @export
apca <- function(text, bg) {
  Yt <- .apca_Y(text); Yb <- .apca_Y(bg)
  if (abs(Yb - Yt) < 0.0005) return(0)
  S <- if (Yb > Yt) (Yb^0.56 - Yt^0.57) * 1.14 else (Yb^0.65 - Yt^0.62) * 1.14
  round((if (abs(S) < 0.1) 0 else if (S > 0) S - 0.027 else S + 0.027) * 100, 1)
}
