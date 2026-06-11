-- Neovim Lua plugin: algorithms snippet inserter
-- Located at ~/.config/nvim/lua/custom/plugins/algo.lua
-- Usage: In a C++ file, use <leader>a commands for algorithm snippets
--   <leader>ai - Insert an algorithm snippet
--   <leader>ab - Toggle auto-build on save (cycles: debug → optimized → off)
--   <leader>ao - Open build output

-- Ensure overseer is installed
vim.pack.add { 'https://github.com/stevearc/overseer.nvim' }

local M = {}

-- Directory containing the algorithm snippets
local ALGO_DIR = "/home/ishraq/competitive-programming/lib/algo"

-- Helper: read file content into a Lua table of lines
local function read_file(path)
  return vim.fn.readfile(path) or {}
end

-- Helper: get executable name from source file path
local function get_executable_name(filepath)
  return filepath:gsub("%.cpp$", "")
end

-- Helper: run the build
local function run_autobuild(overseer, filepath, exec_name, flags, build_type)
  local cmd = string.format("g++ %s %s -o %s", flags, filepath, exec_name)
  
  local task = overseer.new_task({
    name = "build [" .. build_type .. "]",
    cmd = cmd,
    components = {
      -- { "on_output_quickfix", open_on_exit = "failure" },
      "on_result_diagnostics",
      "default",
    },
  })
  task:start()
end

-- Toggle auto-build with overseer
function M.toggle_autobuild()
  if vim.bo.filetype ~= "cpp" then
    vim.notify("algo plugin: not a C++ buffer", vim.log.levels.INFO)
    return
  end

  local ok, overseer = pcall(require, "overseer")
  if not ok then
    vim.notify("algo plugin: overseer.nvim is not installed", vim.log.levels.ERROR)
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local filepath = vim.fn.expand("%:p")
  local exec_name = get_executable_name(filepath)
  
  -- Cycle through states: off -> debug -> optimized -> off
  local current_state = vim.b.auto_build_state or 0
  local next_state = (current_state + 1) % 3
  
  -- Stop existing auto-build
  if vim.b.auto_build_augroup then
    vim.api.nvim_del_augroup_by_id(vim.b.auto_build_augroup)
    vim.b.auto_build_augroup = nil
  end
  
  if next_state == 0 then
    -- Turn off
    vim.b.auto_build_state = 0
    vim.notify("Auto-build: OFF", vim.log.levels.INFO)
    return
  end
  
  local flags, build_type
  if next_state == 1 then
    -- Debug build
    build_type = "DEBUG"
    flags = "-std=c++23 -O2 -g -Wall -Wextra -pedantic -Wshadow -Wformat=2 " ..
            "-Wfloat-equal -Wconversion -Wlogical-op -Wshift-overflow=2 " ..
            "-Wduplicated-cond -Wcast-qual -Wcast-align -D_GLIBCXX_DEBUG " ..
            "-D_GLIBCXX_DEBUG_PEDANTIC -D_FORTIFY_SOURCE=2 -fsanitize=address " ..
            "-fsanitize=undefined -fno-sanitize-recover -fstack-protector " ..
            "-DDEBUG -I" .. ALGO_DIR .. "/misc/ "
  else
    -- Optimized build
    build_type = "OPTIMIZED"
    flags = "-std=c++23 -O3"
  end
  
  -- Create augroup for auto-build
  local augroup = vim.api.nvim_create_augroup("AutoBuild_" .. buf, { clear = true })
  
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    buffer = buf,
    callback = function()
      run_autobuild(overseer, filepath, exec_name, flags, build_type)
    end,
  })
  
  vim.b.auto_build_state = next_state
  vim.b.auto_build_augroup = augroup
  
  -- Open overseer window if not already open (only when enabling)
  local overseer_open = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local win_buf = vim.api.nvim_win_get_buf(win)
    local buf_name = vim.api.nvim_buf_get_name(win_buf)
    if buf_name:match("overseer") then
      overseer_open = true
      break
    end
  end
  
  if not overseer_open then
    vim.cmd("OverseerOpen")
  end
  
  -- Save the file, which will trigger the build via BufWritePost
  local cpp_win = vim.fn.win_findbuf(buf)[1]
  if cpp_win then
    vim.api.nvim_set_current_win(cpp_win)
  end
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("write")
  end)
  
  vim.notify("Auto-build: " .. build_type, vim.log.levels.INFO)
end

-- Insert algorithm snippet
function M.insert()
  if vim.bo.filetype ~= "cpp" then
    vim.notify("algo plugin: not a C++ buffer", vim.log.levels.INFO)
    return
  end

  local files = vim.fn.globpath(ALGO_DIR, "**/*.cpp", 0, 1)
  if vim.tbl_isempty(files) then
    vim.notify("algo plugin: no .cpp files found in " .. ALGO_DIR, vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, f in ipairs(files) do
    local rel = string.sub(f, #ALGO_DIR + 2)
    table.insert(items, {text = rel, path = f})
  end

  vim.ui.select(items, {
    prompt = "Select algo snippet",
    format_item = function(item)
      return item.text
    end,
  }, function(choice)
    if not choice then return end
    local content = read_file(choice.path)
    if #content == 0 then return end
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_buf_set_lines(0, pos[1] - 1, pos[1] - 1, false, content)
  end)
end

-- Set up keymaps for the <leader>a group
local function setup_keymaps(buf)
  vim.keymap.set("n", "<leader>ai", M.insert, {
    buffer = buf,
    desc = "Insert algorithm snippet"
  })
  
  vim.keymap.set("n", "<leader>ab", M.toggle_autobuild, {
    buffer = buf,
    desc = "Toggle auto-build (debug/optimized/off)"
  })
  
  -- Overseer keymap for viewing build output
  local ok, _ = pcall(require, "overseer")
  if ok then
    vim.keymap.set("n", "<leader>ao", "<cmd>OverseerToggle<cr>", {
      buffer = buf,
      desc = "Open build output"
    })
  end
end

-- Create the autocmd for C++ files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "cpp",
  callback = function(args)
    setup_keymaps(args.buf)
  end
})

-- Expose the module API
return M
