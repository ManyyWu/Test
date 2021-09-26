utils = {}

local function dump_obj_inner(data, showMetatable, tabIndent, noTable, lastCount, result)
  if type(data) ~= "table" then
    if type(data) == "string" then
      table.insert(result, "\"" .. data .. "\"")
    elseif type(data) == "function" then
      ---------bug:������Ϊnil---------
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

---���ذ�����ջ��`level`�㴦���������оֲ������ı�
---
---@param level number ջ����
---@param co    any    ָ��thread��nil��ʾ��ǰthread
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
      local iskeyValid = key ~= "(temporary)" -- ����β���Ż���������ʱ����https://www.codenong.com/18499086/
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

---����Lua�����ַ���
---
---@param data          any     ����
---@param showMetatable boolean �Ƿ����Ԫ��
---@param tabIndent     boolean �Ƿ�ʹ��Tab����
---@param noTable       boolean �Ƿ�ʹ��{}����
---@return string
function utils:dump_obj(data, showMetatable, tabIndent, noTable)
  local result = {}
  dump_obj_inner(data, showMetatable, tabIndent, noTable, 0, result)
  return table.concat(result)
end

---����Lua�����ַ���
---
---@param data          any     ����
---@param showMetatable boolean �Ƿ����Ԫ��
---@param tabIndent     boolean �Ƿ�ʹ��Tab����
---@param noTable       boolean �Ƿ�ʹ��{}����
---@return string
function utils:dump_obj_print(data, showMetatable, tabIndent, noTable)
  print(utils:dump_obj(data, showMetatable, tabIndent, noTable))
end

return utils