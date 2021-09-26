-- �򵥹�ϣʵ���ļ������ظ�����ֹ��ӡ�����ظ���־���ļ�����ʱֱ�Ӹ���
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