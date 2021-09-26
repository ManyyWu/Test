-- 简单哈希实现文件名不重复，防止打印大量重复日志，文件存在时直接覆盖
function LuaErrorHandler(szError)
  print(string.format("error message: %s",szError))
  local nNum = 0
  for i = 1, #szError do
    nNum = nNum + string.byte(szError, i)
  end
  local szFileName = "panic_" .. nNum .. ".dump"
  local f = io.open(szFileName, "w+")
  if f then
    f:write(string.format("%s\n", os.date("%Y-%m-%d %H:%M:%S")))
    f:write(szError)
    f:close()
  end
end


local _, result = pcall(function ()
  error("invalid param")
end)

LuaErrorHandler(result)