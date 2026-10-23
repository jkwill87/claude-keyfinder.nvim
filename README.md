# claude-keyfinder.nvim

Describe what you want to do in plain English and get back the keybinding or command for it,
picked from your own mappings and commands first and built-in Vim keys second.

It runs a headless [Claude Code](https://docs.claude.com/en/docs/claude-code) query with your
existing login, so there's no API key to manage. The model sees a compact list of your mappings
and user commands, returns references into that list, and the plugin fills in the real keys, so
suggestions match your config exactly.

Choosing a suggestion never runs anything: commands are put on the command line for you to
confirm with Enter, and key-only suggestions are shown as a notification.

## Requirements

- Neovim 0.10 or newer
- Claude Code on `PATH`, logged in (a version that supports `--json-schema`)
- Optional: [snacks.nvim](https://github.com/folke/snacks.nvim) for the results picker; without
  it `vim.ui.select` is used

## Install

With `vim.pack` (Neovim 0.12), or the equivalent in your plugin manager:

```lua
vim.pack.add { 'https://github.com/jkwill87/claude-keyfinder.nvim' }

require('claude-keyfinder').setup()
vim.keymap.set('n', '<Leader>?', function() require('claude-keyfinder').ask() end, { desc = 'Ask Claude' })
```

`:ClaudeKeyfinder` prompts for a question, and `:ClaudeKeyfinder <question>` skips the prompt.

## Options

```lua
require('claude-keyfinder').setup {
  cmd = 'claude', -- Claude Code executable
  model = 'haiku',
  effort = 'low',
  max_suggestions = 3,
  modes = { 'n', 'x', 'o', 'i', 't', 'c' }, -- mapping modes sent as context
  args = {}, -- extra Claude Code flags, e.g. { '--fallback-model', 'sonnet' }
}
```

## Speed

A query typically takes 2 to 4 seconds, most of it Claude Code startup and one Haiku turn. The
plugin replaces Claude Code's default system prompt and disables all tools, which keeps the
prompt to a few thousand tokens instead of about 16k and saves a second or two per query. The
mapping list is sent in a stable order so it can be served from the prompt cache.
