local M = {}

---@class claude-keyfinder.Config
M.config = {
  cmd = 'claude',
  model = 'haiku',
  effort = 'low',
  max_suggestions = 3,
  modes = { 'n', 'x', 'o', 'i', 't', 'c' },
  args = {},
}

local INSTRUCTIONS = [[
You help a Neovim user find the keybinding or command that does what they describe.

Their mappings and user commands are listed below, one per line, tab separated:
- mapping lines: id, mode, keys, description (or the mapping's rhs)
- command lines: id, command name, definition
Buffer-local entries, if any, arrive with the request and have ids starting with "b".

Return up to %d suggestions, best first.
- If a listed entry does what was asked, set ref to its id and leave keys, mode and command null.
- Otherwise suggest built-in Vim or Neovim keys and Ex commands: set keys in Vim notation (for
  example <C-w>o) with mode, and/or command without the leading colon, and leave ref null.
- title: a few words saying what it does. note: only for a caveat, under 15 words.
- Never invent mappings or plugin commands that are not listed or built in.
- Return an empty list if nothing fits.

]]

local function resolve(suggestions, index)
  local by_command = {}
  for _, entry in pairs(index) do
    if entry.kind == 'mapping' and entry.command and entry.mode == 'n' then
      by_command[entry.command] = by_command[entry.command] or entry
    end
  end

  local items, seen = {}, {}
  for _, s in ipairs(suggestions) do
    local entry = s.ref and index[s.ref]
    if entry then
      s.keys, s.mode = entry.keys, entry.mode
      s.command = entry.command or s.command
    end
    local mapped = not s.keys and s.command and by_command[s.command]
    if mapped then
      s.keys, s.mode = mapped.keys, mapped.mode
    end
    local key = table.concat({ s.mode or '', s.keys or '', s.command or '' }, '\0')
    if (s.keys or s.command) and not seen[key] then
      seen[key] = true
      items[#items + 1] = s
    end
  end
  return items
end

local function run(query, buf)
  local cfg = M.config
  local global, index = require('claude-keyfinder.context').global(cfg.modes)
  local local_dump, local_index = require('claude-keyfinder.context').buffer(buf, cfg.modes)
  index = vim.tbl_extend('force', index, local_index)

  local system = INSTRUCTIONS:format(cfg.max_suggestions) .. global
  local sections =
    { 'Filetype: ' .. (vim.bo[buf].filetype ~= '' and vim.bo[buf].filetype or 'none') }
  if local_dump ~= '' then sections[#sections + 1] = 'Buffer-local entries:\n' .. local_dump end
  sections[#sections + 1] = 'Request: ' .. query
  local prompt = table.concat(sections, '\n\n')

  local notify = { id = 'claude-keyfinder', title = 'Claude Keyfinder' }
  vim.notify(
    'Asking Claude…',
    vim.log.levels.INFO,
    vim.tbl_extend('force', notify, { timeout = false })
  )

  require('claude-keyfinder.claude').ask(cfg, system, prompt, function(err, suggestions, elapsed)
    if err then return vim.notify(err, vim.log.levels.ERROR, notify) end
    local items = resolve(suggestions, index)
    local msg = ('%d suggestion%s in %.1fs'):format(#items, #items == 1 and '' or 's', elapsed)
    vim.notify(msg, #items == 0 and vim.log.levels.WARN or vim.log.levels.INFO, notify)
    if #items > 0 then require('claude-keyfinder.ui').pick(query, items) end
  end)
end

---@param opts? claude-keyfinder.Config
function M.setup(opts) M.config = vim.tbl_extend('force', M.config, opts or {}) end

--- Asks Claude how to do `query` in Neovim, prompting for it when omitted.
---@param query? string
function M.ask(query)
  local buf = vim.api.nvim_get_current_buf()
  if query and query ~= '' then return run(query, buf) end
  vim.ui.input({ prompt = 'Ask Claude' }, function(input)
    if input and vim.trim(input) ~= '' then run(input, buf) end
  end)
end

return M
