function dump_inner(data, showMetatable, tabIndent, noTable, lastCount, result)
  if type(data) ~= "table" then
    if type(data) == "string" then
      table.insert(result, "\"" .. data .. "\"")
    elseif type(data) == "function" then
      local funcInfo = debug.getinfo(data) -- _G中的函数可以是多个变量的值，因此函数名为nil
      setmetatable(funcInfo, { __index = function () return "" end })
      table.insert(result, "function \'" .. funcInfo.name .. "\' <" .. funcInfo.short_src .. ":" .. funcInfo.linedefined .. ">")
    else
      table.insert(result, tostring(data))
    end
  else
    if not lastCount then lastCount = 0 end
    local indent = tabIndent and "\t" or "    "
    local count = lastCount + 1
    if not noTable then
      table.insert(result, "{\n")
    else
      count = count - 1
    end

    if showMetatable then
      for i = 1, count do table.insert(result, indent) end
      local mt = getmetatable(data)
      table.insert(result, "\"__metatable\" = ")
      dump_inner(mt, showMetatable, tabIndent, false, count, result)
      table.insert(result, ",\n")
    end

    for key, value in pairs(data) do
      for i = 1, count do table.insert(result, indent) end
      if type(key) == "string" then
        table.insert(result, "\"" .. key .. "\" = ")
      elseif type(key) == "number" then
        table.insert(result, "[" .. key .. "] = ")
      else
        table.insert(result, tostring(key))
      end
      dump_inner(value, showMetatable, tabIndent, false, count, result)
      table.insert(result, ",\n")
    end

    for i = 1, lastCount or 0 do table.insert(result, indent) end
    if not noTable then
      table.insert(result, "}")
    end
  end

  if not lastCount then
    table.insert(result, "\n")
  end
end

function dump(data, showMetatable, tabIndent, noTable)
  local result = {}
  dump_inner(data, showMetatable, tabIndent, noTable, 0, result)
  return table.concat(result)
end

function dump_print(data, showMetatable, tabIndent, noTable)
  print(dump(data, showMetatable, tabIndent, noTable))
end

function dump_local(level, co)
  local isCo = true
  if type(co) ~= "thread" then
    if level <= 0 then
      error("level out of range")
    end
    isCo = false
    level = level + 1
  end
  local result = {}
  local i = 1
  while true do
    local key, value
    if isCo then
      key, value = debug.getlocal(co, level, i)
    else
      key, value = debug.getlocal(level, i)
    end
    if not key then
      if i < 0 then
        break
      end
      i = -1
    else
      local iskeyValid = key ~= "(temporary)" -- 消除尾调优化产生的临时变量https://www.codenong.com/18499086/
      if i > 0 then
        if iskeyValid then
          result[key] = value
        end
        i = i + 1
      else
        if iskeyValid then
          result["vararg " .. math.abs(i)] = value
        end
        i = i - 1
      end
    end
  end
  return result
end

local function func(arg1, ...)
  local local1 = 1
  local local2 = { a = local1 }

  dump_print(dump_local(1))
  coroutine.yield()
end

local temp =
{
  f = (function ()
    (function ()
      (function ()
        func("hello world!", 1, 2, 3)
      end)()
    end)()
  end)
}
local co = coroutine.create(temp.f)
coroutine.resume(co)

--dump_print(debug.traceback(co))
--dump_print(debug.getinfo(co, 1))
dump_print(dump_local(1, co))
dump_print(dump_local(1), false, false, true)