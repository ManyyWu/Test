-- ��������̨��������������
local dbgd = {
  cmdlist = {},   -- ��ִ�е������б�
  info = {},      -- ��ǰ�ĵ�����Ϣ
  opt = {},       -- ѡ��
}
-- ����ӿڣ���һ��ȫ�ֱ������������ĺ�����ɲ���
dbg = {
}
-- ѹ������
function dbgd.pushcmd(cmd, ...)
  dbgd.cmdlist[#dbgd.cmdlist+1] = {cmd, table.unpack{...}}
end
-- ִ������
function dbgd.execcmd()
  local cmdlist = dbgd.cmdlist
  dbgd.cmdlist = {}
  for _, cmdinfo in ipairs(cmdlist) do
    local cmd = cmdinfo[1]
    if dbgd[cmd] then
      dbgd[cmd](table.unpack(cmdinfo, 2))
    else
      print(string.format("error - unknown cmd: %s", cmd))
    end
  end
end
-- ȡ������
function getname(n)
  if n.what == "C" then
    return n.name
  end
  local lc = string.format("%s:%d", n.short_src, n.currentline)
  if n.what ~= "main" and n.namewhat ~= "" then
    return string.format("%s (%s)", lc, n.name)
  else
    return lc
  end
end
-- ���溯���ĸ�����Ϣ
function dbgd.capinfo()
  local level = 4
  local finfo = debug.getinfo(level, "nSlf")
  local info = {}
  -- function info
  info.name = getname(finfo)
  info.func = finfo.func
  -- upvalues
  info.uv = {}
  local i = 1
  while true do
    local name, value = debug.getupvalue(finfo.func, i)
    if name == nil then break end
    if string.sub(name, 1, 1) ~= "(" then
      table.insert(info.uv, {name, value, i})
    end
    i = i + 1
  end
  -- local values
  info.lv = {}
  i = 1
  while true do
    local name, value = debug.getlocal(level, i)
    if not name then break end
    if string.sub(name, 1, 1) ~= "(" then
      table.insert(info.lv, {name, value, i})
    end
    i = i + 1
  end
  -- vararg arguments
  info.av = {}
  i = -1
  while true do
    local name, value = debug.getlocal(level, i)
    if not name then break end
    if string.sub(name, 1, 1) ~= "(" then
      table.insert(info.av, {name, value, i})
    end
    i = i -1
  end
  dbgd.info = info
end
-- ���뽻������
local function interactive()
  dbgd.resume()
  print(debug.traceback(nil, 3))
  dbgd.capinfo()
  debug.debug()
  dbgd.execcmd()
end
--- ������Hook�ص�
function dbgd.hook(evt, arg)
  if evt == 'call' then
    interactive()
  elseif evt == "line" then
    if dbgd.opt.type == "line" then
      if dbgd.opt.line == arg then
        interactive()
      end
    elseif dbgd.opt.type == "stepin" then
      interactive()
    elseif dbgd.opt.type == "stepover" then
      if debug.getinfo(2, "f").func == dbgd.info.func then
        interactive()
      end
    end
  end
end
--- ��ĳ�м�һ���ϵ�
function dbgd.breakpoint(line)
  dbgd.opt.type = "line"
  dbgd.opt.line = line
  debug.sethook(dbgd.hook, "l")
end
-- ��������
function dbgd.stepin()
  dbgd.opt.type = "stepin"
  debug.sethook(dbgd.hook, "l")
end
-- ��������
function dbgd.stepover()
  dbgd.opt.type = "stepover"
  debug.sethook(dbgd.hook, "l")
end
-- ����upvalue
function dbgd.setupvalue(n, v)
  debug.setupvalue(dbgd.info.func, n, v)
end
-- ���ñ��ر���
function dbgd.setlocalvalue(n, v)
  debug.setlocal (5, n, v)
end
--- ɾ��Hook������ִ��
function dbgd.resume()
  debug.sethook()
end

---------------------------------------------------------
-- ���������ӿ�
-- ����
function dbg.h()
  print("dbg.h()\t\t\tprint help")        -- ����
  print("dbg.bp(line)\t\tadd a breakpoint to a line")     -- �ڵڼ��жϵ�
  print("dbg.si()\t\tstep into next function call")       -- ����ִ��
  print("dbg.so()\t\tstep over next function call")       -- ����ִ��(��������)

  print("dbg.all()\t\tprint all debug info")      -- ��ӡ���е���Ϣ
  print("dbg.name()\t\tprint function name")     -- ��ӡ������Ϣ
  print("dbg.uv()\t\tprint up values")            -- ��ӡupvalue
  print("dbg.lv()\t\tprint local values")         -- ��ӡ�ֲ�����(��������)
  print("dbg.av()\t\tprint vararg arguments")       -- ��ӡ�ɱ����

  print("dbg.setuv(n, v)\t\tchange a upvalue")    -- ����upvalue��n�Ǳ��������
  print("dbg.setlv(n, v)\t\tchange a local value")  -- ���þֲ�������n�Ǳ��������
end
local function print_vars(msg, vars)
  print(msg)
  if vars then
    for _, v in ipairs(vars) do
      print("", v[3], v[1], v[2])
    end
  end
end
function dbg.name()
  print("name: ")
  print(string.format("    %s", dbgd.info.name))
end
function dbg.uv()
  print_vars("up values: ", dbgd.info.uv)
end
function dbg.lv()
  print_vars("local values: ", dbgd.info.lv)
end
function dbg.av()
  print_vars("vararg argument: ", dbgd.info.av)
end
function dbg.all()
  dbg.name()
  dbg.uv()
  dbg.lv()
  dbg.av()
end
function dbg.bp(ln)
  dbgd.pushcmd("breakpoint", ln)
end
function dbg.si()
  dbgd.pushcmd("stepin")
end
function dbg.so()
  dbgd.pushcmd("stepover")
end
function dbg.setuv(n, v)
  dbgd.pushcmd("setupvalue", n, v)
end
function dbg.setlv(n, v)
  dbgd.pushcmd("setlocalvalue", n, v)
end
local function run(luacode)
  local chunk = loadfile(luacode)
  debug.sethook(dbgd.hook, "c")
  chunk()
  debug.sethook()
end
run(select(1, ...))
