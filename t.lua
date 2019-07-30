local print_r = require "print_r"
local core = require "core"

local source = [[
for i,v in ipairs(table_name) do
    print(i,v)
end

for i,v in ipairs(table_name) do
    print(i,v)
end

local aa = require "ui.aa"
local bb = require "ui.bb"

]]



local ctx = core.new_context()
for line in string.gmatch(source, "[^\r\n]+") do
    ctx:insert_line(line)
end


local root = ctx.root
print_r(root)
print("-------------")


local function test_complete(complete_line)
    local result = ctx:complete_at(complete_line)
    print("---------- complete_line", complete_line)
    if result then
        print_r(result)
    else
        print(result)
    end
    print("---------------------------------------")
end


-- test_complete("f")
test_complete("local")