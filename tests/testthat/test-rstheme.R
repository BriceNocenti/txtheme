# The RStudio theme is read by a program we do not run here, so what it needs is asserted on the
# file itself: the two header lines RStudio's regex looks for, CSS it can take as it stands, classes
# it promises to keep, and a colour per R token that is the page's colour for the same word. That it
# really PAINTS those colours is formations_stat's dev/tools/verifier_rstudio.R, against a live
# RStudio.

rstheme <- function() readLines(txtheme_file("rstudio/txtheme.rstheme"), warn = FALSE)

# The cascade in one direction only: the last rule whose selector list names `sel` exactly.
rule_for <- function(css, sel) {
  hits <- Filter(function(l) sel %in% trimws(strsplit(sub("\\s*\\{.*$", "", l), ",")[[1]]), css)
  if (!length(hits)) return(NA_character_)
  sub("^.*\\{\\s*(.*?)\\s*\\}.*$", "\\1", hits[length(hits)])
}
colour_of <- function(css, sel) sub("^.*(^|; )color: (#[0-9A-Fa-f]{6});.*$", "\\2", rule_for(css, sel))

test_that("the file opens with the two headers RStudio reads, in its own regex", {
  x <- rstheme()
  # SessionThemes.cpp: rs-theme-name\s*:\s*([^\*]+?)\s*(?:\*|$) -- the first match wins
  nm <- regmatches(x[1], regexec("rs-theme-name\\s*:\\s*([^*]+?)\\s*(?:\\*|$)", x[1], perl = TRUE))[[1]][2]
  expect_identical(nm, "txtheme")
  expect_match(x[2], "^/\\* rs-theme-is-dark: TRUE \\*/$")   # absent, a dark theme is taken for light
  expect_length(grep("rs-theme-name", x), 1L)
})

test_that("it is plain CSS: no Sass, no import, no line comment, balanced braces", {
  txt <- paste(rstheme(), collapse = "\n")
  body <- gsub("/\\*.*?\\*/", "", txt)
  expect_false(grepl("@(import|use|include|mixin)", body))
  expect_false(grepl("\\$[a-z]", body))
  expect_false(grepl("(^|\\s)//", body))
  expect_equal(lengths(regmatches(body, gregexpr("\\{", body))),
               lengths(regmatches(body, gregexpr("\\}", body))))
  # one rule per line, never nested
  rules <- grep("\\{", strsplit(body, "\n")[[1]], value = TRUE)
  expect_true(all(lengths(regmatches(rules, gregexpr("\\{", rules))) == 1L))
})

test_that("the editor ground is an UNSCOPED rule, which RStudio samples for its whole UI", {
  expect_match(rule_for(rstheme(), ".ace_editor"), "background-color: #1f1f1f", fixed = TRUE)
})

test_that("every class is one RStudio promises to keep", {
  body <- gsub("/\\*.*?\\*/", "", paste(rstheme(), collapse = "\n"))
  sels <- sub("\\s*\\{.*$", "", grep("\\{", strsplit(body, "\n")[[1]], value = TRUE))
  for (s in sels) expect_silent(txtheme:::.tx_check_rstudio_selector(s, s))
  expect_error(txtheme:::.tx_check_rstudio_selector("x", ".rstudio-themes-flat .ace_line"),
               "does not promise")
})

test_that("each R token RStudio emits takes the page's colour for the same word", {
  skip_if_not_installed("jsonlite")
  css <- rstheme()
  th  <- jsonlite::fromJSON(txtheme_file("highlight/txtheme-dark.theme"))$`text-styles`
  page <- function(tok) th[[tok]]$`text-color`
  # RStudio's R mode (r_highlight_rules.js) -> the skylighting token pandoc gives the same word in R
  pairs <- list(
    c(".ace_comment",              "Comment"),   # # a comment
    c(".ace_string",               "String"),    # "row"
    c(".ace_constant.ace_numeric", "DecVal"),    # 1.5
    c(".ace_constant.ace_language","Constant"),  # TRUE, NA
    c(".ace_keyword",              "Keyword"),   # function, if
    c(".ace_keyword.ace_operator", "SpecialChar"),# |>, ::, $, ==
    c(".ace_keyword.ace_operator", "Other"),     # <-  (pandoc: Other)
    c(".ace_support.ace_function", "Function"))  # tab(
  for (p in pairs)
    expect_identical(toupper(colour_of(css, p[1])), toupper(page(p[2])), info = paste(p, collapse = " / "))
  expect_identical(toupper(colour_of(css, ".ace_identifier")), toupper(th$Normal$`text-color`))
  # the comma under function-call highlighting out-specifies the operator pink, and goes grey
  expect_identical(colour_of(css, ".ace_punctuation.ace_keyword.ace_operator"), "#939293")
})

test_that("the rainbow parentheses out-specify RStudio's own `.editor_dark .ace_paren_color_N`", {
  css <- rstheme()
  for (i in 0:6)
    expect_false(is.na(rule_for(css, sprintf("body .ace_paren.ace_paren_color_%d", i))), info = i)
})

test_that("the operator pink reaches code, and only code", {
  # Other and SpecialChar are skylighting CODE tokens: every rule painting them is scoped under
  # `pre code` (pkgdown) or lives in a .theme that Quarto scopes to `code span.*` itself. Nothing in
  # the prose or annotation sheets may name the two classes.
  scss <- readLines(txtheme_file("pkgdown/BS5/extra.scss"), warn = FALSE)
  hits <- grep("span\\.(ot|sc)\\b", scss, value = TRUE)
  expect_length(hits, 4L)                                   # two tokens, two modes
  expect_true(all(grepl("^\\s*pre code span\\.(ot|sc) \\{", hits)))
  for (f in c("pkgdown/BS5/assets/txtheme-prose.css", "pkgdown/BS5/assets/txtheme-annotations.css"))
    expect_false(any(grepl("\\.(ot|sc)\\b", readLines(txtheme_file(f), warn = FALSE))), info = f)
})
