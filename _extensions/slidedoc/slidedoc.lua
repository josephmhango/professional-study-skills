-- slidedoc.lua
-- Turn each H2 section into a <section class="slide" ...>
-- Ensure left/right columns exist and move a last code block to the right if needed.

local utils = require 'pandoc.utils'

-- Split a list of blocks into (all-but-last-code, last-code) if a CodeBlock exists
local function split_last_code(blocks)
  local last_idx = nil
  for i = #blocks, 1, -1 do
    if blocks[i].t == "CodeBlock" then
      last_idx = i
      break
    end
  end
  if not last_idx then return blocks, nil end
  local left = {}
  for i = 1, #blocks do
    if i ~= last_idx then table.insert(left, blocks[i]) end
  end
  return left, blocks[last_idx]
end

-- Wrap blocks in a Div with a class
local function wrap_div(class, contents)
  return pandoc.Div(pandoc.Blocks(contents), pandoc.Attr("", {class}, {}))
end

function Header(el)
  -- Only act on level-2 headers; mark the section class so Pandoc assigns Div around it
  if el.level == 2 then
    -- Append class 'slide' and carry data-title from header text
    local classes = {"slide"}
    if el.attributes and el.attributes["class"] then
      table.insert(classes, el.attributes["class"])
    end
    local attrs = el.attributes or {}
    attrs["data-title"] = attrs["data-title"] or pandoc.utils.stringify(el.content)
    el.attributes = attrs
    el.classes = classes
  end
  return el
end

function Div(div)
  -- Pandoc wraps H2 sections into Divs with class 'section' (or none). We detect our 'slide' class.
  if not div.classes:includes("slide") then
    return nil
  end

  -- Check if author already provided .left/.right child divs
  local has_left, has_right = false, false
  for _, b in ipairs(div.content) do
    if b.t == "Div" and b.classes:includes("left") then has_left = true end
    if b.t == "Div" and b.classes:includes("right") then has_right = true end
  end

  if has_left and has_right then
    return div -- nothing to do
  end

  -- Otherwise, construct left/right
  local blocks = div.content

  -- If there is a codeblock anywhere and no explicit right, move the last codeblock to right
  local left_blocks, right_code = split_last_code(blocks)
  local left = wrap_div("left", has_left and {} or left_blocks)
  local right

  if has_right then
    -- keep existing right; ensure left exists
    local new_children = pandoc.List:new()
    local inserted_left = false
    for _, b in ipairs(div.content) do
      if b.t == "Div" and b.classes:includes("left") then
        inserted_left = true
        new_children:insert(b)
      elseif b.t == "Div" and b.classes:includes("right") then
        new_children:insert(b)
      end
    end
    if not inserted_left then new_children:insert(1, left) end
    div.content = new_children
    return div
  else
    if right_code ~= nil then
      right = wrap_div("right", { right_code })
    else
      right = wrap_div("right", {}) -- template JS will inject image if empty and data-img exists
    end
    div.content = pandoc.List:new({ left, right })
    return div
  end
end
