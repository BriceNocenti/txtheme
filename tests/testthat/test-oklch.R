# The colour maths. It is base R and exported, so tabxplor's dev previews call it too: a change here
# moves both the site theme and the table-palette tooling.

test_that("APCA matches Myndex's own reference vector", {
  expect_equal(apca("#888888", "#ffffff"), 63.1)
  expect_lt(apca("#CDCBBC", "#21252b"), 0)          # light text on dark reads negative
})

test_that("a hex round-trips through OKLCH", {
  for (h in c("#CDCBBC", "#21252b", "#FEF1A1", "#ff6188", "#000000", "#ffffff")) {
    o <- hex_oklch(h)
    expect_equal(toupper(oklch_hex(o[1], o[2], o[3])), toupper(h), info = h)
  }
})

test_that("out of gamut loses chroma, never lightness or hue", {
  expect_false(in_gamut(0.95, 0.30, 100))
  got <- hex_oklch(oklch_hex(0.95, 0.30, 100))
  expect_equal(unname(got["L"]), 0.95, tolerance = 3e-3)
  expect_equal(unname(got["H"]), 100,  tolerance = 0.5)
  expect_lt(got["C"], 0.30)
})

test_that("max_chroma agrees with the solve() path it is a shortcut for", {
  g <- expand.grid(L = seq(0.05, 0.98, length.out = 12), H = seq(0, 350, by = 30))
  slow <- function(L, H) { lo <- 0; hi <- 0.4
    for (i in 1:30) { m <- (lo + hi) / 2; if (in_gamut(L, m, H)) lo <- m else hi <- m }; lo }
  expect_lt(max(abs(mapply(function(L, H) max_chroma(L, H) - slow(L, H), g$L, g$H))), 1 / 255)
})

test_that("a ramp records only chroma it has", {
  r <- oklch_ramp(seq(0.95, 0.84, length.out = 6), 0.8, 100)
  expect_length(r, 6L)
  expect_true(all(attr(r, "C") <= attr(r, "cmax") + 1e-6))
  expect_equal(attr(r, "C"), vapply(r, function(h) unname(hex_oklch(h)["C"]), numeric(1)),
               tolerance = 1e-9, ignore_attr = TRUE)
})

test_that("hex_tint reproduces bootstrap's own dark link hover", {
  expect_equal(hex_tint("#6ea8fe", 0.2), "#8bb9fe")
})

test_that("hex_rgb is the -rgb twin's own form", {
  expect_equal(hex_rgb("#CDCBBC"), "205,203,188")
})
