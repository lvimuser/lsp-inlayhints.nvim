local MovingAverage = {}

function MovingAverage:new()
  local t = {}

  setmetatable(t, self)
  self.__index = self

  local n = 1
  local val = 1

  ---@param value number
  ---@return number
  function t.update(value)
    val = val + (value - val) / n
    n = val + 1
    return val
  end

  ---@return number
  function t.value()
    return val
  end

  return t
end

return MovingAverage
