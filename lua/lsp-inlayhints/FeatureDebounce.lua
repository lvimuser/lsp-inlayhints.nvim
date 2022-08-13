local MovingAverage = require "lsp-inlayhints.MovingAverage"
local SlidingWindowAverage = require "lsp-inlayhints.SlidingWindowAverage"
local config = require "lsp-inlayhints.config"

local M = {}

local function clamp(value, min, max)
  return math.min(math.max(value, min), max)
end

local FeatureDebounce = {}

---@class DebounceInfo
---@field label string
---@field kind integer
---@field position lsp_position
local _debounceInfo = {}
setmetatable(_debounceInfo, {
  __index = function(t, bufnr)
    t[bufnr] = {}
    return t[bufnr]
  end,
})

function FeatureDebounce:new(name, default, min, max)
  ---@type table<string, SlidingWindowAverage>
  local _cache = {}

  local _min = min or 50
  local _max = max or math.pow(min, 2)

  local t = {}

  setmetatable(t, self)
  self.__index = self

  function t.get(bufnr)
    local key = bufnr
    local avg = _cache[key]
    return avg and (clamp(avg:value(), _min, _max)) or t.default()
  end

  local function _overall()
    if #_cache == 0 then
      return
    end

    local result = MovingAverage:new()
    for _, avg in pairs(_cache) do
      result.update(avg:value())
    end
    return result.value()
  end

  function t.default()
    local value = _overall() or default
    return clamp(value, _min, _max)
  end

  function t.update(bufnr, value)
    local key = bufnr
    local avg = _cache[key]
    if not avg then
      avg = SlidingWindowAverage:new(6)
      _cache[key] = avg
    end

    return clamp(avg:update(value), _min, _max)
  end

  return t
end

-- TODO types
---@type table<string, featureDebounce>
---@private
local _data = {}

M.for_ = function(name, _config)
  _config = _config or {}
  local min = _config.min or 50
  local max = _config.max or math.pow(min, 2)

  local function _overallAverage()
    if #_data == 0 then
      return
    end

    local result = MovingAverage:new()
    for _, info in pairs(vim.tbl_values(_data)) do
      result.update(info.default())
    end

    return result.value()
  end

  local info = _data[name]
  if not info then
    info = FeatureDebounce:new(name, _overallAverage() or (min * 1.5), min, max)
    _data[name] = info
  end

  return info
end

M.featureDebounce = FeatureDebounce

return M
