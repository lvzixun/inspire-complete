local lfs = require "lfs"

local M = {}

function M.suffix(s)
    local basename = string.match(s, "[^/\\]+$")
    local suf = string.match(basename, "[^%.]*$")
    return suf
end

function M.basedir(s)
    local d =  string.match(s, "(.-)[/\\]?[^/\\]*$")
    if d == "" then
        return false
    end
    return d
end


function M.read_file(path)
    local fd = io.open(path, "r")
    local s = fd:read("a")
    fd:close()
    return s
end


local function join(...)
    local t = {...}
    local sep = string.match (package.config, "[^\n]+")
    return table.concat(t, sep)
end


function M.find_files(dir, type, max_count, max_size)
    local out = {}
    local fmt = ".+%." .. type .. "$"
    local function _f(cur_dir, max_count, out)
        local next_dirs = {}
        for file in lfs.dir(cur_dir) do
            if file ~= "." and file ~= ".." then
                local f = join(cur_dir, file)
                local attr = lfs.attributes(f)
                if attr.mode == "directory" then
                    next_dirs[#next_dirs+1] = f
                elseif string.match(file, fmt) then
                    if not max_size or attr.size <= max_size then
                        out[#out+1] = f
                        if #out >= max_count then
                            return true
                        end
                    end
                end
            end
        end
        for i, d in ipairs(next_dirs) do
            local ok = _f(d, max_count, out)
            if ok then
                return
            end
        end
        return false
    end
    _f(dir, max_count, out)
    return out
end


return M

