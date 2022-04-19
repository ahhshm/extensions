local util = {}


util.calc_float_opts = function(opts)
  return {
    relative = "editor",
    width = math.ceil(opts.width*vim.o.columns),
    height = math.ceil(opts.height*vim.o.lines),
    row = math.floor(opts.row*vim.o.lines),
    col = math.floor(opts.col*vim.o.columns),
    border = opts.border,
  }
end

util.get_split_dims = function(type, winsize)
  local type_switch = type == "horizontal"
  local type_func = type_switch and vim.api.nvim_win_get_height or vim.api.nvim_win_get_width
  return math.floor(type_func(0) * winsize[type])
end

util.get_split_cmds = function(type, terminals)
  local term_cmds = function (dims)
    if type == "horizontal" then
      return { new = terminals.location.horizontal .. dims .. " split" }
    elseif type == "vertical" then
      return { new = terminals.location.vertical .. dims .. " vsplit" }
    end
  end
  local dims = util.get_split_dims(type, terminals.winsize)
  return term_cmds(dims).new
end

local setup_terminals = function(config)
  local terminals = {
    types = {"horizontal", "vertical", "float"},
    list = {},
    winsize = {
      vertical=.5,
      horizontal=.5,
    },
    location = {
      float = {},
      horizontal = "rightbelow",
      vertical = "rightbelow",
    }
  }
  terminals.winsize["horizontal"] = config.window.split_ratio or .5
  terminals.winsize["vertical"] = config.window.vsplit_ratio or .5
  terminals.location = vim.tbl_deep_extend("force", terminals.location, config.location)
  return terminals
end
local set_behavior = function(behavior)
  if behavior.close_on_exit then
    vim.api.nvim_create_autocmd({"TermClose"},{
      callback = function()
        vim.schedule_wrap(vim.api.nvim_input('<CR>'))
      end
    })
    vim.api.nvim_create_autocmd({"BufEnter"}, {
      callback = function() vim.cmd('startinsert') end,
      pattern = 'term://*'
    })
    vim.api.nvim_create_autocmd({"BufLeave"}, {
      callback = function() vim.cmd('stopinsert') end,
      pattern = 'term://*'
    })
  end
end

util.startup = function(config)
  set_behavior(config["behavior"])
  return setup_terminals(config)
end

util.verify_terminals = function (terminals)
  terminals.list = vim.tbl_filter(function(term)
    return vim.api.nvim_buf_is_valid(term.buf)
  end, terminals.list)
  terminals.list = vim.tbl_map(function(term)
    term.open = vim.api.nvim_win_is_valid(term.win)
    return term
  end, terminals.list)
  return terminals
end

return util
