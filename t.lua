local print_r = require "print_r"
local core = require "core"


local source = [[
for i,v in ipairs(table_name) do
    print(i,v)
end

for i,v in ipairs(table_name) do
    print(i,v)
end

local dd = test.group[1].value
local self = test.group[2].value

struct foo {
    unsigned int aa;
    unsigned int bb;
    unsigned int cc;
}

local cc = require "ui.cc"
local bb = require "ui.bb"
local s1 = 1123
local s2 = 1123
local s3 = 1123
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


test_complete("for")
test_complete("local s ")
test_complete("uns")
test_complete("local tt")