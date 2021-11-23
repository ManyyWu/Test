local socket = require "socket"

local HOST = "192.168.31.6"
local PORT = 20000

local tcp = socket.tcp()

local c, err = tcp:connect(HOST, PORT)
if not c then
  print(err)
  return
end

print("sockname:", tcp:getsockname())
print("peername:", tcp:getpeername())

tcp:send("hello world!")

tcp:close()
