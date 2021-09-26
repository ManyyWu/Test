function print_log(log_lv, ...)
  local arg = { ... }
  local arg_temp = {}

  local debug_info = debug.getinfo(3)
  local _, _, file_name = string.find(debug_info.short_src, ".*/(.+)")
  table.insert(arg_temp, (file_name or "?"))
  table.insert(arg_temp, "[")
  table.insert(arg_temp, (debug_info.currentline or "?"))
  table.insert(arg_temp, "]:")

    for i = 1, #arg do
    table.insert(arg_temp, tostring(arg[i]))
    table.insert(arg_temp, " ")
    end
  print(log_lv .. "|" .. table.concat(arg_temp))
end

function log_info(...)
    print_log("LOG_INFO", ...)
end

function log_err(...)
    print_log("LOG_ERR", ...)
end

function log_fatal(...)
    print_log("LOG_FAT", ...)
end

function log_debug(...)
    print_log("LOG_DEBUG", ...)
end

log_debug("invalid param")