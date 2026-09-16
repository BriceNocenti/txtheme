# PURPOSE: read the contrast of an element AS THE BROWSER PAINTS IT, in both modes.
# ROLE: the measuring half of screenshot(). contrast() and apca() compute on two hex strings; a page
#   never states its colours as hex -- a band is `color-mix(in oklch, …)`, a box ground is a
#   translucent grey laid over another one. This asks Chromium what it resolved, then does the
#   arithmetic here, with the package's own two functions.
# KEY CONSTRAINTS:
#   - Colours are resolved by painting them on a 1 x 1 canvas and reading the pixel back: whatever
#     CSS syntax the computed style returns (oklch(), color(srgb …), rgb()), the answer is the 8-bit
#     sRGB the screen shows.
#   - The ground is COMPOSITED: every translucent background from the root down to the element is
#     laid over the one before, on white when the root paints nothing. Text with alpha is laid over
#     that ground in turn.
#   - Only `background-color` counts. A ground drawn by an image, a gradient or an inset
#     `box-shadow` (Bootstrap's table stripes) is not seen, and neither is `opacity`.
# See: dev/design.md section 10 (the capture engine this reuses).

.TX_MEASURE_JS <- paste0(
  "(function (sel) {",
  "  var el = document.querySelector(sel);",
  "  if (!el) return null;",
  "  var cv = document.createElement('canvas'); cv.width = cv.height = 1;",
  "  var cx = cv.getContext('2d', { willReadFrequently: true });",
  "  function rgba(c) {",
  "    cx.clearRect(0, 0, 1, 1); cx.fillStyle = '#000'; cx.fillStyle = c; cx.fillRect(0, 0, 1, 1);",
  "    var d = cx.getImageData(0, 0, 1, 1).data; return [d[0], d[1], d[2], d[3] / 255];",
  "  }",
  "  function over(top, base) {",
  "    return [0, 1, 2].map(function (i) { return top[i] * top[3] + base[i] * (1 - top[3]); });",
  "  }",
  "  var chain = []; for (var n = el; n && n.nodeType === 1; n = n.parentElement) chain.unshift(n);",
  "  var ground = [255, 255, 255];",
  "  chain.forEach(function (n) {",
  "    var c = rgba(getComputedStyle(n).backgroundColor); if (c[3] > 0) ground = over(c, ground);",
  "  });",
  "  var ink = over(rgba(getComputedStyle(el).color), ground);",
  "  var hex = function (v) { return '#' + v.map(function (x) {",
  "    return ('0' + Math.round(x).toString(16)).slice(-2); }).join('').toUpperCase(); };",
  "  return JSON.stringify({ n: document.querySelectorAll(sel).length,",
  "                          text: hex(ink), background: hex(ground) });",
  "})(%s)")

#' Measure the contrast of an element as the page paints it
#'
#' Opens a rendered page in headless Chromium, once per mode, and reads the text colour and the
#' ground of the FIRST element `selector` matches, as painted: translucent backgrounds are
#' composited down the ancestor chain, and any CSS colour syntax is resolved to sRGB. Then reports
#' [contrast()] (WCAG 2.x) and [apca()] on the two.
#'
#' Only `background-color` is seen: a ground painted by an image, a gradient, an inset `box-shadow`
#' or `opacity` is not.
#'
#' @inheritParams screenshot
#' @param selector A CSS selector. Several may be given; each is measured on its first match.
#' @return A data frame, one row per selector and mode: `mode`, `selector`, `n` (the number of
#'   matches), `text` and `background` (`"#RRGGBB"`), `wcag` and `apca`. Printed as it is measured.
#' @examples
#' \dontrun{
#' measure_contrast("page.html", c(".webex-inset[data-couleur='terrain'] > .webex-title",
#'                                 ".webex-box > .exercise > p > .theorem-title"))
#' }
#' @export
measure_contrast <- function(page, selector,
                             mode    = c("light", "dark"),
                             actions = NULL,
                             width = 1280, height = 900, delay = 0.5) {
  .tx_need_chrome()
  stopifnot(is.character(page), length(page) == 1L,
            is.character(selector), length(selector) >= 1L, all(nzchar(selector)))
  mode <- match.arg(mode, several.ok = TRUE)
  if (!is.null(actions)) actions <- as.character(actions)
  url <- .tx_page_url(page)

  rows <- list()
  for (m in mode) {
    b <- chromote::ChromoteSession$new()
    tryCatch({
      .tx_open(b, url, m, width, height)
      .tx_assert_mode(b, m)
      if (length(actions)) .tx_act(b, actions)
      Sys.sleep(delay)
      for (s in selector) {
        got <- .tx_eval(b, sprintf(.TX_MEASURE_JS, .tx_js_str(s)))
        # WARNING: a selector that finds nothing must STOP, like screenshot(): a missing row would
        #   read as "nothing to worry about".
        if (is.null(got)) stop("nothing matches ", s, " on ", page, call. = FALSE)
        got <- jsonlite::fromJSON(got)
        rows[[length(rows) + 1L]] <- data.frame(
          mode = m, selector = s, n = got$n, text = got$text, background = got$background,
          wcag = round(contrast(got$text, got$background), 2),
          apca = apca(got$text, got$background), stringsAsFactors = FALSE)
      }
    }, finally = b$close())
  }
  out <- do.call(rbind, rows)
  print(out, row.names = FALSE)
  invisible(out)
}
