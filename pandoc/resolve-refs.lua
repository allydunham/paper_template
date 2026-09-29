-- Give \ref and \eqref links in the Word output the numbers LaTeX assigned.
-- pandoc does not number equations or know about the supplement, so it would
-- otherwise print [eq:solution] or [S:fig:residuals]. The label numbers are
-- read from the comma-separated .aux files in the `aux` metadata field
-- (-M aux=build/preprint.aux,build/supp-labels.tex).

local labels = {}

local function read_aux(path)
  local f = io.open(path)
  if not f then
    io.stderr:write("resolve-refs: cannot read " .. path .. "\n")
    return
  end
  for line in f:lines() do
    local name, num = line:match("^\\newlabel{([^}]*)}{{([^}]*)}")
    if name then
      labels[name] = num
    end
  end
  f:close()
end

local function load(meta)
  if meta.aux == nil then
    return
  end
  for path in pandoc.utils.stringify(meta.aux):gmatch("[^,]+") do
    read_aux(path)
  end
end

local function resolve(link)
  local num = labels[link.attributes["reference"]]
  if num == nil then
    return nil
  end
  if link.attributes["reference-type"] == "eqref" then
    num = "(" .. num .. ")"
  end
  link.content = { pandoc.Str(num) }
  return link
end

return { { Meta = load }, { Link = resolve } }
