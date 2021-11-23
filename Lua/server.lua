print(package.path)
print(package.cpath)
local socket = require "socket"

local HOST = "0.0.0.0"
local PORT = 20000

local tcp = socket.tcp()

local s, err = tcp:bind(HOST, PORT)
if not s then
  print(err)
  return
end

local ip, port = tcp:getsockname()
print("bind:", ip, port)

assert(tcp:listen(50))
print("listening...")

while true do
  local c, err = tcp:accept()
  if not c then
    print(err)
    break
  end

  local ip, port = c:getpeername()
  print("new connection from:", ip, port)

  local data, err = c:receive("*a")
  if not data then
    print(err)
    c:close()
    break
  end

  print(data)

  c:close()
end

tcp:close()
