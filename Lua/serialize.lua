local function serialize(obj)
    local lua = ""
    local t = type(obj)
    if t == "number" then
        lua = lua .. obj
    elseif t == "boolean" then
        lua = lua .. tostring(obj)
    elseif t == "string" then
        lua = lua .. string.format("%q", obj)
    elseif t == "table" then
        lua = lua .. "{"
        for k, v in pairs(obj) do
            lua = lua .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ","
        end
        local metatable = getmetatable(obj)
        if metatable ~= nil and type(metatable.__index) == "table" then
            for k, v in pairs(metatable.__index) do
                lua = lua .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ","
            end
        end
        lua = lua .. "}"
    elseif t == "nil" then
        return "nil"
    --elseif t == "userdata" then
    --    return "userdata"
    --elseif t == "function" then
    --    return "function"
    --elseif t == "thread" then
    --    return "thread"
    else
        error("can not serialize a " .. t .. " type.")
    end
    return lua
end

print(serialize({ a = 1, b = 2, c = {}, __index = {d = 1}, e = "hello world!", f = true,}))