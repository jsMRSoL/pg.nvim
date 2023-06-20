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

M.create_layout = function()
  if M.layout_done == true then return end
  -- create insert window
  vim.cmd.tabnew()
  M.windows.insert = vim.api.nvim_get_current_win()
  M.buffers.insert =  vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_buf(M.windows.insert, M.buffers.insert)
  vim.bo.filetype = 'sql'
  vim.api.nvim_buf_set_name(0, "INSERT...")
  vim.api.nvim_buf_set_lines(
    0,
    0,
    -1,
    false,
    { "INSERT INTO lsj_lemmata (headword, suffixed, form)", "VALUES" }
  )

  -- create select window
  vim.cmd.split() -- now we are on the lower window
  M.windows.select = vim.api.nvim_get_current_win()
  M.buffers.select =  vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(M.windows.select, M.buffers.select)
  vim.api.nvim_buf_set_name(0, "SELECT...")
  vim.bo.filetype = 'sql'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "SELECT headword, suffixed, form FROM lsj_lemmata WHERE headword = 'gai=a'",
  })

  vim.api.nvim_set_current_win(M.windows.insert)
  vim.cmd.vsplit()
  M.windows.output = vim.api.nvim_get_current_win()
  M.buffers.output = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(M.windows.output, M.buffers.output)
  vim.api.nvim_buf_set_name(0, "OUTPUT")
  vim.bo.filetype = 'txt'

  vim.api.nvim_set_current_win(M.windows.select)

  M.layout_done = true
end

M.query_database = function()
  local select_buffer = vim.api.nvim_buf_get_lines(M.buffers.select, 0, -1, false)
  local sql_script = vim.fn.join(select_buffer, ' ')
  local postgres_password = os.getenv("LSJ_PG_DATABASE_URL_LOCAL")
  local cmd = "psql -d "
      .. postgres_password
      .. " -c \""
      .. sql_script
      .. "\" --csv -t"

  local on_data = function(_, data, name)
    if name == "stdout" then
      vim.api.nvim_buf_set_lines(M.buffers.output, 0, -1, false, data)
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

return M
