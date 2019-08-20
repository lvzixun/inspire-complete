local print_r = require "print_r"
local core = require "core"

local function read_file(path)
    local fd = io.open(path, "r")
    local s = fd:read("a")
    fd:close()
    return s
end

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
local TestComplete = require "ui.test_complete"
local BoxWidget = require "ui.box_widget"

local s1 = 1123
local s2 = 1123
local s3 = 1123
local patt = self:parser_line(line)

local function gen_patt_token_key(patt_token)
local function complete_at(self, complete_line, complete_index)
local function complete_at(self, complete_line, complete_index)
result = complete_at(self, complete_line, complete_index)
]]

-- source = read_file("core.lua")

local ctx = core.new_context(source)

local root = ctx.root
print_r(root)
print("-------------")


local function insert_source(source, line, row)
	local lines = {}
	for l in string.gmatch(source, "[^\r\n]*") do
		lines[#lines+1] = l
	end
	row = row or #lines+1
	table.insert(lines, row, line)
	return table.concat(lines, "\n"), row
end

local function test_complete(complete_line, row, col)
	local source, row = insert_source(source, complete_line, row)
    col = col or #complete_line
    local result = ctx:complete_at("test", source, row, col)
    print("---------- complete_line:", complete_line)
    if result then
        print_r(result)
    else
        print(result)
    end
    print("\n")
end


test_complete("for")
test_complete("local s")
test_complete("uns")
test_complete("local func")
test_complete("local kiss")
test_complete("local ss", 23)

