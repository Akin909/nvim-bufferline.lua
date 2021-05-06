local M = {}

local api = vim.api
local fn = vim.fn

local t = {
  LEAF = "leaf",
  ROW = "row",
}

local s = {
  LEFT = 0,
  RIGHT = 1,
  NONE = 2,
}

---Format the content of a neighbouring panel text
---@param size number
---@param highlight string
---@param text string
---@return string
local function get_panel_text(size, highlight, text)
  if not text then
    text = string.rep(" ", size)
  else
    local text_size = fn.strwidth(text)
    -- 2 here is for padding on either side of the text
    if text_size > size then
      text = " " .. text:sub(1, text_size - size - 2) .. " "
    elseif text_size < size then
      local pad_size = math.floor((size - text_size) / 2)
      local pad = string.rep(" ", pad_size)
      text = pad .. text .. pad
    end
  end
  return highlight .. text
end

---A heuristic to attempt to derive a windows background color from a winhighlight
---@param win_id number
---@param attribute string
---@param match string
---@return string|nil
local function guess_window_highlight(win_id, attribute, match)
  assert(win_id, 'A window id must be passed to "guess_window_highlight"')
  attribute = attribute or "bg"
  match = match or "Normal"
  local hl = vim.wo[win_id].winhighlight
  if not hl then
    return
  end
  local parts = vim.split(hl, ",")
  for _, part in ipairs(parts) do
    local grp, hl_name = unpack(vim.split(part, ":"))
    if grp and grp:match(match) then
      return hl_name
    end
  end
  return match
end

--- Test if the windows within a layout row contain the correct panel buffer
--- NOTE: this only tests the first and last windows as those are the only
--- ones that it makes sense to add a panel for
---@param windows table[]
---@param panel table
---@return boolean
---@return number
---@return number
local function is_panel(windows, panel)
  for idx, window in ipairs({ windows[1], windows[#windows] }) do
    local _type, win_id = window[1], window[2]
    if _type == t.LEAF and type(win_id) == "number" then
      local buf = api.nvim_win_get_buf(win_id)
      local valid = buf and vim.bo[buf].filetype == panel.filetype
      local side = idx == 0 and s.LEFT or s.RIGHT
      return valid, win_id, side
    end
  end
  return false, nil, s.NONE
end

---Calculate the size of padding required to offset the bufferline
---@param prefs table
---@return string
---@return number
---@return string
function M.get(prefs)
  local panels = prefs.options.panels

  local component = ""
  local size = 0
  local side = s.NONE

  if panels and #panels > 0 then
    local panel = panels[1]
    local layout = fn.winlayout()
    -- don't bother proceeding if there are no vertical splits
    if layout[1] == t.ROW then
      local is_valid, win_id, pan_side = is_panel(layout[2], panel)
      if is_valid then
        local win_width = api.nvim_win_get_width(win_id)
        local sign_width = vim.wo[win_id].signcolumn and 1 or 0

        local hl_name = panel.highlight
          or guess_window_highlight(win_id)
          or prefs.highlights.fill.hl

        local hl = require("bufferline.highlights").hl(hl_name)

        side = pan_side
        size = win_width + sign_width

        component = get_panel_text(size, hl, panel.text)
      end
    end
  end
  return component, size, side
end

return M