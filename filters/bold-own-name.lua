-- Bold "Longworth, <initials>" in the rendered bibliography (div#refs),
-- so the CV owner's name stands out in multi-author reference lists.
-- Runs after citeproc has expanded the bibliography into plain Inlines.

local function is_initial(s)
  return s:match("^%u%.?,?$") ~= nil
end

local function bold_longworth(inlines)
  local result = pandoc.List({})
  local i = 1
  local n = #inlines
  while i <= n do
    local el = inlines[i]
    if el.t == "Str" and (el.text == "Longworth," or el.text == "Longworth") then
      local run = pandoc.List({ el })
      local j = i + 1
      if el.text == "Longworth" and inlines[j] and inlines[j].t == "Str" and inlines[j].text == "," then
        run:insert(inlines[j])
        j = j + 1
      end
      while inlines[j] and inlines[j].t == "Space" and inlines[j + 1]
          and inlines[j + 1].t == "Str" and is_initial(inlines[j + 1].text) do
        run:insert(inlines[j])
        run:insert(inlines[j + 1])
        j = j + 2
      end
      result:insert(pandoc.Strong(run))
      i = j
    else
      result:insert(el)
      i = i + 1
    end
  end
  return result
end

function Div(div)
  if div.identifier == "refs" then
    return pandoc.walk_block(div, { Inlines = bold_longworth })
  end
end
