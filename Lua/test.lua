local utils = require "utils"

local function func(arg1, ...)
  local local1 = 1
  local local2 = { a = local1 }

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

utils:dump_obj_print(utils:dump_local(1, co))
utils:dump_obj_print(utils:dump_local(1), false, false, true)