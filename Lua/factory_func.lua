-- 元表实现
local Cube = {}

Cube.getSideLength = function (self)
  return self.sideLength
end

Cube.getVolume = function (self)
  return math.floor(self.sideLength ^ 3)
end

Cube.setSideLength = function (self, sideLength)
  self.sideLength = sideLength
end

Cube.new = function (sideLength)
  local c = {}
  local meta = { __index = Cube }

  c.sideLength = sideLength
  setmetatable(c, meta)

  return c
end

local c = Cube.new(0)
c:setSideLength(5)
print(c:getSideLength())
print(c:getVolume())

-- 闭包实现
local Square = {}

Square.new = function (sideLength)
  local getSideLenght = function (self)
    return self.sideLength
  end

  local getArea = function (self)
    return math.floor(self.sideLength ^ 2)
  end

  local setSideLength = function (self, sideLength)
    self.sideLength = sideLength
  end
    
  return { sideLength = sideLength, getSideLength = getSideLenght, getArea = getArea, setSideLength = setSideLength }
end

local s = Square.new(0)
s:setSideLength(5)
print(s:getSideLength())
print(s:getArea())