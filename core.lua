local line = require "line.c"
local print_r = require "print_r"
local M = {}
local mt = {}

local function gen_patt_token_key(patt_token)
    local key
    local ttype = patt_token.ttype
    if not patt_token.any then
        key = string.format("<%s>:%s", ttype, patt_token.value)
    else
        local ref = patt_token.ref
        key = string.format("<*>:%s%s", ttype, ref and ref or "")
    end
    return key
end


function mt:parser_line(l)
    local cap = line.capture_line(l)
    local  len = #cap
    local  patt = {}
    local map = {}
    local patt_index = 1
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
                    first = patt_index,
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
                first_patt_token.key = gen_patt_token_key(first_patt_token)
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
        patt[patt_index] = patt_token
        patt_index = patt_index + 1
    end
    return patt
end


function mt:insert_patt(patt)
    local root = self.root
    local parent_layer_token = false
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
            cur_layer[cur_key] = layer_token
        else
            layer_token.count = layer_token.count + 1
        end

        if parent_layer_token then
            local child = parent_layer_token.child
            local ref_count = child[cur_key] or 0
            ref_count = patt_token.any and (ref_count-1) or (ref_count+1)
            child[cur_key] = ref_count  -- negative number is any token
        end
        parent_layer_token = layer_token
    end
end


function mt:insert_line(line)
    local patt = self:parser_line(line)
    -- print("insert_line", line)
    -- print_r(patt)
    self:insert_patt(patt)
end

local function _substr(s, sub_s)
    return not not string.find(s, sub_s, 1, true)
end


local function _search_layer_by_value(self, cur_layer_index, search_token)
    local cur_layer = self.root[cur_layer_index]
    if cur_layer then
        return
    end

    local result = {}
    for k, layer_token in pairs(cur_layer) do
        local search_value = search_token.value
        if layer_token.ttype == search_token.ttype and _substr(layer_token.value, search_value) then
            result[#result] = layer_token
        end
    end
    return result
end


local function gen_complete(self, cur_layer_index, layer_token, search_token_list, result)
    local function _gen_cpl_str(self, cur_layer_index, layer_token, search_token_list, buf)
        local is_any = layer_token.any
        local ttype = layer_token.ttype
        local child = layer_token.child
        local has_child = not not next(child)
        local new_value
        if not is_any then
            new_value = layer_token.value
        else
            local ref = layer_token.ref or #search_token_list
            new_value = search_token_list[ref].value
        end
        buf[#buf+1] = new_value
        for k, ref_count in pairs(child) do
            local next_layer_token = self.root[cur_layer_index][k]
            if ref_count <= -2 or ref_count >= 2 then
                _gen_cpl_str(self, cur_layer_index+1, next_layer_token, search_token_list, buf)
            end
        end
        return table.concat(buf), buf[1]
    end
    local longest, shortest = _gen_cpl_str(self, cur_layer_index, layer_token, search_token_list, {})
    result[#result+1] = longest
    if longest ~= shortest then
        result[#result+1] = shortest
    end
end


local function _complete(self, cur_layer_index, layer_token, search_token_list, search_token_index, result)
    local next_layer = self.root[cur_layer_index+1]
    if not next_layer or not layer_token then
        return
    end

    -- is final match
    local cur_search_token = search_token_list[search_token_index]
    if not cur_search_token then
        gen_complete(layer_token, search_token_list, result)
        return
    end

    local search_token_key = cur_search_token.key
    local is_last_search_token = #search_token_list == search_token_index
    for k, ref_count in pairs(layer_token.child) do
        local next_layer_token = next_layer[k]
        -- full match
        if search_token_key == k then
            _complete(self, cur_layer_index+1, next_layer_token, search_token_list, search_token_index+1, result)

        -- last match
        elseif ref_count > 0 and is_last_search_token and  _substr(next_layer_token.value, cur_search_token.value) then
            _complete(self, cur_layer_index+1, next_layer_token, search_token_list, search_token_index+1, result)
        
        -- any match
        elseif ref_count <= -3 then
            _complete(self, cur_layer_index+1, next_layer_token, search_token_list, search_token_index+1, result)     
        end
    end
end


function mt:search(complete_line, complete_index)
    local cap = line.capture_line(complete_line)
    local search_token_list = {}
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
            local search_token = {
                value = token,
                ttype = ttype,
            }
            search_token.key = gen_patt_token_key(search_token)
            search_token_list[#search_token_list+1] = search_token
        end
    end

    if #search_token_list <= 0 then
        return
    end

    local first_layer_tokens = _search_layer_by_value(self, 1, search_token_list[1])
    if not first_layer_tokens then
        return
    end

    table.sort(first_layer_tokens, function (a, b) return a.count > b.count end)
    local result = {}
    for i, layer_token in ipairs(first_layer_tokens) do
        _complete(layer_token, search_token_list, 2, result)
    end
    return result
end


function M.new_context()
    local raw = {
        root = {},
    }
    return setmetatable(raw, {__index = mt})
end


return M