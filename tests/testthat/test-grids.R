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

test_that("every recorded oklch is the hex's own, and every spec builds its hex", {
  for (nm in names(txtheme:::TX_PALETTE)) {
    row <- txtheme:::TX_PALETTE[[nm]]
    got <- hex_oklch(row$dark)
    rec <- as.numeric(strsplit(trimws(row$oklch), " +")[[1]])
    expect_equal(unname(got[1:2]), rec[1:2], tolerance = 5e-3, info = nm)
    expect_lt(abs(((got[3] - rec[3] + 180) %% 360) - 180), 0.5, label = nm)
    if (!txtheme:::tx_empty(row$spec)) {
      s <- strsplit(trimws(row$spec), " +")[[1]]
      built <- switch(s[1],
        oklch = oklch_hex(as.numeric(s[2]), as.numeric(s[3]), as.numeric(s[4])),
        tint  = hex_tint(txtheme:::TX_PALETTE[[s[2]]]$dark, as.numeric(s[3])))
      expect_equal(toupper(built), toupper(row$dark), info = nm)
    }
  }
})

test_that("the heading ladder is warm-95-10, floored on the ink", {
  L <- vapply(paste0("heading-", 1:6),
              function(k) unname(hex_oklch(txtheme:::TX_PALETTE[[k]]$dark)["L"]), numeric(1))
  expect_true(all(diff(L) < 0))                       # every level dimmer than the one above
  expect_equal(unname(L[6]), unname(hex_oklch(txtheme:::TX_PALETTE$ink$dark)["L"]), tolerance = 2e-3)
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
