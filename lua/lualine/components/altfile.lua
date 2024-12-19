-- Copyright (c) 2020-2021 shadmansaleh
-- MIT license, see LICENSE for more details.
local M = require('lualine.component'):extend()

local modules = require('lualine_require').lazy_require {
  highlight = 'lualine.highlight',
  utils = 'lualine.utils.utils',
}

local default_options = {
  symbols = {
    separator = '^',
    modified = '[+]',
    readonly = '[-]',
    unnamed = '[No Name]',
    newfile = '[New]',
  },
  file_status = true,
  newfile_status = false,
  path = 0,
  shorting_target = 40,
  use_mode_colors = false,
  altfile_color = nil,
}

local function is_new_file(buf)
  local bufnr = buf or 0
  local filename = vim.api.nvim_buf_get_name(bufnr)
  return filename ~= '' and vim.bo[bufnr].buftype == '' and vim.fn.filereadable(filename) == 0
end

---shortens path by turning apple/orange -> a/orange
---@param path string
---@param sep string path separator
---@param max_len integer maximum length of the full filename string
---@return string
local function shorten_path(path, sep, max_len)
  local len = #path
  if len <= max_len then
    return path
  end

  local segments = vim.split(path, sep)
  for idx = 1, #segments - 1 do
    if len <= max_len then
      break
    end

    local segment = segments[idx]
    local shortened = segment:sub(1, vim.startswith(segment, '.') and 2 or 1)
    segments[idx] = shortened
    len = len - (#segment - #shortened)
  end

  return table.concat(segments, sep)
end

local function filename_and_parent(path, sep)
  local segments = vim.split(path, sep)
  if #segments == 0 then
    return path
  elseif #segments == 1 then
    return segments[#segments]
  else
    return table.concat({ segments[#segments - 1], segments[#segments] }, sep)
  end
end

-- This function is duplicated in tabs
---returns the proper hl for buffer in section. Used for setting default highlights
---@param section string name of section buffers component is in
---@return string hl name
local function get_hl(section)
  local section_redirects = {
    lualine_x = 'lualine_c',
    lualine_y = 'lualine_b',
    lualine_z = 'lualine_a',
  }
  if section_redirects[section] then
    section = modules.highlight.highlight_exists(section .. '_inactive') and section or section_redirects[section]
  end
  return section .. '_inactive'
end

M.init = function(self, options)
  M.super.init(self, options)
  default_options.altfile_color = options.use_mode_colors
    and function() return get_hl('lualine_' .. options.self.section) end
    or get_hl('lualine_' .. options.self.section)
  self.options = vim.tbl_deep_extend('keep', self.options or {}, default_options)
  if self.options.component_name == 'altfile' then
    self.highlight = self:create_hl(self.options.altfile_color)
  end
end

M.update_status = function(self)
  local bufnr = vim.fn.bufnr('#')
  if bufnr == -1 then return end

  local path_separator = package.config:sub(1, 1)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local data
  if self.options.path == 1 then
    -- relative path
    data = vim.fn.fnamemodify(filename, ':~:.')
  elseif self.options.path == 2 then
    -- absolute path
    data = vim.fn.fnamemodify(filename, ':p')
  elseif self.options.path == 3 then
    -- absolute path, with tilde
    data = vim.fn.fnamemodify(filename, ':p:~')
  elseif self.options.path == 4 then
    -- filename and immediate parent
    data = filename_and_parent(vim.fn.fnamemodify(filename, ':p:~'), path_separator)
  else
    -- just filename
    data = vim.fn.fnamemodify(filename, ':t')
  end

  if data == '' then
    data = self.options.symbols.unnamed
  end

  if self.options.shorting_target ~= 0 then
    local windwidth = self.options.globalstatus and vim.go.columns or vim.fn.winwidth(0)
    local estimated_space_available = windwidth - self.options.shorting_target

    data = shorten_path(data, path_separator, estimated_space_available)
  end

  data = modules.utils.stl_escape(data)

  local symbols = {}
  if self.options.file_status then
    if vim.bo[bufnr].modified then
      table.insert(symbols, self.options.symbols.modified)
    end
    if vim.bo[bufnr].modifiable == false or vim.bo[bufnr].readonly == true then
      table.insert(symbols, self.options.symbols.readonly)
    end
  end

  if self.options.newfile_status and is_new_file(bufnr) then
    table.insert(symbols, self.options.symbols.newfile)
  end

  local line = data .. (#symbols > 0 and (' ' .. table.concat(symbols, '')) or '')
  local separator = self.options.symbols.separator
  if separator then
    local s = self.highlight.section
    if s == 'a' or s == 'b' or s == 'c' then
      line = separator .. ' ' .. line
    else
      line = line .. ' ' .. separator
    end
  end
  line = modules.highlight.component_format_highlight(self.highlight) .. line

  return line
end

return M