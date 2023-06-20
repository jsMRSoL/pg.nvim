M = {}

M.setup = function ()
  local cmd = vim.api.nvim_create_user_command

  -- cmd('JoinLines', function(opts)
  --   require('txtin.trans').join_lines(opts.line1, opts.line2)
  -- end, { range = true })

  cmd('SqlMode', function()
    require('pg.command').create_layout()
  end, {})
end

return M
