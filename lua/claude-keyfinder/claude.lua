local M = {}

local function nullable(type) return { type = { type, 'null' } } end

local function schema(max)
  return vim.json.encode {
    type = 'object',
    required = { 'suggestions' },
    additionalProperties = false,
    properties = {
      suggestions = {
        type = 'array',
        maxItems = max,
        items = {
          type = 'object',
          required = { 'title' },
          additionalProperties = false,
          properties = {
            title = { type = 'string' },
            ref = nullable('string'),
            keys = nullable('string'),
            mode = nullable('string'),
            command = nullable('string'),
            note = nullable('string'),
          },
        },
      },
    },
  }
end

local job

local function decode(stdout)
  local ok, res = pcall(vim.json.decode, stdout, { luanil = { object = true, array = true } })
  if not ok or type(res) ~= 'table' then return nil, 'unreadable response from claude' end
  if res.is_error then return nil, res.result or 'claude reported an error' end
  local out = res.structured_output
  if not out and res.result then
    ok, out = pcall(vim.json.decode, res.result, { luanil = { object = true, array = true } })
    if not ok then out = nil end
  end
  if type(out) ~= 'table' or type(out.suggestions) ~= 'table' then
    return nil, 'claude did not return suggestions'
  end
  return out.suggestions
end

--- Runs one headless claude query; a newer call supersedes any still in flight.
---@param on_done fun(err?: string, suggestions?: table[], elapsed: number)
function M.ask(opts, system, prompt, on_done)
  if job then job:kill('sigterm') end

  local args = {
    opts.cmd,
    '--print',
    '--model',
    opts.model,
    '--effort',
    opts.effort,
    '--safe-mode',
    '--restricted',
    '--strict-mcp-config',
    '--no-session-persistence',
    '--tools',
    '',
    '--system-prompt',
    system,
    '--output-format',
    'json',
    '--json-schema',
    schema(opts.max_suggestions),
  }
  vim.list_extend(args, opts.args or {})
  vim.list_extend(args, { '--', prompt })

  local start, this = vim.uv.hrtime(), nil
  local ok, spawn_err = pcall(function()
    this = vim.system(args, { text = true }, function(res)
      vim.schedule(function()
        if job ~= this then return end
        job = nil
        local elapsed = (vim.uv.hrtime() - start) / 1e9
        if res.code ~= 0 and (res.stdout or '') == '' then
          local err = vim.trim(res.stderr or '')
          return on_done(
            err ~= '' and err:sub(-500) or ('claude exited with code ' .. res.code),
            nil,
            elapsed
          )
        end
        local suggestions, err = decode(res.stdout)
        on_done(err, suggestions, elapsed)
      end)
    end)
  end)
  if not ok then return on_done(tostring(spawn_err), nil, 0) end
  job = this
end

return M
