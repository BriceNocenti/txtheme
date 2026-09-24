-- PURPOSE: a cross-reference to another session that reads right in BOTH products built from the
--   same .qmd -- a session rendered alone, and the book that later gathers the sessions.
-- ROLE: hand-written, contributed by the txtheme-html format. A course writes
--     [la pondération]{.renvoi seance=1 ref=sec-ponderation}
--   and gets « la pondération (séance 1) » in a session page, or « la pondération (Section 1.1) »,
--   a live link, in a book whose metadata says `livre: true`.
-- KEY CONSTRAINTS:
--   - a bare `@sec-x` pointing to ANOTHER session cannot be written in a session: rendered alone,
--     Quarto prints « ?@sec-x » and a warning. This span is the one spelling that works both ways.
--   - the citation is inserted as a Cite BEFORE Quarto's own filters run (the default slot of a
--     format filter), so the book's cross-reference pass resolves it like a hand-written `@sec-x`.
--   - `ref` must name an identifier that exists in the target session (`## Titre {#sec-x}`); a
--     missing one only shows up when the book is built.
-- WARNING: `livre` is read from document metadata, so a book declares it once in its _quarto.yml
--   (`metadata: livre: true`). Nothing is guessed from the project type.

local livre = false

local function meta(m)
  if m.livre then livre = true end
end

local function span(el)
  if not el.classes:includes("renvoi") then return nil end
  local seance, ref = el.attributes["seance"], el.attributes["ref"]
  local out = pandoc.List(el.content)

  if livre and ref then
    out:insert(pandoc.Space())
    out:insert(pandoc.Str("("))
    out:insert(pandoc.Cite({ pandoc.Str("@" .. ref) }, { pandoc.Citation(ref, "NormalCitation") }))
    out:insert(pandoc.Str(")"))
  elseif seance then
    out:insert(pandoc.Space())
    out:insert(pandoc.Str("(séance " .. seance .. ")"))
  end
  return out
end

return { { Meta = meta }, { Span = span } }
