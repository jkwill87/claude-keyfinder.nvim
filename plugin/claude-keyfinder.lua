if vim.g.loaded_claude_keyfinder then return end
vim.g.loaded_claude_keyfinder = true

vim.api.nvim_create_user_command(
  'ClaudeKeyfinder',
  function(opts) require('claude-keyfinder').ask(opts.args) end,
  { nargs = '*', desc = 'Ask Claude for a keybinding or command' }
)
