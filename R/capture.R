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
#   - What is measured is where the element is PAINTED, not where it is laid out. The two part
#     company under any ancestor that clips, and the gap is a sharp picture of the wrong thing.
#   - Every failure STOPS. A selector that matches nothing, an element an ancestor clips away, a
#     page that stayed in the other mode: each one would otherwise produce a plausible picture of
#     the wrong thing, and nothing would say so.
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
  # DESIGN: the scrollbar goes before the page is laid out, not before the shot. Chromium hides it
  #   itself at capture time; doing it here too means the page is measured in exactly the state it
  #   is captured in, and nothing can drift between the two.
  b$Emulation$setScrollbarsHidden(hidden = TRUE)
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

# The union of the VISIBLE boxes of everything the selector matches, in DOCUMENT coordinates, how
# many nodes that was, and how many of them an ancestor clips away entirely.
# WARNING: a border box is where an element is LAID OUT, not where it is PAINTED, and the two part
#   company as soon as an ancestor clips. A closed webexercises solution is `height: 68px;
#   overflow-y: hidden`: the table inside still lays out at its full height and reports a box 300 px
#   further down, where the page paints something else entirely. Clipping the box against every
#   ancestor that clips is what makes the shot land on the element -- and what lets an element that
#   is wholly clipped away be refused instead of returning a sharp picture of its neighbours.
#   Element.checkVisibility() does NOT answer this: it ignores ancestor overflow and returns true.
# WARNING: the outer bound is the document's own scroll size, NOT the box of `html`. On a Quarto
#   page `html` is only as tall as the viewport, so clamping to it turns any element below the fold
#   into a clip of negative height -- on which Chromium never answers at all. That is the bug in
#   chromote's own $screenshot(selector=), and the reason this file does the arithmetic itself.
.tx_box <- function(b, selector, expand) {
  js <- paste0(
    "(function () {",
    "  var els = document.querySelectorAll(", .tx_js_str(selector), ");",
    "  if (!els.length) return null;",
    # The rect an element is actually painted in: its border box, cut down by the padding box of
    # every ancestor whose overflow is anything but `visible`. `clip`/`clip-path` are not followed:
    # they hide paint without moving layout, and nothing in these pages uses them to hide a block.
    "  function visible(el) {",
    "    var r = el.getBoundingClientRect();",
    "    var t = r.top, b = r.bottom, l = r.left, g = r.right;",
    "    for (var p = el.parentElement; p; p = p.parentElement) {",
    "      var s = getComputedStyle(p);",
    "      if (s.overflowX === \"visible\" && s.overflowY === \"visible\") continue;",
    "      var q = p.getBoundingClientRect();",
    "      if (s.overflowY !== \"visible\") { t = Math.max(t, q.top); b = Math.min(b, q.bottom); }",
    "      if (s.overflowX !== \"visible\") { l = Math.max(l, q.left); g = Math.min(g, q.right); }",
    "    }",
    "    return { l: l, t: t, w: g - l, h: b - t };",
    "  }",
    "  var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity, clipped = 0;",
    "  var laid = 0, seen = 0;",
    "  for (var i = 0; i < els.length; i++) {",
    "    var r = els[i].getBoundingClientRect(); laid += r.width * r.height;",
    "    var v = visible(els[i]);",
    "    if (v.w <= 0 || v.h <= 0) { clipped++; continue; }",
    "    seen += v.w * v.h;",
    "    x0 = Math.min(x0, v.l); y0 = Math.min(y0, v.t);",
    "    x1 = Math.max(x1, v.l + v.w); y1 = Math.max(y1, v.t + v.h);",
    "  }",
    "  if (!isFinite(x0)) return { n: els.length, clipped: clipped, w: 0, h: 0 };",
    "  var d = document.documentElement, e = ", format(expand), ";",
    "  var X0 = Math.max(0, x0 + window.scrollX - e),",
    "      Y0 = Math.max(0, y0 + window.scrollY - e),",
    "      X1 = Math.min(d.scrollWidth,  x1 + window.scrollX + e),",
    "      Y1 = Math.min(d.scrollHeight, y1 + window.scrollY + e);",
    "  return { n: els.length, clipped: clipped, shown: laid > 0 ? seen / laid : 1,",
    "           x: X0, y: Y0, w: X1 - X0, h: Y1 - Y0 };",
    "})()")
  .tx_eval(b, js)
}

# WARNING: the clip is in DOCUMENT coordinates, and scrolling cannot move it. Blink adds the
#   current scroll offset straight back in DevToolsEmulator::ForceViewport(), so a scrollIntoView
#   before the shot cancels itself out exactly. Puppeteer and Playwright both send document
#   coordinates for the same reason; there is nothing here to be clever about.
# WARNING: a very large shot is refused by the browser, not by a constant we could check first. The
#   limit is on total pixels, not on either side: 799 x 47478 and 1598 x 94956 both succeed, while
#   3196 x 189912 fails. So the refusal is caught and translated rather than predicted.
.tx_shot <- function(b, box, scale, file) {
  ratio <- .tx_eval(b, "window.devicePixelRatio")
  # captureBeyondViewport is what lets the clip sit below the fold, and be taller than the window.
  img <- tryCatch(
    b$Page$captureScreenshot(
      format = "png", fromSurface = TRUE, captureBeyondViewport = TRUE, timeout_ = 60,
      clip = list(x = box$x, y = box$y, width = box$w, height = box$h, scale = scale / ratio)),
    error = function(e)
      stop(sprintf(paste("the browser refused a shot of %d x %d px at scale %s.",
                         "\n  Narrow the selector, or lower `scale`."),
                   as.integer(round(box$w * scale)), as.integer(round(box$h * scale)),
                   format(scale)),
           call. = FALSE))
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
#' of what one wants to see -- cut down by every ancestor that clips it. An element a closed
#' solution or a collapsed panel hides is therefore refused rather than captured: it is laid out
#' where it says, and painted nowhere. Open it first with an `actions` click.
#'
#' @param page Path to a rendered `.html`, or a `file://` / `http://` URL.
#' @param selector A CSS selector. Several matches are allowed: the shot is the bounding box of the
#'   ones that are painted, and the count is announced. No match, or nothing painted, is an error.
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
        stop(selector, " matches ", box$n, " node(s), and nothing of them is painted on ", page,
             if (box$clipped > 0)
               paste0("\n  ", box$clipped, " of them an ancestor clips away -- a closed solution,",
                      " a collapsed panel. Open it first, e.g.",
                      "\n  actions = \"click:div.webex-solution > button\"")
             else "\n  -- hidden, or not laid out.",
             call. = FALSE)

      f <- file.path(dir, paste0(name, "__", m, ".png"))
      .tx_shot(b, box, scale, f)

      wh   <- .tx_png_size(f)
      read <- .tx_read_as(wh[[1]], wh[[2]])
      note <- character(0)
      if (box$n - box$clipped > 1)
        note <- c(note, sprintf("%d nodes, bounding box", box$n - box$clipped))
      if (box$clipped > 0)
        note <- c(note, sprintf("%d of %d clipped away by an ancestor, and left out",
                                box$clipped, box$n))
      # An element a scrollbox or a closed solution mostly hides is captured over the sliver it does
      # paint. That is the honest answer, and useless in silence: the share says so.
      else if (box$shown < 0.9)
        note <- c(note, sprintf("an ancestor clips all but %d %% of it away",
                                as.integer(round(100 * box$shown))))
      if (!is.na(read$k) && read$k < 0.5)
        note <- c(note, sprintf("shrunk to %d %% before reading: narrow the selector",
                                as.integer(round(100 * read$k))))
      else if (!is.na(read$tokens) && read$tokens > 1500)
        note <- c(note, "large: narrow the selector, or keep scale = 1")
      message(f)
      message(sprintf("  %d x %d px%s  ~%s tokens%s",
                      wh[[1]], wh[[2]],
                      if (!is.na(read$k) && read$k < 1)
                        sprintf(" -> %d x %d read", read$w, read$h) else "",
                      format(read$tokens),
                      if (length(note)) paste0("  -- ", paste(note, collapse = " ; ")) else ""))
      out <- c(out, f)
    }, finally = b$close())
  }
  invisible(out)
}
