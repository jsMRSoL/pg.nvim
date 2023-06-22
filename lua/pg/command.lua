M = {}

M.layout_done = false

M.windows = {
  select = nil,
  insert = nil,
  output = nil,
}

M.buffers = {
  select = nil,
  insert = nil,
  output = nil,
}

M.reset_buffer = function(bfrkind)
  if bfrkind == "select" then
    vim.api.nvim_buf_set_lines(M.buffers.select, 0, -1, false, {
      "SELECT headword, suffixed, form FROM lsj_lemmata WHERE headword = 'gai=a'",
    })
    return
  end
  if bfrkind == "insert" then
    vim.api.nvim_buf_set_lines(
      M.buffers.insert,
      0,
      -1,
      false,
      { "INSERT INTO lsj_lemmata (headword, suffixed, form)", "VALUES" }
    )
    return
  end
  if bfrkind == "output" then
    vim.api.nvim_buf_set_lines(M.buffers.output, 0, -1, false, { "" })
  end
end

M.set_common_maps = function(bfr)
  vim.keymap.set("n", "<leader>1", function()
    vim.api.nvim_set_current_win(M.windows.insert)
  end, { nowait = true, noremap = true, silent = true, buffer = bfr })
  vim.keymap.set("n", "<leader>2", function()
    vim.api.nvim_set_current_win(M.windows.output)
  end, { nowait = true, noremap = true, silent = true, buffer = bfr })
  vim.keymap.set("n", "<leader>3", function()
    vim.api.nvim_set_current_win(M.windows.select)
  end, { nowait = true, noremap = true, silent = true, buffer = bfr })
  vim.keymap.set("n", "Q", function()
    M.destroy_unload()
  end, { nowait = true, noremap = true, silent = true, buffer = bfr })
end

M.create_layout = function()
  if M.layout_done == true then
    return
  end

  -- create insert window
  vim.cmd.tabnew()
  M.windows.insert = vim.api.nvim_get_current_win()
  M.buffers.insert = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_buf(M.windows.insert, M.buffers.insert)
  vim.bo.filetype = "sql"
  vim.api.nvim_buf_set_name(0, "INSERT...")
  M.reset_buffer("insert")
  -- vim.api.nvim_buf_set_lines(
  --   0,
  --   0,
  --   -1,
  --   false,
  --   { "INSERT INTO lsj_lemmata (headword, suffixed, form)", "VALUES" }
  -- )
  vim.keymap.set(
    "n",
    "<F12>",
    function()
      M.upload_to_database()
    end,
    { nowait = true, noremap = true, silent = true, buffer = M.buffers.insert }
  )

  -- create select window
  vim.cmd.split() -- now we are on the lower window
  M.windows.select = vim.api.nvim_get_current_win()
  M.buffers.select = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_height(M.windows.select, 5)
  vim.api.nvim_win_set_buf(M.windows.select, M.buffers.select)
  vim.api.nvim_buf_set_name(0, "SELECT...")
  vim.bo.filetype = "sql"
  M.reset_buffer('select')
  -- vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  --   "SELECT headword, suffixed, form FROM lsj_lemmata WHERE headword = 'gai=a'",
  -- })
  vim.keymap.set(
    "n",
    "<F12>",
    function()
      M.query_database()
    end,
    { nowait = true, noremap = true, silent = true, buffer = M.buffers.select }
  )

  vim.api.nvim_set_current_win(M.windows.insert)
  -- local win_width = vim.api.nvim_win_get_width(M.windows.insert)
  -- P(0.55 * 159)
  vim.cmd.vsplit()
  M.windows.output = vim.api.nvim_get_current_win()
  M.buffers.output = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(M.windows.output, M.buffers.output)
  vim.api.nvim_buf_set_name(0, "OUTPUT")
  vim.bo.filetype = "txt"
  vim.keymap.set(
    "n",
    "<F12>",
    function()
      M.dress_input()
    end,
    { nowait = true, noremap = true, silent = true, buffer = M.buffers.output }
  )

  vim.api.nvim_set_current_win(M.windows.select)

  for _, bfr in pairs(M.buffers) do
    M.set_common_maps(bfr)
  end

  M.layout_done = true
end

M.destroy_unload = function()
  for _, bfr in pairs(M.buffers) do
    vim.cmd("bdelete! " .. bfr)
  end

  M.layout_done = false
  -- package.loaded["pg"] = nil
end

M.query_database = function()
  local select_buffer =
    vim.api.nvim_buf_get_lines(M.buffers.select, 0, -1, false)
  local sql_script = vim.fn.join(select_buffer, " ")
  local postgres_password = os.getenv("LSJ_PG_DATABASE_URL_LOCAL")
  local cmd = "psql -d "
    .. postgres_password
    .. ' -c "'
    .. sql_script
    .. '" --csv -t'

  local on_data = function(_, data, name)
    if name == "stdout" then
      vim.api.nvim_buf_set_lines(M.buffers.output, 0, -1, true, data)
      M.last_output = data
    end
    if name == "stderr" and data[1] ~= "" then
      vim.notify("stderr: " .. vim.inspect(data))
    end
  end

  vim.fn.jobwait({
    vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      on_stdout = on_data,
      on_stderr = on_data,
    }),
  })
end

M.last_output = {}
M.edited_output = {}
M.dressed_input = {}

M.dress_input = function()
  local edited_output =
    vim.api.nvim_buf_get_lines(M.buffers.output, 0, -2, false)
  -- vim.cmd("norm ggdG")
  M.reset_buffer("output")
  M.edited_output = edited_output
  local dressed_input = {}
  for _, line in ipairs(edited_output) do
    local newline = vim.fn.substitute(line, "\\'", "\\'\\'", 'g')
    newline = vim.fn.substitute(newline, "\\([^,]\\{1,}\\)", "'\\1'", "g")
    newline = "(" .. newline .. "),"
    table.insert(dressed_input, newline)
  end
  local max_idx = #dressed_input
  dressed_input[max_idx] =
    vim.fn.substitute(dressed_input[max_idx], ",$", ";", "")
  M.dressed_input = dressed_input
  vim.api.nvim_buf_set_lines(M.buffers.insert, 3, -1, false, dressed_input)
  vim.api.nvim_set_current_win(M.windows.insert)
end

M.upload_to_database = function()
  vim.cmd.write('/tmp/tmp_sql_file.sql')
  local postgres_password = os.getenv("LSJ_PG_DATABASE_URL_LOCAL")
  local cmd = "psql -d " .. postgres_password .. ' -f /tmp/tmp_sql_file.sql'

  local on_data = function(_, data, name)
    if name == "stdout" then
      vim.notify("stdout: " .. vim.inspect(data))
    end
    if name == "stderr" and data[1] ~= "" then
      vim.notify("stderr: " .. vim.inspect(data))
    end
  end

  vim.fn.jobwait({
    vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      on_stdout = on_data,
      on_stderr = on_data,
      on_exit = function()
        vim.notify("Upload complete!")
        M.reset_buffer("insert")
      end,
    }),
  })
end

return M
