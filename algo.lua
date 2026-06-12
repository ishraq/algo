-- Neovim Lua plugin: algorithm snippet inserter + makefile build/run
-- Located at ~/.config/nvim/lua/custom/plugins/algo.lua
-- Usage in a C++ file:
--   <leader>ai   - Insert an algorithm snippet
--   <leader>am   - Copy makefile from algo directory to current buffer's dir
--   <leader>ab   - Build current file (auto-copies makefile if missing)
--   <leader>at   - Build and run 'oj t -c <executable>' (auto-copies makefile)

local M = {}

-- Directory containing the algorithm snippets and the master makefile
local ALGO_DIR = "/home/ishraq/competitive-programming/lib/algo"
local MAKEFILE_SRC = ALGO_DIR .. "/makefile"

-- fidget.nvim progress module (required)
local has_fidget, fidget_progress = pcall(require, "fidget.progress")
if not has_fidget then
  error("algo plugin: fidget.nvim is required but not installed. Please add 'j-hui/fidget.nvim' to your plugins.")
end

-- Helper: run a command and show output nicely, with fidget progress
-- - success: brief notification
-- - failure: popup window with full output
-- - if always_show true: always popup (useful for test results)
-- cmd: string or table (e.g., {"make", "target"})
-- cwd: directory to run in
-- opts: optional { title = "Display title", always_show = false, show_spinner = true }
-- callback: optional function(success, output) called after command finishes
local function run_cmd_with_output(cmd, cwd, opts, callback)
  opts = opts or {}
  local cmd_str = type(cmd) == "table" and table.concat(cmd, " ") or cmd
  local title = opts.title or cmd_str
  local show_spinner = (opts.show_spinner ~= false)

  local fidget_handle = nil
  if show_spinner then
    fidget_handle = fidget_progress.handle.create({
      title = title,
      message = cmd_str,
      lsp_client = { name = "algo" },
      percentage = 0,
    })
  end

  vim.system(cmd, { cwd = cwd, text = true }, function(obj)
    if fidget_handle then
      vim.schedule(function() fidget_handle:finish() end)
    end

    local output = obj.stdout .. obj.stderr
    local success = (obj.code == 0)

    vim.schedule(function()
      if success and not opts.always_show then
        vim.notify("✓ " .. title .. " succeeded", vim.log.levels.INFO)
      else
        -- Create a scratch buffer with the output
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output, "\n"))

        local width = math.min(120, vim.o.columns - 10)
        local height = math.min(20, vim.api.nvim_buf_line_count(buf))
        local win = vim.api.nvim_open_win(buf, true, {
          relative = 'editor',
          width = width,
          height = height,
          row = 1,
          col = (vim.o.columns - width) / 2,
          border = 'rounded',
          title = (success and "✓ " or "✗ ") .. title,
          title_pos = 'center',
        })

        vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<CR>', { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(buf, 'n', '<esc>', '<cmd>close<CR>', { noremap = true, silent = true })
      end

      if callback then
        callback(success, output)
      end
    end)
  end)
end

-- Helper: read file content into a Lua table of lines
local function read_file(path)
  return vim.fn.readfile(path) or {}
end

-- Helper: write a table of lines to a file
local function write_file(path, lines)
  return vim.fn.writefile(lines, path) == 0
end

-- Helper: get the directory of the current buffer
local function get_current_dir()
  return vim.fn.expand("%:p:h")
end

-- Helper: get the basename (without extension) of the current file
local function get_basename()
  return vim.fn.expand("%:t:r")
end

-- Helper: copy the master makefile to a destination directory
local function copy_makefile_to(dest_dir)
  local dest_file = dest_dir .. "/makefile"
  local src_lines = read_file(MAKEFILE_SRC)
  if #src_lines == 0 then
    vim.schedule(function()
      vim.notify("algo plugin: source makefile not found at " .. MAKEFILE_SRC, vim.log.levels.ERROR)
    end)
    return false
  end
  if write_file(dest_file, src_lines) then
    vim.schedule(function()
      vim.notify("Makefile copied to " .. dest_dir, vim.log.levels.INFO)
    end)
    return true
  else
    vim.schedule(function()
      vim.notify("Failed to write makefile to " .. dest_dir, vim.log.levels.ERROR)
    end)
    return false
  end
end

-- Helper: ensure a makefile exists in the given directory
local function ensure_makefile(dir)
  local makefile_path = dir .. "/makefile"
  if vim.fn.filereadable(makefile_path) == 1 then
    return true
  end
  vim.schedule(function()
    vim.notify("Makefile missing, copying one now...", vim.log.levels.INFO)
  end)
  return copy_makefile_to(dir)
end

-- Insert algorithm snippet
function M.insert()
  if vim.bo.filetype ~= "cpp" then
    vim.schedule(function()
      vim.notify("algo plugin: not a C++ buffer", vim.log.levels.INFO)
    end)
    return
  end

  local files = vim.fn.globpath(ALGO_DIR, "**/*.cpp", 0, 1)
  if vim.tbl_isempty(files) then
    vim.schedule(function()
      vim.notify("algo plugin: no .cpp files found in " .. ALGO_DIR, vim.log.levels.WARN)
    end)
    return
  end

  local items = {}
  for _, f in ipairs(files) do
    local rel = string.sub(f, #ALGO_DIR + 2)
    table.insert(items, { text = rel, path = f })
  end

  vim.ui.select(items, {
    prompt = "Select algo snippet",
    format_item = function(item) return item.text end,
  }, function(choice)
    if not choice then return end
    local content = read_file(choice.path)
    if #content == 0 then return end
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_buf_set_lines(0, pos[1] - 1, pos[1] - 1, false, content)
  end)
end

-- Copy master makefile to current buffer's directory (manual command)
function M.copy_makefile()
  if vim.bo.filetype ~= "cpp" then
    vim.schedule(function()
      vim.notify("algo plugin: not a C++ buffer", vim.log.levels.INFO)
    end)
    return
  end
  copy_makefile_to(get_current_dir())
end

-- Build current file using the makefile in its directory
function M.build()
  if vim.bo.filetype ~= "cpp" then
    vim.schedule(function()
      vim.notify("algo plugin: not a C++ buffer", vim.log.levels.INFO)
    end)
    return
  end

  if vim.bo.modified then
    vim.cmd.write()
  end

  local dir = get_current_dir()
  local target = get_basename()

  if not ensure_makefile(dir) then
    return
  end

  run_cmd_with_output({ "make", target }, dir, { title = "make " .. target, show_spinner = true })
end

-- Build and then run 'oj t -c <executable>' in the buffer's directory
function M.test()
  if vim.bo.filetype ~= "cpp" then
    vim.schedule(function()
      vim.notify("algo plugin: not a C++ buffer", vim.log.levels.INFO)
    end)
    return
  end

  if vim.bo.modified then
    vim.cmd.write()
  end

  local dir = get_current_dir()
  local target = get_basename()
  local exec_path = dir .. "/" .. target

  if not ensure_makefile(dir) then
    return
  end

  run_cmd_with_output({ "make", target }, dir, { title = "make " .. target, show_spinner = true }, function(success)
    if not success then
      return
    end
    run_cmd_with_output({ "oj", "t", "-c", exec_path }, dir, { title = "oj t", always_show = true, show_spinner = true })
  end)
end

-- Set up keymaps for the <leader>a group
local function setup_keymaps(buf)
  vim.keymap.set("n", "<leader>ai", M.insert, { buffer = buf, desc = "Insert algorithm snippet" })
  vim.keymap.set("n", "<leader>am", M.copy_makefile, { buffer = buf, desc = "Copy makefile to this directory" })
  vim.keymap.set("n", "<leader>ab", M.build, { buffer = buf, desc = "Build current file with make" })
  vim.keymap.set("n", "<leader>at", M.test, { buffer = buf, desc = "Build and run oj t" })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "cpp",
  callback = function(args)
    setup_keymaps(args.buf)
  end,
})

return M
