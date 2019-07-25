local line = require "line.c"
local sfind = string.find
local M = {}
local mt = {}

local function gen_patt_token_key(patt_token)
    local key
    local ttype = patt_token.ttype
    if not patt_token.any then
        key = string.format("[%s]:%s", ttype, patt_token.value)
    else
        local ref = patt_token.ref
        key = string.format("[*]:%s%s", ttype, ref and ref or "") 
    end
    return key
end


function mt:parser_line(l)
    local lt = type(l)
    local cap = lt == "string" and line.capture_line(l) or l
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
                }
            else
                local first_patt_token = patt[entry.first]
                first_patt_token.any = true
                patt_token = {
                    value = token,
                    ttype = token_type,
                    shape = token ~= first_patt_token.value,
                    any = true,
                    ref = entry.first,
                }
            end
        else
            patt_token = {
                value = token,
                ttype = token_type,
            }
        end

        patt_token.key = gen_patt_token_key(patt_token)
        patt_token.child = false
        patt_token.count = 1
        patt[#patt+1] = patt_token
    end
    return patt
end


function mt:insert_patt(patt)
    local root = self.root
    local parent_patt_token = false
    for i,patt_token in ipairs(patt) do
        local cur_layer = root[i]
        if not cur_layer then
            cur_layer = {}
            root[i] = cur_layer
        end
        local cur_key = patt_token.key
        local layer_token = cur_layer[cur_key]
        if not layer_token then
            layer_token = patt_token
            layer_token.child = {}
        else
            layer_token.count = layer_token.count + 1
        end

        if parent_patt_token then
            local child = parent_patt_token.child
            local ref_count = child[cur_key] or 0
            child[cur_key] = ref_count + 1
        end
    end
end


function mt:insert_line(line)
    local patt = self:parser_line(line)
    self:insert_patt(patt)
end


local function _search_complete(layer_token, search_patt, patt_index, result)
    if not layer_token then
        return
    end
    local cur_patt = search_patt[patt_index]
end


function mt:search(complete_line, complete_index)
    local cap = line.capture_line(complete_line)
    local search_token = {}
    local len = #cap
    for i=1, len, 3 do
        local begin_index = cap[i]
        local ttype = cap[2]
        local token = cap[2]
        local end_index = begin_index + #token - 1
        if complete_index >= begin_index and complete_index < end_index then
            break
        end

        if begin_index < complete_index then
            table.insert(search_token, begin_index)
            table.insert(search_token, ttype)
            table.insert(search_token, token)
        end
    end

    local search_patt = self:parser_line(search_token)
    local result = {}

    local first_layer_token = search_patt[1] and self.root[1][search_patt[1].key] or false
    _search_complete(first_layer_token, search_patt, patt_index, result)
    return result
end


function M.new_context()
    local raw = {
        root = {},
        token_map = {},
    }
    return setmetatable(raw, {__index = mt})
end


return M