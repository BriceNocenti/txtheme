# The format's Lua filters, run by bare pandoc on a few lines of markdown: what a page receives,
# without rendering a Quarto project.

pandoc_lua <- function(md, filter) {
  pandoc <- Sys.which("pandoc")
  skip_if(pandoc == "", "pandoc is not on the PATH")
  out <- suppressWarnings(system2(pandoc, c("-f", "markdown", "-t", "html", "--wrap=none",
                                            "--lua-filter", shQuote(filter)),
                                  input = md, stdout = TRUE, stderr = TRUE))
  paste(out, collapse = "\n")
}

test_that("liens.lua opens http(s) links in a new tab, and only them", {
  skip_without_source()
  f <- file.path(src_root(), "_extensions/txtheme/liens.lua")
  html <- pandoc_lua(c("[doc](https://example.org/a) et <http://example.org/b>",
                       "[section](#sec-x) [fichier](donnees.xlsx)",
                       "[deja](https://example.org/c){target=\"_self\"}"), f)
  expect_match(html, '<a href="https://example.org/a" target="_blank" rel="noopener">doc</a>',
               fixed = TRUE)
  # a bare autolink is a Link node too
  expect_match(html, 'href="http://example.org/b"[^>]*target="_blank"')
  # internal anchors and local files stay in the page
  expect_match(html, '<a href="#sec-x">section</a>', fixed = TRUE)
  expect_match(html, '<a href="donnees.xlsx">fichier</a>', fixed = TRUE)
  # an author's own target wins
  expect_match(html, 'href="https://example.org/c" target="_self"')
  expect_no_match(html, 'example.org/c"[^>]*_blank')
})
