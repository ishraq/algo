-- Neovim Lua plugin: algorithms snippet inserter
-- Located at ~/.config/nvim/lua/custom/plugins/algo.lua
-- Usage: In a C++ file, press <leader>i to fuzzy‑pick a .cpp snippet
-- from /home/ishraq/competitive-programming/lib/algo and insert it.

local M = {}

-- Directory containing the algorithm snippets
local ALGO_DIR = "/home/ishraq/competitive-programming/lib/algo"

-- Helper: read file content into a Lua table of lines
local function read_file(path)
  return vim.fn.readfile(path) or {}
end

-- Main insertion routine
function M.insert()
  if vim.bo.filetype ~= "cpp" then
    vim.notify("algo plugin: not a C++ buffer", vim.log.levels.INFO)
    return
  end

  -- Gather all .cpp files recursively under the algo directory
  local files = vim.fn.globpath(ALGO_DIR, "**/*.cpp", 0, 1)
  if vim.tbl_isempty(files) then
    vim.notify("algo plugin: no .cpp files found in " .. ALGO_DIR, vim.log.levels.WARN)
    return
  end

  -- Use the built‑in UI selector (supports fuzzy search if a picker is
  -- available like telescope/nvim‑ui‑select). The display format is the
  -- relative path to ALGO_DIR for readability.
  local items = {}
  for _, f in ipairs(files) do
    -- strip the prefix to present nicer names
    local rel = string.sub(f, #ALGO_DIR + 2) -- +2 to drop the separating slash
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
    -- Insert the whole content at the cursor position
    vim.api.nvim_buf_set_lines(0, pos[1] - 1, pos[1] - 1, false, content)
  end)
end

-- Create the autocmd directly
vim.api.nvim_create_autocmd("FileType", {
  pattern = "cpp",
  callback = function(args)
    -- buffer‑local key mapping for inserting algorithm snippets
    vim.keymap.set("n", "<leader>i", M.insert, {
      buffer = args.buf,
      desc = "Insert algorithm snippet"
    })
  end
})

-- Expose the module API
return M
