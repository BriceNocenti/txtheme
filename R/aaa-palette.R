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

# The modes a colour can declare, in the order a consumer meets them: `dark` is the half the palette
# was designed in, `light` the half derived from it. Everything downstream takes one of these as an
# ARGUMENT -- tx_hex(), every emitter, the contrast report, the per-mode check.
TX_MODES <- c("dark", "light")

# === SECTION: the colours =========================================================================
# name          the key everything else refers to
# dark          the hex on a dark page
# dark_spec     how that hex is DERIVED, where it is: "oklch <L> <C> <H>", or "tint <colour> <amount>".
#               Checked at load -- a hex that no longer matches its own construction is a silent drift.
# dark_oklch    what that hex IS: L C H, read back. Checked at load to 5e-3 / 5e-3 / 0.5 deg.
# light         the hex on a light page, and the same two columns after it. NA where the colour is
#               MODE-INDEPENDENT: the ten annotation hues and the note are one value in both modes by
#               construction (see the annotation block below), so a light cell there would be a
#               second name for the same colour.
# source        where the value comes from.
# why           filled ONLY where the value departs from its source, or where the departure is the point.
#
# The two halves are symmetric on purpose: a mode is an ARGUMENT everywhere downstream (tx_hex(),
# every emitter, the contrast report), never a second writer. Adding a third mode would be a third
# triple here and nothing else.
TX_PALETTE <- tx_grid(tx_tribble(
  ~name          , ~dark    , ~dark_spec            , ~dark_oklch        , ~light   , ~light_spec              , ~light_oklch       , ~source                                                                                 , ~why,

  # --- chrome ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
  "page"         , "#21252b", NA                    , "0.263 0.013 258.4", "#FFFFFF", NA                       , "1.000 0.000 263.3", "Atom One Dark's ground -- what the editor shows"                                       , NA,
  "panel"        , "#282c34", NA                    , "0.293 0.016 264.3", "#F8F8F5", "oklch 0.978 0.004 100"  , "0.978 0.004 107.0", "Atom One Dark's raised surface"                                                        , NA,
  "ink"          , "#CDCBBC", NA                    , "0.840 0.020 100.7", "#34332C", "oklch 0.320 0.012 100"  , "0.320 0.012 100.4", "the maintainer's settings.json override"                                               , "the theme's own #fcfcfa is a near-white, which makes the text louder than the colours it sits among",
  "emphasis"     , "#fcfcfa", NA                    , "0.991 0.003 107.2", "#000000", NA                       , "0.000 0.000   0.0", "starless-monokai's own foreground; bootstrap's own --bs-emphasis-color on a light page", "demoted from body text to emphasis by the row above. Black on the light side is a DECISION, not a mirror: bold is loud enough on white without a hue, so the light half spends nothing on it (see the `bold` slot); on a dark page bold reads weakly, which is why the gold is added there",
  "border"       , "#3e4451", NA                    , "0.386 0.024 265.7", "#DAD9D3", "oklch 0.885 0.008 100"  , "0.884 0.008  99.0", "Atom One Dark"                                                                         , NA,
  "accent"       , "#61afef", NA                    , "0.730 0.121 245.3", "#1B7EC2", "oklch 0.573 0.135 245.2", "0.573 0.135 245.2", "Atom One Dark's blue -- also the Function token"                                       , "named `accent`, not `link`: Quarto silently promotes a `color.palette` entry whose NAME is a brand role (`link`, `primary`, `danger`, ...) to that role, in BOTH modes. Verified on 1.10.18 -- a palette key `link` put this blue on the light page at Lc 30. .onLoad() now refuses any such name",
  "accent-hover" , "#81bff2", "tint accent 0.2"     , "0.782 0.097 244.3", "#0069A7", "oklch 0.503 0.127 245.1", "0.503 0.127 245.1", "bootstrap's own dark-mode $link-shade-percentage"                                      , NA,
  "code-page"    , "#1f1f1f", NA                    , "0.239 0.000 263.3", "#F4F4EF", "oklch 0.965 0.006 100"  , "0.966 0.007 106.8", "VS Code's dark ground"                                                                 , "a starless theme sets no editor background, so the code block's ground is NAMED rather than inherited",
  "inline-code"  , "#fc9867", NA                    , "0.774 0.136  46.2", "#A54A14", "oklch 0.519 0.135 46.3" , "0.519 0.135  46.1", "starless-monokai's markup.inline.raw"                                                  , NA,

  # --- the heading ladder: warm-95-10 on a dark page, warm-24-32 on a light one ---------------------------------------------------------------------------------------------------------------------------------------------
  # One hue, the body ink's own (~100), lifted and given chroma back -- so a heading is LITERALLY the text colour, brighter. h6 is FLOORED on the ink at L 0.840 and nothing
  # goes below: the search that produced this family started because a heading was DARKER than the prose it led, and the floor is what stops that returning. A rung of
  # lightness buys ~0.02 of chroma at this hue (the sRGB ceiling is 0.086 at L 0.96, 0.107 at 0.95, 0.128 at 0.94), so the top rung asks for exactly what it can hold: one
  # rung higher and the ladder's first step would have been silently clipped away.
  # THE LIGHT HALF IS THE MIRROR, and a shallow one: h1 at L 0.240 down to h6 at 0.320, CEILINGED on
  # the ink instead of floored on it, so a heading is again the text colour with one step more
  # presence. It is nearly monochrome and that is the point -- at this lightness the warm hue holds
  # 0.05 of chroma at most, and a light course page is read as bookdown and pkgdown set one: the
  # size carries the hierarchy, the warmth only says whose page it is.
  "heading-1"    , "#FEF1A1", "oklch 0.950 0.10 100", "0.951 0.101 100.1", "#242003", "oklch 0.240 0.045 100"  , "0.241 0.046 101.8", "warm-95-10"                                                                            , NA,
  "heading-2"    , "#F5E9A3", "oklch 0.928 0.09 100", "0.928 0.090  99.6", "#282309", "oklch 0.256 0.042 100"  , "0.255 0.041  98.5", "warm-95-10"                                                                            , NA,
  "heading-3"    , "#ECE2A4", "oklch 0.906 0.08 100", "0.906 0.080 100.1", "#2B270F", "oklch 0.272 0.039 100"  , "0.271 0.039 100.0", "warm-95-10"                                                                            , NA,
  "heading-4"    , "#E5DB9D", "oklch 0.884 0.08 100", "0.885 0.081 100.1", "#2F2B16", "oklch 0.288 0.036 100"  , "0.287 0.035  98.8", "warm-95-10"                                                                            , NA,
  "heading-5"    , "#DED396", "oklch 0.862 0.08 100", "0.861 0.080  99.2", "#332F1C", "oklch 0.304 0.033 100"  , "0.304 0.032  97.8", "warm-95-10"                                                                            , NA,
  "heading-6"    , "#D6CC8F", "oklch 0.840 0.08 100", "0.839 0.080 100.0", "#363321", "oklch 0.320 0.030 100"  , "0.319 0.030  99.9", "warm-95-10, floored on the ink"                                                        , NA,

  # --- prose ----------------------------------------------------------------------------------------------------------------------------------------------------------------------
  "gold"         , "#e6ae02", NA                    , "0.781 0.160  85.2", NA       , NA                       , NA                 , "the maintainer's settings.json"                                                        , "MODE-INDEPENDENT on purpose. A yellow darkened for a light page goes muddy, and this one has been read on white: it stays as it is for the `resultat` annotation and the blockquote rule. Only BOLD changes side (see the `bold` slot)",
  "quote"        , "#B7B5AC", NA                    , "0.772 0.013  96.5", "#5F5E56", "oklch 0.480 0.012 96.5" , "0.480 0.013 101.1", "the maintainer's settings.json"                                                        , "a quote recedes: the ink's own hue, a step down in lightness",
  "note"         , "#c6bf93", NA                    , "0.799 0.059 100.1", NA       , NA                       , NA                 , "the page's own warm hue at C 0.06"                                                     , "the one annotation that keeps a fill: it must read as a few lines of light mode inside a dark one, not as a highlighter pen",
  "note-ink"     , "#2C2C2C", NA                    , "0.293 0.000 263.3", NA       , NA                       , NA                 , "the note's own text colour"                                                            , NA,

  # --- the code theme's remaining colours -----------------------------------------------------------------------------------------------------------------------------------------
  # Every other token reuses a colour already above: `ink` (Normal, Variable), `accent` (Function and friends), `inline-code` (Attribute, Information).
  "comment"      , "#8b8a8d", NA                    , "0.635 0.005 301.0", "#7B797E", "oklch 0.579 0.008 303.9", "0.579 0.008 303.9", "starless-monokai's #727072, lifted"                                                    , "measured on the three dark grounds a page can show, #727072 gives Lc 3.4 / 3.1 / 2.9 -- under WCAG AA everywhere, and a page is read smaller than an editor. #8b8a8d gives 4.8 / 4.5 / 4.1. It lands close to the punctuation grey, and that is fine: comments stay ITALIC, so the style carries the distinction the luminance no longer can",
  "keyword"      , "#ff6188", NA                    , "0.706 0.194   8.4", "#891B3D", "oklch 0.420 0.145 8.4"  , "0.420 0.145   8.4", "starless-monokai"                                                                      , NA,
  "string"       , "#a9dc76", NA                    , "0.836 0.142 130.7", "#517C16", "oklch 0.535 0.135 130.7", "0.535 0.135 130.7", "starless-monokai"                                                                      , NA,
  "constant"     , "#ab9df2", NA                    , "0.741 0.122 290.7", "#503894", "oklch 0.420 0.144 290.9", "0.420 0.144 290.9", "starless-monokai"                                                                      , NA,
  "datatype"     , "#78dce8", NA                    , "0.838 0.095 205.7", "#2AB9C7", "oklch 0.721 0.115 205.2", "0.721 0.115 205.2", "starless-monokai"                                                                      , NA,
  "punctuation"  , "#939293", NA                    , "0.661 0.002 324.1", "#6A686A", "oklch 0.520 0.004 325.1", "0.520 0.004 325.1", "starless-monokai's punctuation grey"                                                   , NA,

  # --- the pandoc-span annotation classes -----------------------------------------------------------------------------------------------------------------------------------------
  # MODE-INDEPENDENT BY CONSTRUCTION, which is why the annotations stylesheet needs no light/dark cascade at all: every one sits at medium OKLCH lightness (0.585-0.799)
  # with chroma at most 0.234, chosen to clear both #FFFFFF and a dark ground. `resultat` is the prose gold and `comment-bg` the note, so neither is a row here: one
  # colour, painted twice by TX_SLOTS.
  "enjeu"        , "#d64556", NA                    , "0.600 0.180  17.8", NA       , NA                       , NA                 , "the maintainer's Zettlr palette"                                                       , NA,
  "reflexivite"  , "#13c097", NA                    , "0.720 0.140 170.0", NA       , NA                       , NA                 , "the maintainer's Zettlr palette"                                                       , NA,
  "problematique", "#01a2d6", NA                    , "0.667 0.133 230.2", NA       , NA                       , NA                 , "the maintainer's Zettlr palette"                                                       , NA,
  "structure"    , "#83adbb", NA                    , "0.722 0.050 220.4", NA       , NA                       , NA                 , "the maintainer's Zettlr palette"                                                       , NA,
  "reference"    , "#488bfa", NA                    , "0.649 0.179 260.0", NA       , NA                       , NA                 , "the maintainer's Zettlr palette"                                                       , NA,
  "concept"      , "#b87bf5", NA                    , "0.696 0.180 305.3", NA       , NA                       , NA                 , "the maintainer's Zettlr palette"                                                       , NA,
  "terrain"      , "#d8714c", NA                    , "0.660 0.139  40.1", NA       , NA                       , NA                 , "the maintainer's Zettlr palette"                                                       , NA,
  "pertinent"    , "#05ae30", NA                    , "0.653 0.204 145.0", NA       , NA                       , NA                 , "the maintainer's Zettlr palette"                                                       , NA,

  # --- the five hues a figure legend points at ------------------------------------------------------------------------------------------------------------------------------
  # NOT annotations: an annotation says what a passage IS, these say WHICH MARK ON THE DRAWING the
  # words name -- "les fleches violettes", "le cercle rouge". The hue is therefore the figure's own
  # (ggfacto and FactoMineR draw it), and only the lightness is chosen: 0.660, the lightness the
  # annotation palette already uses, which is what makes one colour legible on a white page and on
  # a dark one without a second value. The courses wrote these as colorize(x, "#d32f2f"), a literal
  # frozen into the prose and wrong in dark mode.
  "fig-rouge"    , "#F4524B", "oklch 0.660 0.200  26.4", "0.660 0.199  26.6", NA       , NA                       , NA                 , "the hue of the mark itself, as ggfacto draws it"                                        , NA,
  "fig-violet"   , "#9E7ED7", "oklch 0.660 0.132 299.3", "0.659 0.132 299.3", NA       , NA                       , NA                 , "the hue of the mark itself, as ggfacto draws it"                                        , NA,
  "fig-orange"   , "#D87322", "oklch 0.660 0.153  53.5", "0.659 0.153  53.4", NA       , NA                       , NA                 , "the hue of the mark itself, as ggfacto draws it"                                        , NA,
  "fig-bleu"     , "#3798E6", "oklch 0.660 0.146 247.0", "0.660 0.146 247.0", NA       , NA                       , NA                 , "the hue of the mark itself, as ggfacto draws it"                                        , NA,
  "fig-vert"     , "#58A859", "oklch 0.660 0.138 144.0", "0.661 0.138 144.1", NA       , NA                       , NA                 , "the hue of the mark itself, as ggfacto draws it"                                        , NA,
  "preciser"     , "#ff8700", NA                    , "0.743 0.182  56.0", NA       , NA                       , NA                 , "the maintainer's Zettlr palette"                                                       , NA,
  "non"          , "#e61301", NA                    , "0.585 0.234  30.0", NA       , NA                       , NA                 , "the maintainer's Zettlr palette"                                                       , NA
))


# === SECTION: where each colour is painted ========================================================
# slot          the key, unique
# colour        a foreign key into TX_PALETTE -- the colour this slot is painted with
# colour_light  a DIFFERENT foreign key for the light page, where the slot is not the same decision
#               in both modes. NA everywhere but `bold`, and that one row is the whole reason the
#               column exists: on white, bold is loud enough as bold, so it stays the emphasis
#               black; on a dark page bold reads weakly, so it takes the gold. A colour that merely
#               has two VALUES needs nothing here -- that is TX_PALETTE's `light` column.
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
  ~slot             , ~colour        , ~colour_light, ~emit       , ~ground, ~bs_var                , ~bs_rgb                    , ~sass_var             , ~css_var         , ~selector         , ~prop              , ~alpha, ~style                                , ~why,

  # --- the chrome ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  "page-bg"         , "page"         , NA           , "chrome"    , NA     , "--bs-body-bg"         , "--bs-body-bg-rgb"         , "$body-bg"            , NA               , NA                , NA                 , NA    , NA                                    , NA,
  "ink"             , "ink"          , NA           , "chrome"    , "page" , "--bs-body-color"      , "--bs-body-color-rgb"      , "$body-color"         , NA               , NA                , NA                 , NA    , NA                                    , NA,
  "ink-secondary"   , "ink"          , NA           , "chrome"    , "page" , "--bs-secondary-color" , NA                         , NA                    , NA               , NA                , NA                 , 0.75  , NA                                    , "bootstrap would compute this from its own stock grey; stated so the sidebar and footer follow the ink. Quarto needs no row of its own: it derives it from $body-color",
  "ink-tertiary"    , "ink"          , NA           , "chrome"    , "page" , "--bs-tertiary-color"  , NA                         , NA                    , NA               , NA                , NA                 , 0.5   , NA                                    , NA,
  "emphasis"        , "emphasis"     , NA           , "chrome"    , "page" , "--bs-emphasis-color"  , "--bs-emphasis-color-rgb"  , "$body-emphasis-color", NA               , NA                , NA                 , NA    , NA                                    , NA,
  "heading-fallback", "heading-1"    , NA           , "chrome"    , "page" , "--bs-heading-color"   , NA                         , "$headings-color"     , NA               , NA                , NA                 , NA    , NA                                    , "bslib has ONE headings variable, so the ladder below cannot be one: this is only what its six rules do not reach",
  "panel-bg"        , "panel"        , NA           , "chrome"    , NA     , "--bs-tertiary-bg"     , NA                         , "$body-tertiary-bg"   , NA               , NA                , NA                 , NA    , NA                                    , NA,
  "border"          , "border"       , NA           , "chrome"    , NA     , "--bs-border-color"    , NA                         , "$border-color"       , NA               , NA                , NA                 , NA    , NA                                    , NA,
  "link"            , "accent"       , NA           , "chrome"    , "page" , "--bs-link-color"      , "--bs-link-color-rgb"      , "$link-color"         , NA               , NA                , NA                 , NA    , NA                                    , NA,
  "link-hover"      , "accent-hover" , NA           , "chrome"    , "page" , "--bs-link-hover-color", "--bs-link-hover-color-rgb", "$link-hover-color"   , NA               , NA                , NA                 , NA    , NA                                    , NA,
  "inline-code-ink" , "inline-code"  , NA           , "chrome"    , "page" , "--bs-code-color"      , NA                         , "$code-color"         , NA               , NA                , NA                 , NA    , NA                                    , NA,
  "highlight"       , "gold"         , "accent"     , "chrome"    , "page" , NA                     , NA                         , NA                    , "--highlight"    , NA                , NA                 , NA    , NA                                    , "the accent of the EXERCISE chrome -- webexercises' box borders and check button, and the courses' `.exercise` title rule. It is DECLARED IN webex.css, so a themed page without webexercises lost it silently. It changes side like `bold` does, and for the same reason: the blue that carries a page's links is the right accent on white and dies on a dark ground, where the gold is what the eye already reads as emphasis",

  # --- the heading ladder -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  "h1"              , "heading-1"    , NA           , "heading"   , "page" , NA                     , NA                         , NA                    , NA               , "h1"              , "color"            , NA    , NA                                    , NA,
  "h2"              , "heading-2"    , NA           , "heading"   , "page" , NA                     , NA                         , NA                    , NA               , "h2"              , "color"            , NA    , NA                                    , NA,
  "h3"              , "heading-3"    , NA           , "heading"   , "page" , NA                     , NA                         , NA                    , NA               , "h3"              , "color"            , NA    , NA                                    , NA,
  "h4"              , "heading-4"    , NA           , "heading"   , "page" , NA                     , NA                         , NA                    , NA               , "h4"              , "color"            , NA    , NA                                    , NA,
  "h5"              , "heading-5"    , NA           , "heading"   , "page" , NA                     , NA                         , NA                    , NA               , "h5"              , "color"            , NA    , NA                                    , NA,
  "h6"              , "heading-6"    , NA           , "heading"   , "page" , NA                     , NA                         , NA                    , NA               , "h6"              , "color"            , NA    , NA                                    , NA,

  # --- prose: what the editor theme colours in markdown, and bootstrap has no variable for --------------------------------------------------------------------------------------------------------------------------------------------
  "bold"            , "gold"         , "emphasis"   , "prose"     , "page" , NA                     , NA                         , NA                    , NA               , "strong, b"       , "color"            , NA    , NA                                    , NA,
  "quote-rule"      , "gold"         , NA           , "prose"     , NA     , NA                     , NA                         , NA                    , NA               , "blockquote"      , "border-left-color", NA    , NA                                    , NA,
  "quote-text"      , "quote"        , NA           , "prose"     , "page" , NA                     , NA                         , NA                    , NA               , "blockquote"      , "color"            , NA    , "font-style: italic"                  , NA,
  "inline-code-pill", "inline-code"  , NA           , "prose"     , NA     , NA                     , NA                         , "$code-bg"            , NA               , ":not(pre) > code", "background-color" , 0.2   , "padding: 3px 5px; border-radius: 5px", "the same orange as the ink on it, at a fifth: a fill on a dark page reads as a TINT OF THE PAGE, not as a colour of its own. The SASS half is not a duplicate: Quarto paints `p code:not(.sourceCode)` at (0,1,2), which outranks the rule beside it",
  "code-ground"     , "code-page"    , NA           , "prose"     , NA     , NA                     , NA                         , "$code-block-bg"      , NA               , "pre"             , "background-color" , NA    , NA                                    , "the SASS half is what reaches a HIGHLIGHTED block: Quarto makes `pre.sourceCode` transparent and paints `div.sourceCode` instead, so the rule beside it only ever reached an OUTPUT block",

  # --- the annotation classes: the custom properties inst/prose/annotations.scss reads -------------------------------------------------------------------------------------------------------------------------------------------------
  "an-enjeu"        , "enjeu"        , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--enjeu"        , NA                , NA                 , NA    , NA                                    , NA,
  "an-resultat"     , "gold"         , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--resultat"     , NA                , NA                 , NA    , NA                                    , "the prose gold again: a result IS the emphasis, so it is one colour painted twice, not two colours that happen to agree",
  "an-reflexivite"  , "reflexivite"  , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--reflexivite"  , NA                , NA                 , NA    , NA                                    , NA,
  "an-problematique", "problematique", NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--problematique", NA                , NA                 , NA    , NA                                    , NA,
  "an-structure"    , "structure"    , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--structure"    , NA                , NA                 , NA    , NA                                    , NA,
  "an-reference"    , "reference"    , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--reference"    , NA                , NA                 , NA    , NA                                    , NA,
  "an-concept"      , "concept"      , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--concept"      , NA                , NA                 , NA    , NA                                    , NA,
  "an-terrain"      , "terrain"      , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--terrain"      , NA                , NA                 , NA    , NA                                    , NA,
  "an-pertinent"    , "pertinent"    , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--pertinent"    , NA                , NA                 , NA    , NA                                    , NA,
  "an-preciser"     , "preciser"     , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--preciser"     , NA                , NA                 , NA    , NA                                    , NA,
  "an-non"          , "non"          , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--non"          , NA                , NA                 , NA    , NA                                    , NA,
  "an-comment-bg"   , "note"         , NA           , "annotation", NA     , NA                     , NA                         , NA                    , "--comment-bg"   , NA                , NA                 , NA    , NA                                    , NA,
  "an-comment-text" , "note-ink"     , NA           , "annotation", "note" , NA                     , NA                         , NA                    , "--comment-text" , NA                , NA                 , NA    , NA                                    , NA,

  # --- the figure-legend hues: same channel as the annotations, a different vocabulary --------------------------------------------------------------------------------------
  "an-fig-rouge"    , "fig-rouge"    , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--fig-rouge"    , NA                , NA                 , NA    , NA                                    , NA,
  "an-fig-violet"   , "fig-violet"   , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--fig-violet"   , NA                , NA                 , NA    , NA                                    , NA,
  "an-fig-orange"   , "fig-orange"   , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--fig-orange"   , NA                , NA                 , NA    , NA                                    , NA,
  "an-fig-bleu"     , "fig-bleu"     , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--fig-bleu"     , NA                , NA                 , NA    , NA                                    , NA,
  "an-fig-vert"     , "fig-vert"     , NA           , "annotation", "page" , NA                     , NA                         , NA                    , "--fig-vert"     , NA                , NA                 , NA    , NA                                    , NA
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
