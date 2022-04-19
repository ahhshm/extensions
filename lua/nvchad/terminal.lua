local util = require('nvchad.termutil')
local nvterm = {}
local terminals = {}


local restore_pos = function(to_restore)
  local win = to_restore[1]
  local pos = to_restore[2]
  vim.api.nvim_win_call(win, function()
    vim.api.nvim_win_set_cursor(win, pos)
  end)
end
local stabilize_position_start= function()
  local win = vim.api.nvim_get_current_win()
  local topline = vim.fn.line('w0')
  local cursor_pos = vim.api.nvim_win_get_cursor(win)
  vim.api.nvim_win_call(win, function()
    vim.api.nvim_win_set_cursor(win, {topline, cursor_pos[1]})
  end)
  print(topline)
  print(vim.inspect(cursor_pos))
  return {win, cursor_pos}
end

local function get_last(list)
  if list then return not vim.tbl_isempty(list) and list[#list] or nil end
  return terminals[#terminals] or nil
end

local function get_type(type)
  return vim.tbl_filter(function(t)
    return t.type == type
  end, terminals.list)
end

local function get_still_open()
  return vim.tbl_filter(function(t)
    return t.open == true 
  end, terminals.list)
end

local function get_last_still_open()
  return get_last(get_still_open())
end

local function get_type_last(type)
  return get_last(get_type(type))
end

local create_term_window = function (type)
  if type ~= "float" then
    vim.cmd(util.get_split_cmds(type, terminals))
  else
    vim.api.nvim_open_win(0, true, util.calc_float_opts(terminals.location.float))
  end
  vim.wo.relativenumber = false
  vim.wo.number = false
  return vim.api.nvim_get_current_win()
end

local create_term = function (type)
  local win = create_term_window(type)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'terminal')
  vim.api.nvim_buf_set_option(buf, 'buflisted', false)
  vim.api.nvim_win_set_buf(win, buf)
  local job_id = vim.fn.termopen(vim.o.shell)
  local term = { win = win, buf = buf, open = true, type=type, job_id=job_id}
  table.insert(terminals.list, term)
  vim.cmd('startinsert')
  return term
end

local ensure_and_send = function(cmd, type)
  terminals = util.verify_terminals(terminals)
  local term = type and get_type_last(type) or get_last_still_open() or nvterm.new("vertical")
  if not term then term = nvterm.new("horizontal") end
  vim.api.nvim_chan_send(term.job_id, cmd..'\n')
end

local call_and_restore = function (fn, opts)
  local current_win = vim.api.nvim_get_current_win()
  local mode = vim.api.nvim_get_mode().mode == 'i' and 'startinsert' or 'stopinsert'
  fn(unpack(opts))
  vim.api.nvim_set_current_win(current_win)
  vim.cmd(mode)
end

nvterm.send = function(cmd, type)
  if not cmd then return end
  call_and_restore(ensure_and_send, {cmd, type})
end

nvterm.hide_term = function (term)
  term.open = false
  vim.api.nvim_win_close(term.win, false)
end

nvterm.show_term = function (term)
  term.open = true
  term.win = create_term_window(term.type)
  vim.api.nvim_win_set_buf(term.win, term.buf)
  vim.cmd('startinsert')
end

nvterm.hide = function (type)
  local term = type and get_type_last(type) or get_last()
  nvterm.hide_term(term)
end

nvterm.show = function(type)
  local term = type and get_type_last(type) or terminals.last
  nvterm.show_term(term)
end

nvterm.new = function (type)
  local term = create_term(type)
  return term
end

nvterm.new_or_toggle = function (type)
  terminals = util.verify_terminals(terminals)
  local term = get_type_last(type)
  if not term then term = nvterm.new(type)
  elseif term.open then nvterm.hide_term(term)
  else nvterm.show_term(term) end
end

nvterm.init = function()
  local config = require("core.utils").load_config().options.terminal
  terminals = util.startup(config)
end

return nvterm
