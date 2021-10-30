local t =
{
  a = 1,
  b = 2,
  c = 3,
}

local function f ()
  for i, v in pairs(t) do
    print(i, v)
  end
end
f()
