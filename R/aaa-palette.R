# PURPOSE: the four declared grids -- every colour, every place a colour is painted, every syntax
#   token, every brand role. This is the ONLY file a colour is decided in.
# ROLE: the single source the generator reads. Everything under inst/ and _extensions/ is written
#   from here by build_theme(); nothing downstream is edited by hand.
# KEY CONSTRAINTS:
#   - FOUR grids, split by the NAMESPACE a key belongs to: a colour name is ours, a `--bs-*`
#     property is Bootstrap's, a skylighting token is pandoc's, a brand role is Quarto's. Folding
#     them would force some hexes (the accent blue is also the Function token and the brand primary;
#     the gold is bold, the blockquote rule and an annotation class) to be stated more than once,
#     which is the one thing a grid may not do.
#   - A hex appears ONCE, in TX_PALETTE. The other three carry a foreign key to it, checked at load
#     by R/zzz-checks.R.
#   - `oklch` is the coordinate READ BACK off the hex, `spec` the construction the hex came from
#     where it has one. Both are re-derived and diffed at load, so neither can record a colour it
#     does not have.
# See: dev/design.md for the palette's rationale, R/build-theme.R for what is written from it.

# === SECTION: the colours =========================================================================
# name    the key everything else refers to
# dark    the hex on a dark page -- the only mode decided so far
# light   the hex on a light page. NA everywhere today: the light half is pkgdown's and Quarto's own,
#         and the emitters already write an unprefixed rule for any row that fills this in.
# spec    how the hex is DERIVED, where it is: "oklch <L> <C> <H>", or "tint <colour> <amount>".
#         Checked at load -- a hex that no longer matches its own construction is a silent drift.
# oklch   what the hex IS: L C H, read back. Checked at load to 5e-3 / 5e-3 / 0.5 deg.
# source  where the value comes from.
# why     filled ONLY where the value departs from its source, or where the departure is the point.
TX_PALETTE <- tx_grid(tx_tribble(
  ~name,            ~dark,      ~light, ~spec,                  ~oklch,              ~source,                                           ~why,

  # --- chrome ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
  "page",           "#21252b",  NA,     NA,                     "0.263 0.013 258.4", "Atom One Dark's ground -- what the editor shows",  NA,
  "panel",          "#282c34",  NA,     NA,                     "0.293 0.016 264.3", "Atom One Dark's raised surface",                  NA,
  "ink",            "#CDCBBC",  NA,     NA,                     "0.840 0.020 100.7", "the maintainer's settings.json override",          "the theme's own #fcfcfa is a near-white, which makes the text louder than the colours it sits among",
  "emphasis",       "#fcfcfa",  NA,     NA,                     "0.991 0.003 107.2", "starless-monokai's own foreground",                "demoted from body text to emphasis by the row above",
  "border",         "#3e4451",  NA,     NA,                     "0.386 0.024 265.7", "Atom One Dark",                                   NA,
  "accent",         "#61afef",  NA,     NA,                     "0.730 0.121 245.3", "Atom One Dark's blue -- also the Function token",  "named `accent`, not `link`: Quarto silently promotes a `color.palette` entry whose NAME is a brand role (`link`, `primary`, `danger`, ...) to that role, in BOTH modes. Verified on 1.10.18 -- a palette key `link` put this blue on the light page at Lc 30. .onLoad() now refuses any such name",
  "accent-hover",   "#81bff2",  NA,     "tint accent 0.2",      "0.782 0.097 244.3", "bootstrap's own dark-mode $link-shade-percentage", NA,
  "code-page",      "#1f1f1f",  NA,     NA,                     "0.239 0.000 263.3", "VS Code's dark ground",                           "a starless theme sets no editor background, so the code block's ground is NAMED rather than inherited",
  "inline-code",    "#fc9867",  NA,     NA,                     "0.774 0.136  46.2", "starless-monokai's markup.inline.raw",             NA,

  # --- the heading ladder: warm-95-10 ---------------------------------------------------------------------------------------------------------------------------------------------
  # One hue, the body ink's own (~100), lifted and given chroma back -- so a heading is LITERALLY the text colour, brighter. h6 is FLOORED on the ink at L 0.840 and nothing
  # goes below: the search that produced this family started because a heading was DARKER than the prose it led, and the floor is what stops that returning. A rung of
  # lightness buys ~0.02 of chroma at this hue (the sRGB ceiling is 0.086 at L 0.96, 0.107 at 0.95, 0.128 at 0.94), so the top rung asks for exactly what it can hold: one
  # rung higher and the ladder's first step would have been silently clipped away.
  "heading-1",      "#FEF1A1",  NA,     "oklch 0.950 0.10 100", "0.951 0.101 100.1", "warm-95-10",                                      NA,
  "heading-2",      "#F5E9A3",  NA,     "oklch 0.928 0.09 100", "0.928 0.090  99.6", "warm-95-10",                                      NA,
  "heading-3",      "#ECE2A4",  NA,     "oklch 0.906 0.08 100", "0.906 0.080 100.1", "warm-95-10",                                      NA,
  "heading-4",      "#E5DB9D",  NA,     "oklch 0.884 0.08 100", "0.885 0.081 100.1", "warm-95-10",                                      NA,
  "heading-5",      "#DED396",  NA,     "oklch 0.862 0.08 100", "0.861 0.080  99.2", "warm-95-10",                                      NA,
  "heading-6",      "#D6CC8F",  NA,     "oklch 0.840 0.08 100", "0.839 0.080 100.0", "warm-95-10, floored on the ink",                  NA,

  # --- prose ----------------------------------------------------------------------------------------------------------------------------------------------------------------------
  "gold",           "#e6ae02",  NA,     NA,                     "0.781 0.160  85.2", "the maintainer's settings.json",                  "markdown bold should read as emphasis, not as more text; the blockquote's rule ties to it",
  "quote",          "#B7B5AC",  NA,     NA,                     "0.772 0.013  96.5", "the maintainer's settings.json",                  "a quote recedes: the ink's own hue, a step down in lightness",
  "note",           "#c6bf93",  NA,     NA,                     "0.799 0.059 100.1", "the page's own warm hue at C 0.06",               "the one annotation that keeps a fill: it must read as a few lines of light mode inside a dark one, not as a highlighter pen",
  "note-ink",       "#2C2C2C",  NA,     NA,                     "0.293 0.000 263.3", "the note's own text colour",                      NA,

  # --- the code theme's remaining colours -----------------------------------------------------------------------------------------------------------------------------------------
  # Every other token reuses a colour already above: `ink` (Normal, Variable), `accent` (Function and friends), `inline-code` (Attribute, Information).
  "comment",        "#8b8a8d",  NA,     NA,                     "0.635 0.005 301.0", "starless-monokai's #727072, lifted",              "measured on the three dark grounds a page can show, #727072 gives Lc 3.4 / 3.1 / 2.9 -- under WCAG AA everywhere, and a page is read smaller than an editor. #8b8a8d gives 4.8 / 4.5 / 4.1. It lands close to the punctuation grey, and that is fine: comments stay ITALIC, so the style carries the distinction the luminance no longer can",
  "keyword",        "#ff6188",  NA,     NA,                     "0.706 0.194   8.4", "starless-monokai",                                NA,
  "string",         "#a9dc76",  NA,     NA,                     "0.836 0.142 130.7", "starless-monokai",                                NA,
  "constant",       "#ab9df2",  NA,     NA,                     "0.741 0.122 290.7", "starless-monokai",                                NA,
  "datatype",       "#78dce8",  NA,     NA,                     "0.838 0.095 205.7", "starless-monokai",                                NA,
  "punctuation",    "#939293",  NA,     NA,                     "0.661 0.002 324.1", "starless-monokai's punctuation grey",             NA,

  # --- the pandoc-span annotation classes -----------------------------------------------------------------------------------------------------------------------------------------
  # MODE-INDEPENDENT BY CONSTRUCTION, which is why the annotations stylesheet needs no light/dark cascade at all: every one sits at medium OKLCH lightness (0.585-0.799)
  # with chroma at most 0.234, chosen to clear both #FFFFFF and a dark ground. `resultat` is the prose gold and `comment-bg` the note, so neither is a row here: one
  # colour, painted twice by TX_SLOTS.
  "enjeu",          "#d64556",  NA,     NA,                     "0.600 0.180  17.8", "the maintainer's Zettlr palette",                 NA,
  "reflexivite",    "#13c097",  NA,     NA,                     "0.720 0.140 170.0", "the maintainer's Zettlr palette",                 NA,
  "problematique",  "#01a2d6",  NA,     NA,                     "0.667 0.133 230.2", "the maintainer's Zettlr palette",                 NA,
  "structure",      "#83adbb",  NA,     NA,                     "0.722 0.050 220.4", "the maintainer's Zettlr palette",                 NA,
  "reference",      "#488bfa",  NA,     NA,                     "0.649 0.179 260.0", "the maintainer's Zettlr palette",                 NA,
  "concept",        "#b87bf5",  NA,     NA,                     "0.696 0.180 305.3", "the maintainer's Zettlr palette",                 NA,
  "terrain",        "#d8714c",  NA,     NA,                     "0.660 0.139  40.1", "the maintainer's Zettlr palette",                 NA,
  "pertinent",      "#05ae30",  NA,     NA,                     "0.653 0.204 145.0", "the maintainer's Zettlr palette",                 NA,
  "preciser",       "#ff8700",  NA,     NA,                     "0.743 0.182  56.0", "the maintainer's Zettlr palette",                 NA,
  "non",            "#e61301",  NA,     NA,                     "0.585 0.234  30.0", "the maintainer's Zettlr palette",                 NA
))


# === SECTION: where each colour is painted ========================================================
# slot      the key, unique
# colour    a foreign key into TX_PALETTE
# emit      which generator stage owns the row: chrome / heading / prose / annotation. Replaces a switch().
# ground    the colour this one is READ ON, for the contrast report build_theme() prints. NA where the slot is itself a ground, a border or a rule.
# bs_var    a bootstrap 5.3 colour-mode custom property -- how pkgdown gets the chrome. Checked at load against the 52 bootstrap emits.
# bs_rgb    its `-rgb` twin, filled only where bootstrap derives from the LITERAL channels. See the warning below.
# sass_var  the bootstrap SASS variable the same slot is set through in a Quarto theme. Not derivable from bs_var: `--bs-emphasis-color` is
#           `$body-emphasis-color`, `--bs-heading-color` is `$headings-color`. NA where bootstrap derives the value itself from another variable.
# css_var   a custom property of ours, written into :root
# selector  a CSS selector, scoped by the emitter
# prop      the CSS property a `selector` row sets
# alpha     the colour at this opacity instead of opaque; rendered rgba(r,g,b,a)
# style     the extra declarations no palette can express, appended to the rule
# why       filled only where the row is not self-evident
#
# WARNING: `bs_rgb` is not decoration and no consumer can supply it. Bootstrap derives --bs-secondary-color / --bs-tertiary-color as rgba() of the
#   LITERAL body-colour channels, and pkgdown.scss reads var(--bs-body-color-rgb) in eleven places -- setting the hex alone leaves the sidebar, the
#   footer and the mermaid chrome on bootstrap's stock cool grey, visibly but subtly wrong. Links are worse: `a { color: rgba(var(--bs-link-color-rgb),
#   var(--bs-link-opacity,1)) }` reads ONLY the twin, so the hex alone does nothing at all.
# WARNING: exactly ONE of bs_var / css_var / selector is filled per row -- R/zzz-checks.R refuses anything else.
TX_SLOTS <- tx_grid(tx_tribble(
  ~slot,              ~colour,        ~emit,        ~ground, ~bs_var,                 ~bs_rgb,                     ~sass_var,              ~css_var,          ~selector,          ~prop,               ~alpha, ~style,                                 ~why,

  # --- the chrome ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  "page-bg",          "page",         "chrome",     NA,      "--bs-body-bg",          "--bs-body-bg-rgb",          "$body-bg",             NA,                NA,                 NA,                  NA,     NA,                                     NA,
  "ink",              "ink",          "chrome",     "page",  "--bs-body-color",       "--bs-body-color-rgb",       "$body-color",          NA,                NA,                 NA,                  NA,     NA,                                     NA,
  "ink-secondary",    "ink",          "chrome",     "page",  "--bs-secondary-color",  NA,                          NA,                     NA,                NA,                 NA,                  0.75,   NA,                                     "bootstrap would compute this from its own stock grey; stated so the sidebar and footer follow the ink. Quarto needs no row of its own: it derives it from $body-color",
  "ink-tertiary",     "ink",          "chrome",     "page",  "--bs-tertiary-color",   NA,                          NA,                     NA,                NA,                 NA,                  0.5,    NA,                                     NA,
  "emphasis",         "emphasis",     "chrome",     "page",  "--bs-emphasis-color",   "--bs-emphasis-color-rgb",   "$body-emphasis-color", NA,                NA,                 NA,                  NA,     NA,                                     NA,
  "heading-fallback", "heading-1",    "chrome",     "page",  "--bs-heading-color",    NA,                          "$headings-color",      NA,                NA,                 NA,                  NA,     NA,                                     "bslib has ONE headings variable, so the ladder below cannot be one: this is only what its six rules do not reach",
  "panel-bg",         "panel",        "chrome",     NA,      "--bs-tertiary-bg",      NA,                          "$body-tertiary-bg",    NA,                NA,                 NA,                  NA,     NA,                                     NA,
  "border",           "border",       "chrome",     NA,      "--bs-border-color",     NA,                          "$border-color",        NA,                NA,                 NA,                  NA,     NA,                                     NA,
  "link",             "accent",       "chrome",     "page",  "--bs-link-color",       "--bs-link-color-rgb",       "$link-color",          NA,                NA,                 NA,                  NA,     NA,                                     NA,
  "link-hover",       "accent-hover", "chrome",     "page",  "--bs-link-hover-color", "--bs-link-hover-color-rgb", "$link-hover-color",    NA,                NA,                 NA,                  NA,     NA,                                     NA,
  "inline-code-ink",  "inline-code",  "chrome",     "page",  "--bs-code-color",       NA,                          "$code-color",          NA,                NA,                 NA,                  NA,     NA,                                     NA,

  # --- the heading ladder -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  "h1",               "heading-1",    "heading",    "page",  NA,                      NA,                          NA,                     NA,                "h1",               "color",             NA,     NA,                                     NA,
  "h2",               "heading-2",    "heading",    "page",  NA,                      NA,                          NA,                     NA,                "h2",               "color",             NA,     NA,                                     NA,
  "h3",               "heading-3",    "heading",    "page",  NA,                      NA,                          NA,                     NA,                "h3",               "color",             NA,     NA,                                     NA,
  "h4",               "heading-4",    "heading",    "page",  NA,                      NA,                          NA,                     NA,                "h4",               "color",             NA,     NA,                                     NA,
  "h5",               "heading-5",    "heading",    "page",  NA,                      NA,                          NA,                     NA,                "h5",               "color",             NA,     NA,                                     NA,
  "h6",               "heading-6",    "heading",    "page",  NA,                      NA,                          NA,                     NA,                "h6",               "color",             NA,     NA,                                     NA,

  # --- prose: what the editor theme colours in markdown, and bootstrap has no variable for --------------------------------------------------------------------------------------------------------------------------------------------
  "bold",             "gold",         "prose",      "page",  NA,                      NA,                          NA,                     NA,                "strong, b",        "color",             NA,     NA,                                     NA,
  "quote-rule",       "gold",         "prose",      NA,      NA,                      NA,                          NA,                     NA,                "blockquote",       "border-left-color", NA,     NA,                                     NA,
  "quote-text",       "quote",        "prose",      "page",  NA,                      NA,                          NA,                     NA,                "blockquote",       "color",             NA,     "font-style: italic",                   NA,
  "inline-code-pill", "inline-code",  "prose",      NA,      NA,                      NA,                          NA,                     NA,                ":not(pre) > code", "background-color",  0.2,    "padding: 3px 5px; border-radius: 5px", "the same orange as the ink on it, at a fifth: a fill on a dark page reads as a TINT OF THE PAGE, not as a colour of its own",
  "code-ground",      "code-page",    "prose",      NA,      NA,                      NA,                          NA,                     NA,                "pre",              "background-color",  NA,     NA,                                     NA,

  # --- the annotation classes: the custom properties inst/prose/annotations.scss reads -------------------------------------------------------------------------------------------------------------------------------------------------
  "an-enjeu",         "enjeu",        "annotation", "page",  NA,                      NA,                          NA,                     "--enjeu",         NA,                 NA,                  NA,     NA,                                     NA,
  "an-resultat",      "gold",         "annotation", "page",  NA,                      NA,                          NA,                     "--resultat",      NA,                 NA,                  NA,     NA,                                     "the prose gold again: a result IS the emphasis, so it is one colour painted twice, not two colours that happen to agree",
  "an-reflexivite",   "reflexivite",  "annotation", "page",  NA,                      NA,                          NA,                     "--reflexivite",   NA,                 NA,                  NA,     NA,                                     NA,
  "an-problematique", "problematique","annotation", "page",  NA,                      NA,                          NA,                     "--problematique", NA,                 NA,                  NA,     NA,                                     NA,
  "an-structure",     "structure",    "annotation", "page",  NA,                      NA,                          NA,                     "--structure",     NA,                 NA,                  NA,     NA,                                     NA,
  "an-reference",     "reference",    "annotation", "page",  NA,                      NA,                          NA,                     "--reference",     NA,                 NA,                  NA,     NA,                                     NA,
  "an-concept",       "concept",      "annotation", "page",  NA,                      NA,                          NA,                     "--concept",       NA,                 NA,                  NA,     NA,                                     NA,
  "an-terrain",       "terrain",      "annotation", "page",  NA,                      NA,                          NA,                     "--terrain",       NA,                 NA,                  NA,     NA,                                     NA,
  "an-pertinent",     "pertinent",    "annotation", "page",  NA,                      NA,                          NA,                     "--pertinent",     NA,                 NA,                  NA,     NA,                                     NA,
  "an-preciser",      "preciser",     "annotation", "page",  NA,                      NA,                          NA,                     "--preciser",      NA,                 NA,                  NA,     NA,                                     NA,
  "an-non",           "non",          "annotation", "page",  NA,                      NA,                          NA,                     "--non",           NA,                 NA,                  NA,     NA,                                     NA,
  "an-comment-bg",    "note",         "annotation", NA,      NA,                      NA,                          NA,                     "--comment-bg",    NA,                 NA,                  NA,     NA,                                     NA,
  "an-comment-text",  "note-ink",     "annotation", "note",  NA,                      NA,                          NA,                     "--comment-text",  NA,                 NA,                  NA,     NA,                                     NA
))


# === SECTION: the brand roles =====================================================================
# One row per key in a Quarto `_brand.yml` -- a fourth vocabulary, and so a fourth grid: `primary`
# belongs to the brand spec exactly as `--bs-link-color` belongs to bootstrap. Everything a brand
# file says beyond this is the palette itself, which is TX_PALETTE written out.
# key     the brand.yml colour role
# colour  a foreign key into TX_PALETTE
# why     filled where the pairing is a choice rather than a synonym
TX_BRAND <- tx_grid(tx_tribble(
  ~key,         ~colour,         ~why,
  "background", "page",          NA,
  "foreground", "ink",           NA,
  "primary",    "accent",        "the blue is the page's one accent, and webexercises reads --highlight from it",
  "secondary",  "quote",         NA,
  "success",    "pertinent",     "the semantic four come from the annotation palette, which is where this vocabulary already exists",
  "info",       "problematique", NA,
  "warning",    "preciser",      NA,
  "danger",     "non",           NA
))


# === SECTION: the syntax tokens ===================================================================
# One row per skylighting token, all 31 exactly once -- the vocabulary pkgdown's `.scss` styles and
# pandoc's `.theme` files share, one as two-letter classes, the other as names. That shared
# vocabulary is why ONE grid generates both, mechanically and without judgement.
#
# token     pandoc's name, the key in a `.theme` file's `text-styles`
# class     pkgdown's two-letter class. NA for Normal, which is `pre code` itself.
# colour    a foreign key into TX_PALETTE
# style     the extra declaration, in CSS. The `.theme` and editor writers read bold / italic / underline back out of it.
# tm_scope  the TextMate scope for the editor block. NA where the editor has no token scope for it.
# why       filled only where the mapping is a judgement rather than a translation
TX_TOKENS <- tx_grid(tx_tribble(
  ~token,           ~class, ~colour,       ~style,                       ~tm_scope,                     ~why,
  "Normal",         NA,     "ink",         NA,                           NA,                            "an editor's own foreground is a workbench colour, not a token scope, so this row reaches the .scss and the .theme but not the editor block",
  "Alert",          "al",   "keyword",     "font-weight: bold",          "invalid.illegal",             NA,
  "Annotation",     "an",   "comment",     NA,                           "comment",                     NA,
  "Attribute",      "at",   "inline-code", "font-style: italic",         "variable.parameter",          "an R ARGUMENT NAME, and the one token the two highlighters disagree on. Pandoc tags `pct =` as Attribute, so Quarto colours it for free; downlit leaves it as BARE TEXT -- only the `=` beside it is tagged -- and no CSS selector reaches a bare text node. That gap is what inst/pkgdown/BS5/assets/txtheme-at.js closes, so one colour serves both toolchains",
  "BaseN",          "bn",   "constant",    NA,                           "constant.numeric",            NA,
  "BuiltIn",        "bu",   "accent",      NA,                           "support.function",            NA,
  "Char",           "ch",   "string",      NA,                           "string.quoted.single",        NA,
  "Comment",        "co",   "comment",     "font-style: italic",         "comment",                     NA,
  "CommentVar",     "cv",   "comment",     NA,                           "comment",                     NA,
  "Constant",       "cn",   "constant",    NA,                           "constant.language",           NA,
  "ControlFlow",    "cf",   "keyword",     NA,                           "keyword.control",             NA,
  "DataType",       "dt",   "datatype",    "font-style: italic",         "entity.name.type",            NA,
  "DecVal",         "dv",   "constant",    NA,                           "constant.numeric",            NA,
  "Documentation",  "do",   "comment",     NA,                           "comment.block.documentation", NA,
  "Error",          "er",   "keyword",     "text-decoration: underline", "invalid",                     NA,
  "Extension",      "ex",   "accent",      NA,                           "support.function",            NA,
  "Float",          "fl",   "constant",    NA,                           "constant.numeric",            NA,
  "Function",       "fu",   "accent",      NA,                           "entity.name.function",        NA,
  "Import",         "im",   "keyword",     NA,                           "keyword.control.import",      NA,
  "Information",    "in",   "inline-code", NA,                           "constant.other.placeholder",  NA,
  "Keyword",        "kw",   "keyword",     NA,                           "keyword",                     NA,
  "Operator",       "op",   "punctuation", NA,                           "punctuation",                 "downlit tags `(`, `,`, `$` AND `<-` all as `.op` -- 317 of them on one vignette page, the commonest class by far. In the editor the brackets are punctuation grey and only `<-` is pink; pink for all of them makes every bracket shout, so `.op` takes the grey and pink is left to keywords. The one place the port is DELIBERATELY not the editor",
  "Other",          "ot",   "accent",      NA,                           "support.other",               NA,
  "Preprocessor",   "pp",   "keyword",     NA,                           "meta.preprocessor",           NA,
  "RegionMarker",   "re",   "comment",     NA,                           "comment",                     NA,
  "SpecialChar",    "sc",   "constant",    NA,                           "constant.character.escape",   NA,
  "SpecialString",  "ss",   "string",      NA,                           "string.regexp",               NA,
  "String",         "st",   "string",      NA,                           "string",                      NA,
  "Variable",       "va",   "ink",         NA,                           "variable",                    NA,
  "VerbatimString", "vs",   "string",      NA,                           "string.quoted.other",         NA,
  "Warning",        "wa",   "keyword",     NA,                           "invalid.deprecated",          NA
))


# === SECTION: what bootstrap 5.3 actually offers ==================================================
# The 52 custom properties bootstrap emits inside `[data-bs-theme="dark"]`, captured from the
# compiled bootstrap 5.3.8 that bslib 0.11.0 ships. A `bs_var` outside this list is a typo that would
# fail SILENTLY -- nothing errors, the colour simply never arrives -- so .onLoad() refuses it.
# WARNING: re-capture this WITH ITS VERSION when bslib moves, and never edit it by hand: the capture
#   is the whole point.
# The colour ROLES Quarto's brand spec knows. A `color.palette` entry whose NAME is one of these is
# silently promoted to that role, in BOTH modes -- verified on Quarto 1.10.18, where a palette key
# `link` put the dark accent blue on the light page. .onLoad() refuses such a name outright, since
# nothing about the failure is visible: the render succeeds and the wrong colour just appears.
BRAND_ROLES <- c("foreground", "background", "primary", "secondary", "tertiary",
                 "success", "info", "warning", "danger", "light", "dark", "link", "black", "white")

BS_VERSION <- "5.3.8"
BS_DARK_VARS <- c(
  "--bs-body-color", "--bs-body-color-rgb", "--bs-body-bg", "--bs-body-bg-rgb",
  "--bs-emphasis-color", "--bs-emphasis-color-rgb",
  "--bs-secondary-color", "--bs-secondary-color-rgb", "--bs-secondary-bg", "--bs-secondary-bg-rgb",
  "--bs-tertiary-color", "--bs-tertiary-color-rgb", "--bs-tertiary-bg", "--bs-tertiary-bg-rgb",
  "--bs-primary-text-emphasis", "--bs-secondary-text-emphasis", "--bs-success-text-emphasis",
  "--bs-info-text-emphasis", "--bs-warning-text-emphasis", "--bs-danger-text-emphasis",
  "--bs-light-text-emphasis", "--bs-dark-text-emphasis",
  "--bs-primary-bg-subtle", "--bs-secondary-bg-subtle", "--bs-success-bg-subtle",
  "--bs-info-bg-subtle", "--bs-warning-bg-subtle", "--bs-danger-bg-subtle",
  "--bs-light-bg-subtle", "--bs-dark-bg-subtle",
  "--bs-primary-border-subtle", "--bs-secondary-border-subtle", "--bs-success-border-subtle",
  "--bs-info-border-subtle", "--bs-warning-border-subtle", "--bs-danger-border-subtle",
  "--bs-light-border-subtle", "--bs-dark-border-subtle",
  "--bs-heading-color",
  "--bs-link-color", "--bs-link-hover-color", "--bs-link-color-rgb", "--bs-link-hover-color-rgb",
  "--bs-code-color", "--bs-highlight-color", "--bs-highlight-bg",
  "--bs-border-color", "--bs-border-color-translucent",
  "--bs-form-valid-color", "--bs-form-valid-border-color",
  "--bs-form-invalid-color", "--bs-form-invalid-border-color")
