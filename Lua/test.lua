require "utils"

do
  local a = 1
  local b = 2
  local f
  f = function ()
    local info = debug.getinfo(1, "nSflu")
    utils:dump_obj_print(info)
    a, b = a, b
    print(debug.getupvalue(f, 1))
    print(debug.getupvalue(f, 2))
    print(debug.getupvalue(f, 3))
    print(a, b)
    debug.setupvalue(f, 1, 11)
    debug.setupvalue(f, 2, 22)
  end
  f()
  print(a, b)
end