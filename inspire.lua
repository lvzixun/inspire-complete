local platform, lua_dir, lib_dir = ...
assert(platform)
assert(lua_dir)
assert(lib_dir)

local inspirelog_path = false
if platform == "windows" then
	local core_path = lib_dir .. "\\?.dll;"
	local lua_path = lua_dir .. "\\?.lua;"
	package.cpath = core_path .. package.cpath
	package.path = lua_path .. package.path
	inspirelog_path = lua_dir .. "\\inspire_error.log"
elseif platform == "osx" then
	local core_path = lib_dir .. "/?.so;"
	local lua_path = lua_dir .. "/?.lua;"
	package.cpath = core_path .. package.cpath
	package.path = lua_path .. package.path
	inspirelog_path = lua_dir .. "/inspire_error.log"
else
	error("invalid platform:" .. platform)
end

local core = require "core"
local file = require "file"
local stdin_fd = io.stdin
local stdout_fd = io.stdout

local ctx_map = {}

local ins_fd = io.open(inspirelog_path, "w")
assert(ins_fd)
local function _log(t, fmt, ...)
	fmt = string.format("[%s] ", t) .. fmt
	local s = string.format(fmt, ...)
	ins_fd:write(s)
	ins_fd:write("\n")
	ins_fd:flush()
end

local function log_err(fmt, ...)
	return _log("ERR", fmt, ...)
end

local function log_info(fmt, ...)
	return _log("INF", fmt, ...)
end


local function get_ctx_by_filename(filename)
	local suff = file.suffix(filename)
	local ctx = ctx_map[suff]
	if not ctx then
		ctx = core.new_context()
		ctx_map[suff] = ctx
	end
	return ctx
end


local max_files_count = 16
local max_file_size = 256 * 1024
local function load_extra_files(filename)
	local suff = file.suffix(filename)
	local dir = file.basedir(filename)
	if dir then
		local files = file.find_files(dir, suff, max_files_count, max_file_size)
		local ctx = get_ctx_by_filename(filename)
		for i,v in ipairs(files) do
			if not ctx:complete_isloaded(v) then
				local source = file.read_file(v)
				ctx:complete_load(v, source)
				log_info("load_extra: %s", v)
			end
		end
	end
end


--[=[
protocol request:

filename
complete_row complete_column
source_size
source_data....
-------- example --------
test.lua
3 9
110
local cc = require "ui.cc"
local bb = require "ui.bb"
local ss
local s1 = 1123
local s2 = 1123
local s3 = 1123


protocol response:

complete_line_count
complete_1
complete_2
complete_3
...
-------- example --------
4
s = require "ui.s"
s1
s2
s3
]=]

local function read_line()
	local line = stdin_fd:read("l")
	if not line then
		log_err("stdin is break when read_line.")
		os.exit()
	end
	return line
end

local function read_data(sz)
	local data, err = stdin_fd:read(sz)
	if not data then
		log_err("stdin is break when read_data err.")
		os.exit()
	end
	return data
end

local function write_line(fmt, ...)
	local s = string.format(fmt, ...)
	stdout_fd:write(s)
	local ok, err = stdout_fd:write("\n")
	if not ok then
		log_err("stdout is break when write_line err:%s", err)
		os.exit()
	end
end


local function dispatch()
	local filename = read_line()
	local row, col = string.match(read_line(), "(%d+)%s+(%d+)")
	row = assert(tonumber(row))
	col = assert(tonumber(col))
	local source_size = tonumber(read_line())
	assert(source_size)
	local source = read_data(source_size)
	assert(source_size)

	local ctx = get_ctx_by_filename(filename)
	load_extra_files(filename)

	local result = ctx:complete_at(filename, source, row, col)
	if not result then
		write_line("%d", 0)
	else
		write_line("%d", #result)
		for i,v in ipairs(result) do
			write_line("%s", v)
		end
	end
	stdout_fd:flush()
end


local function main()
	log_info("inspire start service:")
	while true do
		local ok, err = xpcall(dispatch, debug.traceback)
		if not ok then
			log_err("%s\n", err)
			write_line("%d", 0)
			stdout_fd:flush()
		end
	end
end

main()