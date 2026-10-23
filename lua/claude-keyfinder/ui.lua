local M = {}

--- Prefills the command line with the suggestion's command, or shows its keys; never executes.
function M.apply(item)
  local key = item.keys and table.concat({ item.mode or 'n', item.keys }, '  ')
  if item.command then
    if key then
      vim.notify(key .. '  ' .. item.title, vim.log.levels.INFO, { title = 'Claude Keyfinder' })
    end
    vim.api.nvim_feedkeys(':' .. item.command, 'n', false)
  elseif key then
    vim.notify(key .. '  ' .. item.title, vim.log.levels.INFO, { title = 'Claude Keyfinder' })
  end
end

local function keys(item) return item.keys and ((item.mode or 'n') .. ' ' .. item.keys) or '' end

local function command(item) return item.command and (':' .. item.command) or '' end

local function label(item)
  local parts = { item.title, keys(item), command(item) }
  if item.note then parts[#parts + 1] = '(' .. item.note .. ')' end
  return table.concat(vim.tbl_filter(function(p) return p ~= '' end, parts), '  ')
end

-- Column widths fitted to these items, so short results don't leave the description off-screen
local function columns(items)
  local w = { title = 0, keys = 0, command = 0, note = 0 }
  for _, item in ipairs(items) do
    w.title = math.max(w.title, vim.api.nvim_strwidth(item.title))
    w.keys = math.max(w.keys, vim.api.nvim_strwidth(keys(item)))
    w.command = math.max(w.command, vim.api.nvim_strwidth(command(item)))
    w.note = math.max(w.note, item.note and vim.api.nvim_strwidth(item.note) or 0)
  end
  return w
end

function M.pick(query, items)
  for _, item in ipairs(items) do
    item.text = label(item)
  end

  if not (_G.Snacks and Snacks.picker) then
    return vim.ui.select(items, { prompt = query, format_item = label }, function(item)
      if item then M.apply(item) end
    end)
  end

  local w = columns(items)
  local a = Snacks.picker.util.align
  local width = w.title + w.keys + w.command + w.note + 10

  Snacks.picker.pick {
    source = 'claude_keyfinder',
    title = query,
    items = items,
    preview = 'none',
    format = function(item)
      local ret = {
        { a(item.title, w.title) },
        { '  ' },
        { a(keys(item), w.keys), 'SnacksPickerKeymapLhs' },
        { '  ' },
        { a(command(item), w.command), 'SnacksPickerCmd' },
      }
      if item.note then ret[#ret + 1] = { '  ' .. item.note, 'SnacksPickerComment' } end
      return ret
    end,
    layout = {
      preset = 'select',
      config = function(layout)
        layout.layout.width = math.min(math.max(width, 60), vim.o.columns - 4)
        layout.layout.min_width, layout.layout.max_width = nil, nil
        for _, box in ipairs(layout.layout) do
          if box.win == 'list' then box.height = #items end
        end
      end,
    },
    confirm = function(picker, item)
      picker:close()
      if item then vim.schedule(function() M.apply(item) end) end
    end,
  }
end

return M
