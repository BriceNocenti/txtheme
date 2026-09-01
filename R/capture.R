# PURPOSE: see ONE element of a rendered page, in both modes, at the size a browser actually paints
#   it.
# ROLE: the review half of the theme. R/oklch.R says what a colour should be; this shows what a
#   browser did with it, so a judgement about a switch, a verdict colour or a table's width is made
#   on the page rather than on a stylesheet. Serves the three consumers alike -- a Quarto document,
#   a pkgdown site, a plain html file.
# KEY CONSTRAINTS:
#   - Base R, plus chromote and jsonlite as Suggests -- jsonlite only to decode the PNG chromote
#     hands back, and chromote imports it anyway. This package must still install in seconds with
#     nothing but R (see R/aaa-grid.R); nothing here runs unless screenshot() is called.
#   - The mode is IMPOSED and then VERIFIED. A capture of the wrong mode is worse than no capture:
#     it looks right.
#   - Every failure STOPS. A selector that matches nothing, an element with no surface, a page that
#     stayed in the other mode: each one would otherwise produce a plausible picture of the wrong
#     thing, and nothing would say so.
# See: dev/design.md section 10.

# === SECTION: small helpers =======================================================================

.tx_need_chrome <- function() {
  if (!requireNamespace("chromote", quietly = TRUE))
    stop("screenshot() needs the 'chromote' package.\n  install.packages(\"chromote\")",
         call. = FALSE)
  if (is.null(chromote::find_chrome()))
    stop("no Chromium-based browser found.\n  On Debian/Ubuntu: sudo apt install chromium",
         call. = FALSE)
  invisible(TRUE)
}

.tx_page_url <- function(page) {
  if (grepl("^(https?|file)://", page)) return(page)
  p <- normalizePath(page, mustWork = FALSE)
  if (!file.exists(p)) stop("no such page: ", page, call. = FALSE)
  paste0("file://", p)
}

# A double-quoted JS string literal. fixed = TRUE twice, in this order: no regex, no ambiguity.
.tx_js_str <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  paste0("\"", x, "\"")
}

.tx_eval <- function(b, expr, await = FALSE) {
  r <- b$Runtime$evaluate(expr, awaitPromise = await, returnByValue = TRUE, timeout_ = 30)
  if (!is.null(r$exceptionDetails))
    stop("the page refused a script: ", r$exceptionDetails$text, call. = FALSE)
  r$result$value
}

.tx_slug <- function(x, max = 48L) {
  x <- gsub("[^A-Za-z0-9]+", "-", x)
  x <- gsub("(^-+)|(-+$)", "", x)
  if (!nzchar(x)) x <- "element"
  if (nchar(x) > max) x <- substr(x, 1L, max)
  x
}

# Width and height straight out of the PNG's IHDR, which is always the first chunk: bytes 17-24,
# two big-endian int32. Reading them back off the FILE rather than trusting the requested clip is
# what makes the announced cost the real one.
.tx_png_size <- function(f) {
  con <- file(f, "rb"); on.exit(close(con))
  h <- readBin(con, "raw", n = 24L)
  if (length(h) < 24L) return(c(NA_integer_, NA_integer_))
  be <- function(r) sum(as.integer(r) * c(16777216, 65536, 256, 1))
  c(be(h[17:20]), be(h[21:24]))
}

# What the image will look like, and cost, once read: it is first shrunk so that its longest side
# is at most 1568 px, then charged at roughly one token per 750 pixels.
# WARNING: the cost alone is misleading, and that is why the READ size is reported beside it. A
#   selector matching 31 tables gives their bounding box -- 1079 x 30033 px -- which shrinks to a
#   56 px-wide strip and is charged 118 tokens. Cheap, and unreadable: only the read size says so.
.tx_read_as <- function(w, h) {
  if (anyNA(c(w, h))) return(list(w = NA, h = NA, k = 1, tokens = NA_integer_))
  k <- min(1, 1568 / max(w, h))
  list(w = round(w * k), h = round(h * k), k = k,
       tokens = as.integer(round(w * k * h * k / 750)))
}

# === SECTION: the page, opened and driven =========================================================

# DESIGN: the mode is imposed through `prefers-color-scheme`, not through the stored key. That is
#   the branch txtheme-scheme.html falls back to when nothing is stored, and it is the only one that
#   works on a file:// page in every browser. The stored key is wiped before each load so that a
#   toggle fired in one session cannot decide the mode of the next.
# WARNING: go_to() waits for the LOAD event, and that is not a nicety. A Quarto page finishes
#   building itself there: the light/dark switch, and everything a filter's javascript adds, do not
#   exist before it.
.tx_open <- function(b, url, mode, width, height) {
  b$Emulation$setEmulatedMedia(
    features = list(list(name = "prefers-color-scheme", value = mode)))
  b$Page$addScriptToEvaluateOnNewDocument(
    source = "try { localStorage.removeItem(\"txtheme.scheme\"); } catch (e) {}")
  b$set_viewport_size(width = width, height = height)
  b$go_to(url, timeout_ = 60)
  .tx_eval(b, "document.fonts.ready.then(function(){ return true; })", await = TRUE)
  invisible(TRUE)
}

# Which convention this page uses to say what mode it is in, and what it says. "" means the page
# has no such hook: its stylesheet answers prefers-color-scheme directly, and the emulation above
# is the whole story.
.TX_MODE_JS <- paste0(
  "(function () {",
  "  var c = document.body ? document.body.classList : null;",
  "  if (c && (c.contains(\"quarto-dark\") || c.contains(\"quarto-light\")))",
  "    return c.contains(\"quarto-dark\") ? \"dark\" : \"light\";",
  "  var t = document.documentElement.getAttribute(\"data-bs-theme\");",
  "  if (t === \"dark\" || t === \"light\") return t;",
  "  return \"\";",
  "})()")

.tx_assert_mode <- function(b, mode) {
  seen <- .tx_eval(b, .TX_MODE_JS)
  if (!nzchar(seen) || identical(seen, mode)) return(invisible(TRUE))
  # Quarto's own switch is public, and txtheme wraps rather than replaces it. Ask it once.
  if (isTRUE(.tx_eval(b, "typeof window.quartoToggleColorScheme === \"function\""))) {
    .tx_eval(b, "window.quartoToggleColorScheme()")
    Sys.sleep(0.2)
    seen <- .tx_eval(b, .TX_MODE_JS)
  }
  if (!identical(seen, mode))
    stop("the page stayed in ", seen, " mode when ", mode, " was asked for.", call. = FALSE)
  invisible(TRUE)
}

# WARNING: a click or a fill that finds nothing must STOP. A no-op here produces a perfectly
#   plausible screenshot of a page where nothing happened, and nothing says so.
.tx_act <- function(b, actions) {
  for (a in actions) {
    if (!grepl(":", a, fixed = TRUE))
      stop("an action reads verb:argument -- got: ", a, call. = FALSE)
    verb <- sub(":.*$", "", a)
    arg  <- sub("^[^:]*:", "", a)
    if (verb == "wait") {
      Sys.sleep(as.numeric(arg) / 1000)
    } else if (verb == "js") {
      .tx_eval(b, arg)
    } else if (verb == "click") {
      ok <- .tx_eval(b, paste0(
        "(function(){ var e = document.querySelector(", .tx_js_str(arg), ");",
        " if (!e) return false; e.click(); return true; })()"))
      if (!isTRUE(ok)) stop("click: nothing matches ", arg, call. = FALSE)
    } else if (verb == "fill") {
      if (!grepl("=", arg, fixed = TRUE))
        stop("a fill reads fill:selector=value -- got: ", a, call. = FALSE)
      sel <- sub("=.*$", "", arg)
      val <- sub("^[^=]*=", "", arg)
      # `change` is what webexercises binds on all four widget kinds, and what a <select> answers
      # to. Setting .value alone leaves every listener asleep.
      ok <- .tx_eval(b, paste0(
        "(function(){ var e = document.querySelector(", .tx_js_str(sel), ");",
        " if (!e) return false; e.value = ", .tx_js_str(val), ";",
        " e.dispatchEvent(new Event(\"change\", { bubbles: true })); return true; })()"))
      if (!isTRUE(ok)) stop("fill: nothing matches ", sel, call. = FALSE)
    } else {
      stop("unknown action verb '", verb, "' -- one of click, fill, wait, js", call. = FALSE)
    }
  }
  invisible(TRUE)
}

# === SECTION: the shot ============================================================================

# The union of the border boxes of everything the selector matches, in DOCUMENT coordinates, and
# how many nodes that was.
# WARNING: the bound is the document's own scroll size, NOT the box of `html`. On a Quarto page
#   `html` is only as tall as the viewport, so clamping to it turns any element below the fold into
#   a clip of negative height -- on which Chromium never answers at all. That is the bug in
#   chromote's own $screenshot(selector=), and the reason this file does the arithmetic itself.
.tx_box <- function(b, selector, expand) {
  js <- paste0(
    "(function () {",
    "  var els = document.querySelectorAll(", .tx_js_str(selector), ");",
    "  if (!els.length) return null;",
    "  var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;",
    "  for (var i = 0; i < els.length; i++) {",
    "    var r = els[i].getBoundingClientRect();",
    "    if (r.width === 0 && r.height === 0) continue;",
    "    x0 = Math.min(x0, r.left); y0 = Math.min(y0, r.top);",
    "    x1 = Math.max(x1, r.right); y1 = Math.max(y1, r.bottom);",
    "  }",
    "  if (!isFinite(x0)) return { n: els.length, w: 0, h: 0 };",
    "  var d = document.documentElement, e = ", format(expand), ";",
    "  var X0 = Math.max(0, x0 + window.scrollX - e),",
    "      Y0 = Math.max(0, y0 + window.scrollY - e),",
    "      X1 = Math.min(d.scrollWidth,  x1 + window.scrollX + e),",
    "      Y1 = Math.min(d.scrollHeight, y1 + window.scrollY + e);",
    "  return { n: els.length, x: X0, y: Y0, w: X1 - X0, h: Y1 - Y0 };",
    "})()")
  .tx_eval(b, js)
}

.tx_shot <- function(b, box, scale, file) {
  ratio <- .tx_eval(b, "window.devicePixelRatio")
  b$Emulation$setScrollbarsHidden(hidden = TRUE)
  on.exit(b$Emulation$setScrollbarsHidden(hidden = FALSE), add = TRUE)
  # captureBeyondViewport is what lets the clip sit below the fold, and be taller than the window.
  img <- b$Page$captureScreenshot(
    format = "png", fromSurface = TRUE, captureBeyondViewport = TRUE, timeout_ = 60,
    clip = list(x = box$x, y = box$y, width = box$w, height = box$h, scale = scale / ratio))
  writeBin(jsonlite::base64_dec(img$data), file)
  invisible(file)
}

# === SECTION: the exported call ===================================================================

#' A screenshot of one element, in both modes
#'
#' Loads a rendered page in a headless Chromium and writes a PNG of the element `selector` names --
#' the browser's "screenshot node", not a screenshot of the window. One file per mode, each one
#' announced with its pixel size and with what it costs a model to read.
#'
#' The mode is imposed through `prefers-color-scheme` and then verified against whatever hook the
#' page uses to record it (`body.quarto-dark` for a Quarto page, `data-bs-theme` for a Bootstrap or
#' pkgdown one). A page that ends up in the other mode stops the call rather than returning a
#' plausible-looking picture of the wrong thing.
#'
#' The page is driven only after its `load` event, because that is when a Quarto page finishes
#' building itself: the light/dark switch, and anything a filter's javascript adds, do not exist
#' before it.
#'
#' What is captured is the element's border box, padded by `expand` -- an exercise's frame is part
#' of what one wants to see.
#'
#' @param page Path to a rendered `.html`, or a `file://` / `http://` URL.
#' @param selector A CSS selector. Several matches are allowed: the shot is their bounding box, and
#'   the count is announced. No match is an error.
#' @param mode `"light"`, `"dark"`, or both (the default) -- one file each.
#' @param actions Character vector, played in order after `load` and before the shot, and replayed
#'   identically in each mode. Four verbs: `"click:<css>"`, `"fill:<css>=<value>"`,
#'   `"wait:<ms>"`, `"js:<expression>"`. A `click` or a `fill` that matches nothing is an error.
#' @param width,height The viewport, in CSS pixels. Layout depends on it; `width = 390` is a phone.
#'   The element may be taller than the window: it is captured whole either way.
#' @param scale Device pixel ratio of the output. `1` by default, which is legible for prose and
#'   layout and costs a quarter of what `2` does. Raise it to `2` to judge a colour or a hairline --
#'   a border, a focus ring; above that nothing is gained, since a content-column element then
#'   passes the 1568 px at which an image is shrunk again before being read.
#' @param expand Padding around the element, in pixels, so a border or a shadow is not clipped.
#' @param dir Where the files go. Defaults to this package's user cache directory.
#' @param name Base name for the files, without extension or mode. Derived from the page and the
#'   selector when left `NULL`, so a second call to the same element overwrites the first.
#' @param delay Seconds to wait after `load`, and again after the actions, before measuring.
#' @return The written paths, invisibly.
#' @examples
#' \dontrun{
#' screenshot("dev/preview_theme.html", "#un-tableau-tabxplor")
#' screenshot("_site/cours/M1S1/M1S1_02.html", "table.tabxplor-tab", mode = "dark", scale = 2)
#' screenshot("dev/exercices_types.html", "div.webex-box:has(> div#exr-m1-lecture)",
#'            actions = c("fill:input.webex-solveme=42", "click:button.webex-check-button"))
#' }
#' @export
screenshot <- function(page, selector,
                       mode    = c("light", "dark"),
                       actions = NULL,
                       width = 1280, height = 900,
                       scale = 1, expand = 8,
                       dir = NULL, name = NULL, delay = 0.5) {
  .tx_need_chrome()
  stopifnot(is.character(page), length(page) == 1L,
            is.character(selector), length(selector) == 1L, nzchar(selector),
            is.numeric(scale), scale > 0, is.numeric(expand), expand >= 0)
  mode <- match.arg(mode, several.ok = TRUE)
  if (!is.null(actions)) actions <- as.character(actions)

  url <- .tx_page_url(page)
  if (is.null(dir)) dir <- tools::R_user_dir("txtheme", "cache")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  if (is.null(name))
    name <- paste0(.tx_slug(tools::file_path_sans_ext(basename(sub("[?#].*$", "", page)))),
                   "__", .tx_slug(selector))

  out <- character(0)
  for (m in mode) {
    b <- chromote::ChromoteSession$new()
    tryCatch({
      .tx_open(b, url, m, width, height)
      .tx_assert_mode(b, m)
      if (length(actions)) .tx_act(b, actions)
      Sys.sleep(delay)

      box <- .tx_box(b, selector, expand)
      if (is.null(box))
        stop("nothing matches ", selector, " on ", page, call. = FALSE)
      if (box$w <= 0 || box$h <= 0)
        stop(selector, " matches ", box$n, " node(s) with no surface on ", page,
             " -- hidden, or not laid out.", call. = FALSE)

      f <- file.path(dir, paste0(name, "__", m, ".png"))
      .tx_shot(b, box, scale, f)

      wh   <- .tx_png_size(f)
      read <- .tx_read_as(wh[[1]], wh[[2]])
      note <- character(0)
      if (box$n > 1) note <- c(note, sprintf("%d nodes, bounding box", box$n))
      if (!is.na(read$k) && read$k < 0.5)
        note <- c(note, sprintf("shrunk to %d %% before reading: narrow the selector",
                                as.integer(round(100 * read$k))))
      else if (!is.na(read$tokens) && read$tokens > 1500)
        note <- c(note, "large: narrow the selector, or keep scale = 1")
      message(f)
      message(sprintf("  %d x %d px%s  ~%s tokens%s",
                      wh[[1]], wh[[2]],
                      if (read$k < 1) sprintf(" -> %d x %d read", read$w, read$h) else "",
                      format(read$tokens),
                      if (length(note)) paste0("  -- ", paste(note, collapse = " ; ")) else ""))
      out <- c(out, f)
    }, finally = b$close())
  }
  invisible(out)
}
