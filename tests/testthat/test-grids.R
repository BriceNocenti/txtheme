# The grids' own contract: every fact stated once, every reference resolving, every recorded
# coordinate a measurement of the hex beside it. tx_check_grids() runs at load, so a broken grid
# fails the install -- these tests say WHICH rule broke.

test_that("the load-time checks pass", {
  expect_true(txtheme:::tx_check_grids())
})

test_that("TX_TOKENS is skylighting's 31, once each", {
  tok <- txtheme:::TX_TOKENS
  expect_setequal(names(tok), txtheme:::SKYLIGHTING_TOKENS)
  expect_length(tok, 31L)
  cls <- txtheme:::tx_field(tok, "class")
  expect_equal(sum(is.na(cls)), 1L)            # Normal alone: it IS `pre code`
  expect_false(anyDuplicated(cls[!is.na(cls)]) > 0)
})

test_that("every foreign key resolves in TX_PALETTE", {
  pal <- names(txtheme:::TX_PALETTE)
  expect_true(all(txtheme:::tx_field(txtheme:::TX_SLOTS,  "colour") %in% pal))
  expect_true(all(txtheme:::tx_field(txtheme:::TX_TOKENS, "colour") %in% pal))
  expect_true(all(txtheme:::tx_field(txtheme:::TX_BRAND,  "colour") %in% pal))
})

test_that("no colour is named after a Quarto brand role", {
  # Quarto promotes a `color.palette` entry whose NAME is a role to that role, in BOTH modes and
  # with no message -- which once put the dark accent blue on the light page.
  expect_length(intersect(names(txtheme:::TX_PALETTE), txtheme:::BRAND_ROLES), 0L)
})

test_that("every recorded oklch is the hex's own, and every spec builds its hex, in every mode", {
  for (mode in txtheme:::TX_MODES) for (nm in names(txtheme:::TX_PALETTE)) {
    row <- txtheme:::TX_PALETTE[[nm]]
    hex <- row[[mode]]
    if (txtheme:::tx_empty(hex)) next                 # a mode this colour does not declare
    lab <- paste0(nm, " (", mode, ")")
    got <- hex_oklch(hex)
    rec <- as.numeric(strsplit(trimws(row[[paste0(mode, "_oklch")]]), " +")[[1]])
    expect_equal(unname(got[1:2]), rec[1:2], tolerance = 5e-3, info = lab)
    expect_lt(abs(((got[3] - rec[3] + 180) %% 360) - 180), 0.5, label = lab)
    spec <- row[[paste0(mode, "_spec")]]
    if (!txtheme:::tx_empty(spec)) {
      s <- strsplit(trimws(spec), " +")[[1]]
      built <- switch(s[1],
        oklch = oklch_hex(as.numeric(s[2]), as.numeric(s[3]), as.numeric(s[4])),
        tint  = hex_tint(txtheme:::TX_PALETTE[[s[2]]][[mode]], as.numeric(s[3])))
      expect_equal(toupper(built), toupper(hex), info = lab)
    }
  }
})

test_that("a colour declares a coordinate for every hex it declares", {
  # The one thing a light half could quietly skip. A hex with no measurement beside it is exactly
  # the drift .tx_check_mode() exists to refuse, so assert the shape as well as the values.
  for (mode in txtheme:::TX_MODES) for (nm in names(txtheme:::TX_PALETTE)) {
    row <- txtheme:::TX_PALETTE[[nm]]
    if (txtheme:::tx_empty(row[[mode]])) next
    expect_false(txtheme:::tx_empty(row[[paste0(mode, "_oklch")]]), info = paste(nm, mode))
  }
})

test_that("the heading ladder runs from the page towards the ink, in both modes", {
  # Dark: h1 is the BRIGHTEST and h6 lands on the ink. Light: the mirror -- h1 the darkest, h6 on
  # the ink again. Either way a heading never recedes past the prose it leads, which is the whole
  # point of the floor (dark) / ceiling (light).
  for (mode in txtheme:::TX_MODES) {
    L <- vapply(paste0("heading-", 1:6),
                function(k) unname(hex_oklch(txtheme:::TX_PALETTE[[k]][[mode]])["L"]), numeric(1))
    ink <- unname(hex_oklch(txtheme:::TX_PALETTE$ink[[mode]])["L"])
    page <- unname(hex_oklch(txtheme:::TX_PALETTE$page[[mode]])["L"])
    away <- if (page < ink) -1 else 1                  # towards the ink, away from the page
    expect_true(all(sign(diff(L)) == away), info = mode)
    # 5e-3 is the grids' own tolerance: both ends are 8-bit hexes, and a chroma of 0.03 moves the
    # measured L off the requested one by more than a relative 2e-3 at this lightness.
    expect_equal(unname(L[6]), ink, tolerance = 5e-3, info = mode)
  }
})

test_that("a slot paints in exactly one vocabulary", {
  for (nm in names(txtheme:::TX_SLOTS)) {
    r <- txtheme:::TX_SLOTS[[nm]]
    n <- sum(!vapply(r[c("bs_var", "css_var", "selector")], txtheme:::tx_empty, logical(1)))
    expect_equal(n, 1L, info = nm)
  }
})

test_that("every bootstrap property named is one bootstrap emits", {
  v <- c(txtheme:::tx_field(txtheme:::TX_SLOTS, "bs_var"),
         txtheme:::tx_field(txtheme:::TX_SLOTS, "bs_rgb"))
  expect_true(all(v[!is.na(v)] %in% txtheme:::BS_DARK_VARS))
  expect_length(txtheme:::BS_DARK_VARS, 52L)
})

test_that("a slot may be painted by a different colour per mode, and two are", {
  # `colour_light` says a slot CHANGES COLOUR with the mode, which is not the same thing as a colour
  # having two values -- that is TX_PALETTE's own light column. Two rows need it, and both for the
  # same reason: on white, bold is loud enough as bold and the accent blue carries the page, while
  # on a dark ground bold reads weakly and the blue chrome recedes, so both take the gold.
  alt <- vapply(txtheme:::TX_SLOTS, function(s)
    if (txtheme:::tx_empty(s$colour_light)) NA_character_ else s$colour_light, character(1))
  expect_setequal(names(alt)[!is.na(alt)], c("bold", "highlight"))
  expect_identical(txtheme:::tx_slot_colour(txtheme:::TX_SLOTS$bold, "dark"),  "gold")
  expect_identical(txtheme:::tx_slot_colour(txtheme:::TX_SLOTS$bold, "light"), "emphasis")
  expect_identical(txtheme:::tx_slot_colour(txtheme:::TX_SLOTS$highlight, "dark"),  "gold")
  expect_identical(txtheme:::tx_slot_colour(txtheme:::TX_SLOTS$highlight, "light"), "accent")
})

test_that("a colour with one value is mode-independent, and reads that way in every mode", {
  # The gold and the ten annotation hues declare `dark` only, on purpose: a darkened yellow goes
  # muddy, and the annotation palette was built to clear both grounds. tx_hex() falls back rather
  # than returning NA, which is what keeps the blockquote rule and `.resultat` on one colour.
  expect_identical(txtheme:::tx_hex("gold", "light"), txtheme:::tx_hex("gold", "dark"))
  expect_true("gold" %in% txtheme:::tx_mode_free())
  expect_false("accent" %in% txtheme:::tx_mode_free())
})
