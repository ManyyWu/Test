utils = {}

local function dump_obj_inner(data, showMetatable, tabIndent, noTable, lastCount, result)
  if type(data) ~= "table" then
    if type(data) == "string" then
      table.insert(result, "\"" .. data .. "\"")
    elseif type(data) == "function" then
      ---------bug:函数名为nil---------
      local funcInfo = debug.getinfo(data)
      setmetatable(funcInfo, { __index = function () return "" end })
      --------------------------------
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
      table.insert(result, indent:rep(count))
      local mt = getmetatable(data)
      table.insert(result, "\"__metatable\" = ")
      dump_obj_inner(mt, showMetatable, tabIndent, false, count, result)
      table.insert(result, ",\n")
    end

    for key, value in pairs(data) do
      table.insert(result, indent:rep(count))
      if type(key) == "string" then
        table.insert(result, "\"" .. key .. "\" = ")
      elseif type(key) == "number" then
        table.insert(result, "[" .. key .. "] = ")
      else
        table.insert(result, tostring(key))
      end
      dump_obj_inner(value, showMetatable, tabIndent, false, count, result)
      table.insert(result, ",\n")
    end

    table.insert(result, indent:rep(lastCount or 0))
    if not noTable then
      table.insert(result, "}")
    end
  end

  if not lastCount then
    table.insert(result, "\n")
  end
end

---返回包含在栈的`level`层处函数的所有局部变量的表
---
---@param level number 栈级别
---@param co    any    指定thread，nil表示当前thread
---@return table
function utils:dump_local(level, co)
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

---导出Lua对象到字符串
---
---@param data          any     对象
---@param showMetatable boolean 是否包括元表
---@param tabIndent     boolean 是否使用Tab缩进
---@param noTable       boolean 是否使用{}包含
---@return string
function utils:dump_obj(data, showMetatable, tabIndent, noTable)
  local result = {}
  dump_obj_inner(data, showMetatable, tabIndent, noTable, 0, result)
  return table.concat(result)
end

---导出Lua对象到字符串
---
---@param data          any     对象
---@param showMetatable boolean 是否包括元表
---@param tabIndent     boolean 是否使用Tab缩进
---@param noTable       boolean 是否使用{}包含
---@return string
function utils:dump_obj_print(data, showMetatable, tabIndent, noTable)
  print(utils:dump_obj(data, showMetatable, tabIndent, noTable))
end

return utils