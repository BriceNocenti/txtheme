# PURPOSE: prove that screenshot() lands on the element it was asked for, and refuses when it
#   cannot.
# ROLE: the only test here that starts a browser. Everything else in this package is arithmetic on
#   colours; this is the one place where the answer depends on what Chromium actually paints.
# KEY CONSTRAINTS:
#   - The oracle is the PIXELS, never the reported size. The failure this file guards produced a
#     sharp PNG of exactly the requested dimensions, showing the wrong part of the page: any
#     assertion on geometry alone would have passed it.
#   - The fixture is written at test time, not committed: it is 50 000 px tall and trivially
#     regenerated.
# See: dev/design.md section 10.

MAGENTA <- c(1, 0, 1)
CYAN    <- c(0, 1, 1)

skip_sans_navigateur <- function() {
  skip_on_cran()
  skip_if_not_installed("chromote")
  skip_if_not_installed("png")
  skip_if(is.null(chromote::find_chrome()), "no Chromium-based browser")
}

# A page tall enough that the element asked for is nowhere near the viewport, carrying every shape
# the real pages use to hide a block: a container that clips it away entirely, and one that clips
# it in half.
ecrire_page <- function(f) {
  bloc <- function(id, h, top) sprintf(
    "<div id='%s' style='position:absolute;top:%dpx;left:40px;width:600px;height:%dpx;background:var(--c)'></div>",
    id, top, h)
  writeLines(c(
    "<!doctype html><html><head><meta charset='utf-8'><style>",
    ":root { --c: rgb(255,0,255); }",
    "@media (prefers-color-scheme: dark) { :root { --c: rgb(0,255,255); } }",
    "body { margin: 0; background: #fff; position: relative; height: 50600px; }",
    "</style></head><body>",
    bloc("haut", 300, 0),
    bloc("cible", 400, 50000),
    # laid out at 300 px, painted over 0: the shape that used to be captured silently and wrongly
    "<div style='position:absolute;top:49000px;left:40px;width:600px;height:0;overflow:hidden'>",
    "  <div id='efface' style='width:600px;height:300px;background:var(--c)'></div></div>",
    # laid out at 300 px, painted over its top 100 only
    "<div style='position:absolute;top:49300px;left:40px;width:600px;height:100px;overflow:hidden'>",
    "  <div id='moitie' style='width:600px;height:300px;background:var(--c)'></div></div>",
    "</body></html>"), f)
  f
}

# The share of pixels of `couleur` in the file, ignoring a 2 px frame: getBoundingClientRect() is
# fractional, so the outermost row and column are half-covered and prove nothing.
part_de <- function(f, couleur = MAGENTA) {
  a <- png::readPNG(f)
  if (length(dim(a)) < 3) return(0)
  if (dim(a)[[1]] <= 4 || dim(a)[[2]] <= 4) return(0)
  a <- a[3:(dim(a)[[1]] - 2), 3:(dim(a)[[2]] - 2), 1:3, drop = FALSE]
  mean(abs(a[, , 1] - couleur[[1]]) < 0.05 &
       abs(a[, , 2] - couleur[[2]]) < 0.05 &
       abs(a[, , 3] - couleur[[3]]) < 0.05)
}

taille <- function(f) rev(dim(png::readPNG(f))[1:2])  # largeur, hauteur

test_that("un element a 50 000 px de fond est capture, et c'est bien lui", {
  skip_sans_navigateur()
  page <- ecrire_page(tempfile(fileext = ".html"))
  dir  <- tempfile(); dir.create(dir)

  f <- screenshot(page, "#cible", mode = "light", dir = dir, expand = 0)
  expect_length(f, 1L)
  expect_equal(taille(f), c(600, 400))
  expect_gt(part_de(f), 0.99)

  g <- screenshot(page, "#haut", mode = "light", dir = dir, expand = 0)
  expect_equal(taille(g), c(600, 300))
  expect_gt(part_de(g), 0.99)
})

test_that("un element qu'un ancetre rogne entierement est refuse, pas devine", {
  skip_sans_navigateur()
  page <- ecrire_page(tempfile(fileext = ".html"))
  dir  <- tempfile(); dir.create(dir)

  # THE regression. `#efface` is laid out 300 px tall and painted over none of it: the old
  # measurement handed those coordinates to the clip and got back a sharp, correctly sized picture
  # of the page behind it. Nothing but the pixels says so, which is why this file exists.
  expect_error(screenshot(page, "#efface", mode = "light", dir = dir, expand = 0),
               "nothing of them is painted(.|\n)*clips away")

  # Rogne a moitie : on capture ce qui est peint, et rien de plus. Avant, la boite valait 300 px et
  # les 200 du bas montraient ce qui se trouve derriere.
  h <- screenshot(page, "#moitie", mode = "light", dir = dir, expand = 0)
  expect_equal(taille(h), c(600, 100))
  expect_gt(part_de(h), 0.99)
})

test_that("expand, scale et le mode font ce qu'ils disent", {
  skip_sans_navigateur()
  page <- ecrire_page(tempfile(fileext = ".html"))
  dir  <- tempfile(); dir.create(dir)

  e <- screenshot(page, "#cible", mode = "light", dir = dir, expand = 8, name = "e")
  expect_equal(taille(e), c(616, 416))

  s <- screenshot(page, "#cible", mode = "light", dir = dir, expand = 0, scale = 2, name = "s")
  expect_equal(taille(s), c(1200, 800))
  expect_gt(part_de(s), 0.99)

  # Le mode est impose par prefers-color-scheme, et la page en change de couleur : une capture qui
  # atterrit au bon endroit dans le mauvais mode se voit ici, et elle seule.
  d <- screenshot(page, "#cible", mode = "dark", dir = dir, expand = 0, name = "d")
  expect_gt(part_de(d, CYAN), 0.99)
  expect_lt(part_de(d, MAGENTA), 0.01)
})
