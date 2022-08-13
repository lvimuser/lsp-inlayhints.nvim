---@class SlidingWindowAverage
---@field private __index SlidingWindowAverage
local M = {}

local fill = function(size, value)
  local t = {}
  for i = 1, size do
    t[i] = value
  end

  return t
end

---@type fun(self:table, size:number):SlidingWindowAverage
function M:new(size)
  local n = 0
  local val = 0

  local values = fill(size, 0)
  local index = 1
  local sum = 0

  ---@param value number
  ---@return number
  self.update = function(_self, value)
    local oldValue = values[index]
    values[index] = value
    index = (index + 1) % (size + 1)
    index = index == 0 and 1 or index

    sum = sum - oldValue + value
    if n < size then
      n = n + 1
    end
    val = sum / n

    return val
  end

  ---@return number
  self.value = function()
    return val
  end

  local t = {}
  setmetatable(t, self)
  self.__index = self

  return t
end

return M
