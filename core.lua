local line = require "line.c"
local sfind = string.find
local M = {}
local mt = {}


function mt:parser_line(l)
    local cap = line.capture_line(l)
    local  len = #cap
    local  patt = {}
    local map = {}
    for i=1, len, 3 do
        local line_idx = cap[i]
        local token_type = cap[i+1]
        local token = cap[i+2]
        local patt_token
        if token_type == "A" then  -- alpha name
            local entry = map[token]
            if not entry then
                map[token] = {
                    value = token,
                    ttype = token_type,
                    first = i,
                }
                patt_token = {
                    value = token,
                    ttype = token_type,
                    shape = false,
                    any = false,
                    ref = false,
                    prev = false,
                    next = false,
                }
            else
                local first_patt_token = patt[entry.first]
                first_patt_token.any = true
                patt_token = {
                    value = token,
                    shape = token ~= first_patt_token.value,
                    any = true,
                    ref = entry.first,
                    prev = false,
                    next = false,
                }
            end
        else
            patt_token = {
                value = token,
                ttype = token_type,
                prev = false,
                next = false,
            }
        end
        patt_token.line_idx = line_idx
        patt[#patt+1] = patt_token
    end
    return patt
end


function mt:insert_patt(patt)
    local root = self.root
    local parent_token = false
    for i, patt_token in ipairs(patt) do
        local layer = root[i]
        if not layer then
            layer = {
                normal = {},
                anys = {},
            }
            root[i] = layer
        end

        local is_any = patt_token.any
        if is_any then
            table.insert(layer.anys, patt_token)
        else
            table.insert(layer.normal, patt_token)
        end
        if parent_token then
            parent_token.next = patt_token
            patt_token.prev = parent_token
        end
        parent_token = patt_token
    end
end

function mt:insert_line(line)
    local patt = self:parser_line(line)
    self:insert_patt(patt)
end

local function gen_complete_str(complete_patt, final_node)
    local t = {}
    local node = final_node
    while node do
        local value = node.value
        local any = node.any
        local ref = node.ref
        if any then
            assert(ref)
            local cv = complete_patt[ref].value
            t[#t+1] = cv
        else
            t[#t+1] = value
        end
        node = node.next
    end
    return table.concat(t, " ")
end


local function _search(self, complete_patt, layer_idx, result)
    local root = self.root
    local layer = root[layer_idx]
    if not layer then
        return
    end

    local cur_patt = complete_patt[layer_idx]
    local cur_value = cur_patt.value
    local isend_patt = #complete_patt == layer_idx
    local normal = layer.normal
    local anys = layer.anys

    -- find result from normal
    for i,v in ipairs(normal) do
        local value = v.value
        if sfind(value, cur_value) then
            if isend_patt then
                result[#result+1] = gen_complete_str(complete_patt, v)
            else
                _search(self, complete_patt, layer_idx+1, result)
            end
        end
    end

    -- find result from anys
    for i,v in ipairs(anys) do
        if isend_patt then
            result[#result+1] = gen_complete_str(complete_patt, v)
        else
            _search(self, complete_patt, layer_idx+1, result)
        end
    end
end


function mt:search(half_line, complete_idx)
    local  cap = line.capture_line(half_line)
    complete_idx = complete_idx or #cap
    local complete_patt = {}
    local len = #cap
    for i=1, len, 3 do
        local line_idx = cap[i]
        local token_type = cap[i+1]
        local token = cap[i+2]
        local end_idx = #token + line_idx - 1
        -- in token
        if complete_idx >= line_idx and complete_idx < end_idx then
            return false
        end
        if end_idx <= complete_idx then
            complete_patt[#complete_patt+1] = {
                value = token,
                ttype = token_type,
            }
        else
            break
        end
    end

    if #complete_patt == 0 then
        return false
    end

    local result = {}
    _search(self, complete_patt, layer_idx, result)
    return result
end


function M.new_context()
    local raw = {
        root = {},
    }
    return setmetatable(raw, {__index = mt})
end


return M