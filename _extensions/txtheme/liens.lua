-- PURPOSE: an external link opens in a new tab, so a student who follows it never loses the page --
--   and, with it, the answers typed into its exercises.
-- ROLE: hand-written, contributed by the txtheme-html format next to renvoi.lua. Every Link whose
--   target starts with http:// or https:// gets `target="_blank"` and `rel="noopener"`; a link
--   inside the page (`#sec-x`), to a local file, or already carrying a `target` is left alone.
-- KEY CONSTRAINTS:
--   - a filter, not Quarto's `link-external-newwindow`: that option is a script which decides
--     "external" by comparing the link's host with the page's, and a course page is opened offline
--     (`file://`, empty host) -- the comparison then calls EVERY link internal and nothing opens in
--     a new tab, without a message. The filter writes the attribute into the HTML itself.
--   - bare `<https://…>` autolinks are Link nodes too, so they are covered.

local function link(el)
  if el.target:match("^https?://") and not el.attributes["target"] then
    el.attributes["target"] = "_blank"
    el.attributes["rel"] = "noopener"
    return el
  end
  return nil
end

return { { Link = link } }
