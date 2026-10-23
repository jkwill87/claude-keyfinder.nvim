local M = {}

local function trim(s, max)
  s = s:gsub('%s+', ' ')
  if #s > max then return s:sub(1, max - 1) .. '…' end
  return s
end

local function leader() return vim.fn.keytrans(vim.g.mapleader or '\\') end

local function keys(lhs)
  local lead = leader()
  if lhs:sub(1, #lead) == lead then return '<Leader>' .. lhs:sub(#lead + 1) end
  return lhs
end

local function keep(map)
  if map.lhs:find('<Plug>', 1, true) or map.lhs:find('<SNR>', 1, true) then return false end
  return (map.desc or '') ~= '' or (map.rhs or '') ~= ''
end

-- Returns `<Cmd>Foo<CR>` and `:Foo<CR>` mappings as `Foo`, so the command can be prefilled
local function rhs_command(rhs)
  if not rhs then return nil end
  return rhs:match('^<[Cc][Mm][Dd]>(.-)<[Cc][Rr]>$') or rhs:match('^:(.-)<[Cc][Rr]>$')
end

local function collect(get_maps, get_cmds, modes, prefix, index)
  local lines, maps = {}, {}
  for _, mode in ipairs(modes) do
    for _, map in ipairs(get_maps(mode)) do
      if keep(map) then
        maps[#maps + 1] = {
          kind = 'mapping',
          mode = mode,
          keys = keys(map.lhs),
          desc = (map.desc or '') ~= '' and map.desc or nil,
          command = rhs_command(map.rhs),
          rhs = map.rhs,
        }
      end
    end
  end
  table.sort(maps, function(a, b) return a.mode .. a.keys < b.mode .. b.keys end)

  local cmds = {}
  for name, cmd in pairs(get_cmds()) do
    cmds[#cmds + 1] = { kind = 'command', command = name, desc = cmd.definition }
  end
  table.sort(cmds, function(a, b) return a.command < b.command end)

  for i, map in ipairs(maps) do
    local id = prefix .. 'm' .. i
    index[id] = map
    lines[#lines + 1] =
      table.concat({ id, map.mode, map.keys, trim(map.desc or map.rhs, 80) }, '\t')
  end
  for i, cmd in ipairs(cmds) do
    local id = prefix .. 'c' .. i
    index[id] = cmd
    lines[#lines + 1] = table.concat({ id, cmd.command, trim(cmd.desc or '', 80) }, '\t')
  end
  return table.concat(lines, '\n')
end

--- Global mappings and user commands, in a stable order so the prompt prefix stays cacheable.
---@return string dump, table<string, table> index
function M.global(modes)
  local index = {}
  local dump = collect(
    vim.api.nvim_get_keymap,
    function() return vim.api.nvim_get_commands {} end,
    modes or { 'n', 'x', 'o', 'i', 't', 'c' },
    '',
    index
  )
  return dump, index
end

--- Buffer-local mappings and commands, with ids prefixed `b` so they never collide with global ones.
---@return string dump, table<string, table> index
function M.buffer(buf, modes)
  local index = {}
  local dump = collect(
    function(mode) return vim.api.nvim_buf_get_keymap(buf, mode) end,
    function() return vim.api.nvim_buf_get_commands(buf, {}) end,
    modes or { 'n', 'x', 'o', 'i', 't', 'c' },
    'b',
    index
  )
  return dump, index
end

return M
