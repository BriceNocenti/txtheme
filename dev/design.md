# One theme for pkgdown, Quarto and the editor

The design record. Every claim marked ✓ was verified on this machine; how, and with what versions, is in Appendix A. Present tense throughout: this describes what txtheme is, not how it got there.

## 1. What this is for

Four things display the same author's work, and each was themed in a different language:

- the **tabxplor pkgdown site** — bslib variables, pkgdown highlight styles, `tab_css()`;
- the **statistics courses** (`~/github/formations_stat`) — `webexercises::webexercises_default2()`, i.e. `bookdown::html_document2` plus a hand-written 769-line `style.css` and a pandoc `highlight:` name;
- the **bookdown books** (`~/github/formations_stat/books/…`) — the same again, per book;
- **Positron**, where the author writes and where the students read code — the *Starless Monokai Atom* theme.

The friction was never that any one of them is hard. It is that **a colour decision had to be re-made in four places**, in four notations, and that a new output format meant starting again. txtheme is the framework where a colour is decided **once** and every consumer is a few lines of YAML.

Two non-goals, stated up front because they keep the design small:

- **not a design system.** No components, no utility classes, no grid. A palette, a code theme, and a handful of prose rules.
- **not a tabxplor feature.** Table colours already have a single source of truth (`tab_css()`); see §9.

## 2. What each consumer can actually read

The design is entirely determined by this table, so it is the first thing to check when a version changes.

| consumer                  | page chrome                            | code colours                                 |
|---------------------------|----------------------------------------|----------------------------------------------|
| pkgdown 2.2               | a **rules layer** of `--bs-*` properties ✓ | `theme:` / `theme-dark:`, 35 bundled `.scss` |
| Quarto 1.10               | Sass variables, and `brand:` ✓         | `syntax-highlighting: {light, dark}` ✓        |
| bookdown `html_document2` | `theme:` (bootswatch) or raw `css:`    | pandoc `highlight:` — a name **or a `.theme` path** ✓ |
| Positron / VS Code        | theme JSON                             | the same JSON                                |
| tabxplor tables           | —                                      | —                                            |

| consumer                  | extra CSS                                     | light/dark                                  |
|---------------------------|-----------------------------------------------|---------------------------------------------|
| pkgdown 2.2               | `pkgdown/extra.scss`, `template: package:` ✓  | `light-switch: true` → `data-bs-theme`      |
| Quarto 1.10               | `theme: [brand, extra.scss]`, or an extension | built in → two stylesheets, swapped ✓       |
| bookdown `html_document2` | `css:`                                        | **none**                                    |
| Positron / VS Code        | —                                             | editor setting                              |
| tabxplor tables           | `tab_css()`                                   | **already follows both** ✓                  |

Four consequences drive everything below.

1. **pkgdown does not need a brand file, and does not get one.** `template: package:` adds the package's `inst/pkgdown/BS5/extra.scss` with `bslib::bs_add_rules()` — a *rules* layer, landing at the very end of the compiled CSS ✓. A Sass *variable* set there is inert, but a Bootstrap 5.3 **custom property** is not, and all eight chrome targets have `--bs-*` twins. So the package delivers the whole chrome from CSS alone: no `bslib:` block, no `brand.yml` dependency, one line of consumer YAML.

2. **⚠ The `-rgb` twins are not decoration.** Bootstrap derives `--bs-secondary-color` / `--bs-tertiary-color` as `rgba()` of the **literal** body-colour channels, and `pkgdown.scss` reads `var(--bs-body-color-rgb)` in eleven places ✓. Setting the hex alone leaves the sidebar, the footer and the mermaid chrome on Bootstrap's stock cool grey — visibly, subtly wrong. Links are worse: `a { color: rgba(var(--bs-link-color-rgb), …) }` reads **only** the twin, so the hex alone does nothing at all. The generator emits each twin beside its hex, and the two derived `rgba()` rules explicitly.

3. **pkgdown's `.scss` styles and pandoc's `.theme` files are the same vocabulary.** Both enumerate skylighting's 31 token types — pkgdown as two-letter classes (`co`, `st`, `fu`, …), pandoc as names (`Comment`, `String`, `Function`, …) ✓. One grid therefore generates both, mechanically and without judgement.

4. **bookdown has no dark mode, but it can have the code theme.** `rmarkdown`'s `highlight:` takes a path to a `.theme` file ✓, so a course page gets the 31 colours today, without moving to Quarto. What it cannot have is a switch, which is why moving the courses is still worth doing (§8).

## 3. The four layers

| layer          | what it decides                     | single source                    | consumed as                          |
|----------------|-------------------------------------|----------------------------------|--------------------------------------|
| **A. palette** | background, text, links, borders    | `TX_PALETTE` + `TX_SLOTS`        | `--bs-*` (pkgdown); `$vars` (Quarto) |
| **B. code**    | the 31 syntax tokens                | `TX_TOKENS`                      | `.scss`; `.theme`; `textMateRules`   |
| **C. prose**   | bold, quotes, inline code, notes    | `TX_SLOTS` + `inst/prose/`       | the same `.scss` layers              |
| **D. tables**  | tabxplor cells                      | `tab_css()`, inside tabxplor     | automatic in both ✓                  |

Layer D is the proof that this works: `tab_css(theme = "auto")` writes its cascade against `[data-bs-theme=dark]` **and** `body.quarto-dark`, so a tabxplor table already follows the reader on a pkgdown site and in a Quarto document, with no theme code of ours involved ✓. txtheme's job is to make layers A–C behave the same way.

## 4. Architecture

```text
                    R/aaa-palette.R
        TX_PALETTE · TX_SLOTS · TX_TOKENS · TX_BRAND
              (four grids, one fact per row)
                           │
                  R/build-theme.R        ← the ONE generator, run by hand
                           │
   ┌───────────┬───────────┼────────────┬─────────────┬────────────┐
   ▼           ▼           ▼            ▼             ▼            ▼
extra.scss  annotations  txtheme-dark  txtheme-dark  _brand.yml  token-
(pkgdown)   .css (opt-in) .scss (pkgdown/  .scss+.theme  (Quarto)  colors.json
                           bookdown)     (Quarto)                 (editor)
```

Read it as one rule: **nothing downstream is edited by hand**, and a file's first line says which side of that line it is on. The only hand-written artefacts are `inst/prose/annotations.scss` (typography no palette can express), the `.at` JS shim, the `in-header.html` override and `_extension.yml`.

`build_theme(check = TRUE)` rebuilds every output in memory and diffs it against disk; the test suite asserts it is clean. Two rules make that possible: **no dates in any banner**, and sorted keys in the JSON and the YAML.

## 5. Where it lives

One repository, `BriceNocenti/txtheme`, that is both an R package and a Quarto extension — because the two mechanisms that make this frictionless are already provided by the two toolchains. pkgdown reads a theme from an R package (`pkgdown:::bs_theme_rules()` looks for `inst/pkgdown/BS5/extra.scss` in the package named by `template: package:` ✓); Quarto installs an extension from a GitHub repository (`quarto add BriceNocenti/txtheme` copies `_extensions/txtheme/`). The R package sits at the root, `_extensions/` beside it and `.Rbuildignore`d.

The alternatives were weighed and rejected. Inside tabxplor: it is a CRAN package about cross-tables, personal branding is out of its scope, and it would tie a theme's release cycle to a statistics package's. Inside the webexercises fork: that fork tracks an upstream, and the more it carries that upstream does not, the harder every rebase gets. No package at all, files copied per project: that is exactly the 769-line `style.css`, four times over.

### 5.1 And the editor extension — separate, and one-directional

Only the **palette** is shared with the editor; not code. The editor consumes it as `editor.tokenColorCustomizations` JSON, pkgdown as scss, Quarto as a `.theme` file and a brand file — one small data table plus generators, which a single repository gives you and which a generator writing a second repository gives you just as well.

Three costs would be paid forever for merging: two exclusion lists that every new directory must be added to (`.Rbuildignore` hiding `package.json` and `syntaxes/`, `.vscodeignore` hiding `R/` and `inst/`), one version number over three cadences, and the fact that the existing extension is not a theme — `pandoc-span-highlight` injects a TextMate grammar and contributes a render-to-PowerPoint command, of which colour is the smallest part.

⚠ **And the argument that would have justified merging does not hold: VS Code settings have no include mechanism.** `editor.tokenColorCustomizations` must sit inline in `settings.json`, so the editor side is a paste (or a synced profile) whatever the repository layout is. One repository would not make it automatic.

So: they stay separate and the flow is one-directional. txtheme owns the palette and *generates* the editor block; `pandoc-span-highlight` keeps the grammar and the command, and owns no colour. Revisit only if the editor side ever becomes a **published, colour-only** theme of its own — that is, if txtheme stops overriding *Starless Monokai Atom* and replaces it. Then the palette and the theme are the same artefact, and one repository is the natural home.

## 6. What you write, per project

See the README. It is three lines for pkgdown, one for Quarto, and one for bookdown, which is the whole point of the framework.

## 7. The generator

`build_theme(path, check, quiet)` — validate, then write. Its stages, and what each output is for:

| output                                            | consumer                                                |
|---------------------------------------------------|---------------------------------------------------------|
| `inst/pkgdown/BS5/extra.scss`                     | pkgdown: chrome + ladder + prose + code, one file       |
| `inst/pkgdown/BS5/assets/txtheme-annotations.css` | pkgdown, **opt-in** — see the warning below             |
| `inst/highlight/txtheme-dark.scss`                | a site naming the style instead of taking the package   |
| `inst/highlight/txtheme-dark.theme`               | rmarkdown / bookdown, as a `highlight:` path            |
| `inst/brand/_brand.yml`                           | Quarto, auto-discovered at a project root               |
| `inst/brand/_brand-dark.yml`                      | anything that cannot take `{light:, dark:}` — see below |
| `inst/editor/token-colors.json`                   | the editor: a ready `textMateRules` block to paste      |
| `_extensions/txtheme/*.scss`, `*.theme`           | Quarto, through `quarto add`                            |

**The validate stage is where readability is measured**, not recorded: `build_theme()` prints one APCA `|Lc|` per slot, against the ground that slot is read on. A slot knows its ground; a colour does not — which is why there is no `apca` column in `TX_PALETTE` and no `oklch` cell that is not also re-derived from its hex at load.

⚠ **The annotation stylesheet cannot be a global site asset.** `pkgdown.scss` styles `pre code .error, pre code .warning`, and a built reference page really does emit `<span class="warning">` for an example's warning. The annotation sheet's `.non, .error {text-decoration: underline double !important}` would decorate every warned or errored example on the live site. It is an opt-in link (`template: params: txtheme: {annotations: true}`), never baked into `extra.scss`.

⚠ **A Quarto `color.palette` name shares a namespace with the brand roles.** An entry named after a role (`link`, `primary`, `danger`, …) is promoted to that role, in **both** modes and with no message ✓ — a palette key `link` put the dark accent blue on the light page at Lc 30. That is why the blue is called `accent`, and why `.onLoad()` refuses any such name. A role that names only one mode, by contrast, is correctly ignored in the other ✓.

### 7.1 The token mapping, and its two judgement calls

`TX_TOKENS` is the mapping between skylighting's 31 types, pkgdown's two-letter classes and TextMate scopes. Two rows are decisions rather than translations, and both carry their reasoning in the grid's `why` cell:

⚠ **`.op` takes the punctuation grey.** downlit tags `(`, `,`, `$` **and** `<-` all as `.op` — 317 of them on one vignette page, the commonest class by far. In the editor the brackets are punctuation grey and only `<-` is pink; pink for all of them makes every bracket shout. It is the one place the port is *deliberately* not the editor.

⚠ **An R argument name is tagged by one highlighter and not the other.** Pandoc marks `pct =` as Attribute (`<span class="at">pct =</span>`), so Quarto colours it from the `.theme` file for free; **downlit leaves the name as bare text** — only the `=` beside it is tagged — and no CSS selector can reach a bare text node. pkgdown therefore gets a fifteen-line DOM shim (`inst/pkgdown/BS5/assets/txtheme-at.js`), shipped by the package and pulled in by its own `in-header.html`, so consumer YAML stays untouched. Two things make it exact rather than a heuristic: it works on the parsed DOM, so it can never touch a string or a comment, and downlit emits each operator as one span, so `==`, `<=`, `!=` and `<-` never match. A pandoc block is immune by construction — there the `=` lives *inside* the `at` span, so the loop finds nothing to do.

pkgdown searches the site's own `pkgdown/templates/` before the package's ✓, so a consumer can always shadow the override back; the package's copy keeps pkgdown's own `{{#includes}}{{{in_header}}}{{/includes}}` line so that `template: includes:` keeps working.

The other deliberate departures from the editor theme, all from the author's own `settings.json`, are `why` cells in `TX_PALETTE`: base text `#CDCBBC` instead of `#fcfcfa` (a near-white makes the text louder than the colours it sits among), gold `#e6ae02` bold, a `#B7B5AC` italic block quote with a gold rule, `#fc9867` inline code, and `#1f1f1f` as the code ground (VS Code's own, which is what a *starless* theme inherits in the editor).

⚠ Comments are **lighter** than the editor's. Measured on the three dark grounds a page can show (`#1f1f1f` / `#21252b` / `#282c34`), the theme's own `#727072` gives 3.4 / 3.1 / 2.9 to 1 — under WCAG AA everywhere, and a page is read at a smaller size than an editor. `#8b8a8d` gives 4.8 / 4.5 / 4.1. It lands close to the punctuation grey, and that is fine: comments stay *italic*, so the style carries the distinction the luminance no longer can.

### 7.2 The palette, decided

The dark half is **one hue**. Everything warm on the page sits at OKLCH hue ~100, which is not a coincidence to be admired but the thing that makes a chroma cap possible later: the page can be desaturated as a whole and stays coherent, because there is only one hue to desaturate.

| role | value | OKLCH |
|---|---|---|
| body ink | `#CDCBBC` | 0.840 · 0.020 · 101 |
| **headings, h1 → h6** | `warm-95-10` | L 0.95 → **0.84**, C 0.10 0.09 0.08 0.08 0.08 0.08, h 100 |
| | `#FEF1A1 #F5E9A3 #ECE2A4 #E5DB9D #DED396 #D6CC8F` | |
| the note (`.comment`) | `#c6bf93` | 0.799 · 0.059 · 100 |
| bold / `.resultat` | `#e6ae02` | 0.781 · 0.160 · 85 |
| inline code | `#fc9867` | 0.774 · 0.136 · 46 |
| page | `#21252b` | 0.263 |

Three decisions are worth keeping, because each was arrived at against an alternative that looked right and measured wrong:

- **h6 is floored on the ink.** Its L is 0.840 — the body text's own lightness — and nothing goes below. The search started because the previous heading green was *darker* than the prose it led; stating the floor is what stops that returning.
- **A rung of lightness buys about 0.02 of chroma.** At hue 100 the sRGB ceiling is 0.086 at L 0.96, 0.107 at 0.95, 0.128 at 0.94. `warm-95-10` asks for exactly what its top rung can hold; one rung higher and the 0.10 would have been silently clipped, which is what makes a ladder's first step disappear.
- **The chroma is what separates a heading from a bold run**, not the hue. The closest rung to the gold is h6 at 0.093 in OKLab — comfortable, but a third of the clearance a green ladder had. The gap is −0.08 of chroma against +0.04 of lightness and 15° of hue. ⚠ A global chroma cap therefore erodes exactly that: at a cap of 0.08 the two close to 0.045, near the 0.036 that counts as a collision. The cap and the warm family pull against each other, and the lever that survives a cap is lightness.

The six hexes are never hand-typed: each row's `spec` cell states `oklch 0.950 0.10 100`, and `.onLoad()` rebuilds the hex from it and refuses a mismatch. A hex that no longer matches its own construction is a silent drift; here it is an install failure.

The annotation classes keep their published colours and lose their boxes: on a rendered page a chip per annotated phrase turns prose into a mosaic, so an annotation is its text colour and nothing else. `.comment` alone keeps a fill, because it has to read as something added in the margin. The palette is mode-independent by construction — every one sits at medium OKLCH lightness with chroma capped, chosen to clear both `#FFFFFF` and a dark ground — which is why that stylesheet needs no light/dark cascade at all.

### 7.3 The light half

Every grid has a `light` column and every emitter reads it; today no colour fills one in, so the light half is pkgdown's and Quarto's own (`arrow-light` plus Bootstrap defaults) and **light is a mode argument, not a second writer**. Filling the column in is the whole of adding a light theme: `extra.scss` grows an unprefixed cascade, the brand file grows a `light:` line per role, and a second `.scss` / `.theme` pair appears for Quarto — with no change to any emitter.

## 8. What remains

**The courses and the books** (`~/github/formations_stat`) are the migration this framework was built for, and they are a separate project: that repository is 100 % bookdown with no `.qmd` files at all. The order, when it happens:

1. **Pilot one course in Quarto**, the shortest one. Two things must survive the move: `webexercises` (its `.qmd` path already exists — `webexercises::add_to_quarto()`, and §9.1 is what makes it follow the switch) and the tabxplor tables (nothing to do — layer D ✓). What of `style.css` is worth keeping is inventoried in Appendix C: of its 769 lines, only about 80 are live CSS, and a third of those are table rules `tab_css()` has since absorbed.
2. **The books.** A Quarto book is the same format plus `_quarto.yml`; the framework does not distinguish them.
3. **Retire `style.css`** and the per-project `highlight:` lines.

Until then the bookdown courses keep working unchanged and can take the code theme alone, `highlight: !expr txtheme::txtheme_file("highlight/txtheme-dark.theme")` ✓ — no dark mode, which is what bookdown offers.

## 9. What deliberately stays outside

- **tabxplor's table colours.** `tab_css()` is the single source for anything inside a `.tabxplor-tab`, in every medium, and it already follows both toolchains' dark hooks ✓. **Rule: txtheme never writes a selector containing `.tabxplor-tab`.** If a table looks wrong on a themed page, the fix belongs in tabxplor.
- **`webexercises`.** Exercise widgets, their CSS and their JS. The fork stays a thin fork — with the one exception §9.1 defines.
- **Fonts.** `style.css` currently pulls DejaVu from `raw.githubusercontent.com` at page load — a third party in the render path of every course page. `brand.yml`'s `typography.fonts` takes Google or Bunny fonts, or files bundled in the package; either is better, and the choice is worth making explicitly rather than inheriting.

### 9.1 webexercises, on a page with a switch

A course page carries the switch, so the exercise widgets have to follow it — and they are the one part of the stack written for a light page only. `webex.css` (217 lines) is in good shape for this: **seven of its colours are already `:root` variables**, which the theme can redefine under the dark hooks without touching the file at all.

| variable | light (upstream) | what it colours |
|---|---|---|
| `--correct` / `--incorrect` | `#59935B` / `#983E82` | the border of an answered field |
| `--correct_alpha` / `--incorrect_alpha` | `#c0edc2` / `#edaddd` | its fill — **pastels, made for white** |
| `--correct_text` / `--incorrect_text` | `#00D26A` / `#c60800` | the score line under a check button |
| `--highlight` | `#467AAC` | the check button, and the `.exercise` underline |

⚠ **`--highlight` is declared in `webex.css`, and the courses use it for their own `.exercise` class.** A page with the theme but without webexercises therefore loses that underline's colour silently — it falls back to `currentColor`. The theme must declare `--highlight` itself, from the brand's `primary`.

**Four values are literals, and no redefinition can reach them.** They are what actually breaks on a dark page:

| `webex.css` | literal | breaks as |
|---|---|---|
| `.unchecked .webex-incorrect` / `-correct` | `background-color: white !important` | a white field on a dark page |
| `.webex-select, input.webex-solveme, .unchecked … label` | `background-color: white` | the same, for text inputs |
| `.webex-incorrect, … label.webex-incorrect` | `color: black` | black on a dark-mode fill |
| `.webex-correct, … label.webex-correct` | `color: black` | the same |

**The fix is four one-word edits in the fork, not four override rules in the theme.** Each literal becomes a variable *with the literal as its fallback* — `background-color: var(--webex-field-bg, white)`, `color: var(--webex-answer-fg, black)` — so the file behaves **identically** where no theme is loaded, the theme needs no `!important` war against an `!important` rule, and the change is small enough to offer upstream. That refines §9's rule rather than breaking it: **the fork may turn a literal into a variable that keeps the literal as its fallback; it never gains a colour of its own.**

The dark values themselves are a design decision, not a conversion: the pastels cannot simply be darkened, because a fill on a dark page reads as a **tint of the page**, not as a colour of its own. The shape that works is the same one the inline-code pill uses — the semantic hue at ~20 % alpha over whatever the page is, with the text left at the page's own foreground rather than forced to black.

---

## Appendix A — verified facts

Measured 2026-08-27 and 2026-08-28: pkgdown 2.2.1, bslib 0.11.0, sass 0.4.10 (libsass), Quarto 1.10.18 (Positron-bundled), rmarkdown, R 4.6.1.

- **pkgdown reads a theme from a package as a RULES layer** — `pkgdown:::bs_theme_rules()` returns `pkgdown.scss` → `template.theme` → the package's `extra.scss` → the site's own, and `pkgdown:::bs_theme()` appends them all with `bslib::bs_add_rules()`. `template.theme-dark` is wrapped in `[data-bs-theme="dark"] { … }` and appended *after* all of them, so only an extra element in a selector out-specifies it.
- **The chrome survives being a rules layer** — the compiled site CSS carries `--bs-body-color-rgb: 205,203,188` (not Bootstrap's stock `222,226,230`), `rgba(205,203,188,0.75)`, the six heading rules and 30 scoped token rules.
- **Bootstrap 5.3.8 emits 52 custom properties** inside `[data-bs-theme="dark"]`, plus `color-scheme`. `a { color: rgba(var(--bs-link-color-rgb), var(--bs-link-opacity, 1)) }` — the hex alone reaches nothing.
- **`@extend` gives the ladder its utility twins for free** — Bootstrap's `.h1 { @extend h1 }` makes `html[data-bs-theme="dark"] h1` compile to `html[…] h1, html[…] .h1`.
- **pkgdown copies the package's assets and searches templates in order** — `copy_assets()` copies `inst/pkgdown/BS5/assets/*` to the site root; `template_candidates()` searches the site's own `pkgdown/templates/`, then the package's, then pkgdown's.
- **`template: params:` reaches a template as `{{#yaml}}`** — `pkgdown:::data_template()` sets `out$yaml <- config_pluck(pkg, "template.params")`.
- **⚠ libsass cannot compile CSS `min()` with mixed units** — `min(80vh, 34rem)` aborts the whole site build with *"Internal Error: Incompatible units"*. Uppercase `MIN(...)` matches no Sass function and is passed through; pkgdown's own `pkgdown.scss` writes `MAX(100%, 20rem)` for the same reason.
- **Quarto compiles a whole separate stylesheet per mode and swaps them** — it does *not* set `data-bs-theme`, so the `[data-bs-theme=dark]` block inside its dark sheet is inert and `:root` is what applies. Setting `$body-color` there yields `--bs-body-color-rgb: 205, 203, 188` correctly: **the `-rgb` trap is pkgdown's alone.**
- **Quarto auto-discovers `_brand.yml` at a project root** with no `brand:` key anywhere; its palette reaches both stylesheets as `--brand-<name>` custom properties.
- **⚠ A `color.palette` entry named after a brand role is promoted to that role, in both modes** — a palette key `link: "#61afef"` set `--bs-link-color` on the *light* stylesheet. Renaming it to `accent` restored Bootstrap's `#0d6efd`.
- **A brand role that names only one mode is correctly ignored in the other** — `background: {dark: page}` leaves the light stylesheet on `#ffffff`.
- **`brand:` under `format: html:` is ignored** — the same document with `brand:` nested produced two byte-identical stylesheets carrying none of the brand colours.
- **An extension cannot set `brand:` for its consumer** — that key is resolved from project/document metadata, not from a format's render defaults.
- **Quarto takes a light/dark code theme** — `syntax-highlighting: {light:, dark:}` produced two `quarto-syntax-highlighting*.css`, linked as `quarto-color-scheme` and `quarto-color-scheme quarto-color-alternate`.
- **rmarkdown takes a `.theme` file path in `highlight:`** — `highlight: !expr txtheme::txtheme_file("highlight/txtheme-dark.theme")` put the token colours in the rendered HTML.
- **The two code-theme formats share one vocabulary** — a pandoc `.theme` has 31 `text-styles`; pkgdown's `.scss` files carry the same 31 as two-letter classes. A `_comments` key is accepted (pandoc's own `a11y-dark` carries one).
- **tabxplor already follows both** — `tx_dark_hooks` (`R/tab-css.R`) contains `[data-bs-theme=dark]` *and* `body.quarto-dark`.
- **⚠ `light-switch: true` is silently load-bearing** — `pkgdown:::bs_theme()` only appends the dark block `if (uses_lightswitch(pkg))`, and every txtheme rule is scoped under `html[data-bs-theme="dark"]`. Forgetting the switch means the theme never matches anything, with no error. Nothing in the generator can check a consumer's YAML, which is why it is a README line and a banner comment.

## Appendix B — what is left of the courses' `style.css`

`~/github/formations_stat/style.css` is 769 lines, of which **about 80 are live CSS**: the rest is commented-out experiments (three TOC layouts, an xaringanExtra clipboard button, and one whole duplicated block at the end). `resources/tab.css` is 76 lines and **entirely** old table styling.

**Discarded without asking**, because something else now owns it:

- everything matching `.lightable-classic` and `.popover`, in both files — kableExtra's table skin and tabxplor's old tooltip. `tab_css()` has owned all of it since tabxplor 2.0.0, and kableExtra was dropped from the package entirely.
- everything matching `.webex-*`, `textarea`, and the three `--show_answers` / `--try_again` / `--welldone` strings — webexercises' own, and §9.1 is where they are dealt with.
- every commented-out block.

⚠ **`--border-color` is used and never defined** (`resources/tab.css`, the `.lightable-classic` border rules). A `var()` that resolves to nothing makes the whole declaration invalid, so those borders have never been drawn. Nothing to port; worth knowing before anyone "restores" it.

**The candidates.** Nothing below is applied yet — this is the list to choose from.

| # | element | what it does | note |
|---|---|---|---|
| 1 | **DejaVu Sans / Sans Condensed** (4 `@font-face`) | the course typeface | keep the face, change the delivery |
| 2 | **heading family + bold** | `DejaVu Sans`, bold, `!important` | drop `!important`; brand `typography.headings` |
| 3 | **heading spacing ladder** | `padding-top`: h1 10, h2 **150**, h3 40, h4 20px | a scroll-anchor hack — see below |
| 4 | **heading scale** | h4 underlined, h5 16px, h6 14px italic | a real voice, cheap to keep |
| 5 | **tight paragraph rhythm** | `p` 8px/2px, `ul p` 0 | what makes a dense course page readable |
| 6 | **`.compact-list`** | tighter still, opt-in per list | keep as is |
| 7 | **`.column-display`** | a flex row of columns | Quarto has `:::{.columns}` natively |
| 8 | **`.footnote`** | 80 %, tight leading | keep as is |
| 9 | **`.exercise span`** | underlined term, 3px | needs `--highlight` (§9.1) |
| 10 | **code wrapping trio** | `pre {word-break: normal}`, `white-space: inherit` on code | check the intent first |

Four of them deserve a sentence before they are chosen:

- **#1 fonts.** Worth keeping for a reason beyond taste: `tab_css()` already asks for *DejaVu Sans Condensed* for table text, so the course typeface and the tables' agree today by coincidence. But the delivery must change: `style.css` pulls the `.ttf` from `raw.githubusercontent.com` on every page load — a third party in the render path, serving a file GitHub does not promise to keep at that URL. Bundle the woff2 in txtheme, or take the face from Google/Bunny through `typography.fonts`.
- **#3 heading spacing.** `h2 { padding-top: 150px }` is not typography, it is a scroll offset for a fixed header — and it also pushes 150 px of blank into every printed page. Quarto handles anchor offsets itself; if the intent survives the move, `scroll-margin-top` is the property that means it.
- **#7 columns.** Quarto's own `:::{.columns}` / `.grid` do this with layout attributes and degrade properly on a phone. Keeping `.column-display` as an alias costs three lines; porting the documents costs a search-and-replace. Either is defensible — but keeping both is not.
- **#10 code wrapping.** `pre { word-break: normal; word-wrap: normal }` stops long code lines from breaking mid-token, which is right, and is what pkgdown and tabxplor already do (with a horizontal scroll). `p code { white-space: inherit }` is the opposite bet — it lets *inline* code wrap anywhere, including mid-identifier. Worth confirming that this was deliberate before porting it.
