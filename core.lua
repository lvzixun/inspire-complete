local line = require "line.c"
local shape_token = line.shape_token
-- local print_r = require "print_r"
local M = {}
local mt = {}


local function gen_patt_token_key(patt_token)
    local key
    local ttype = patt_token.ttype
    if not patt_token.any then
        if ttype == "S" then
            key = "<S>"
        elseif ttype == "N" then
            key = "<N>"
        else
            key = string.format("<%s:%s>", ttype, patt_token.value)
        end
    else
        local ref = patt_token.ref
        local shape = patt_token.shape
        key = string.format("<*%s:%s:%s>", ttype, ref and ref or "", shape and 's' or 'n')
    end
    return key
end


local function parser_line(self, l)
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
            local is_shape = false
            local entry = map[token]
            if not entry then
                local sp_token = shape_token(token)
                entry = map[sp_token]
                if entry then
                    is_shape = true
                end
            end

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
                patt_token = {
                    value = token,
                    ttype = token_type,
                    shape = is_shape,
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

        patt_token.path = {}
        patt_token.child = false
        patt_token.count = 1
        patt[patt_index] = patt_token
        patt_index = patt_index + 1
    end

    for i, patt_token in ipairs(patt) do
        local k = gen_patt_token_key(patt_token)
        local path = patt_token.path
        patt_token.key = k
        for j=1, i do
            local key = patt[j].key
            path[j] = key
        end
    end
    return patt
end


local function insert_patt(self, patt)
    local function insert_paths(paths, path)
        for i,v in ipairs(path) do
            local c = paths[i]
            local tc = type(c)
            if tc =="table" then
                c[v] = (c[v] or 0) + 1
            elseif tc == "string" then
                if c ~= v then
                    c = {[v]=1, [c]=1}
                else
                    c = {[v] = 2}
                end
            elseif tc == "nil" then
                c = v
            else
                assert(false)
            end
            paths[i] = c
        end
    end

    local root = self.root
    local parent_layer_token = false
    for i,patt_token in ipairs(patt) do
        local cur_layer = root[i]
        if not cur_layer then
            cur_layer = {}
            root[i] = cur_layer
        end
        local ttype = patt_token.ttype
        local cur_key = patt_token.key
        local layer_token = cur_layer[cur_key]
        local path = patt_token.path
        patt_token.path = nil
        if ttype == "A" then
            local tk = self.alpha_tokens[patt_token.value] or 0
            self.alpha_tokens[patt_token.value] = tk + 1
        end
        if not layer_token then
            layer_token = patt_token
            layer_token.paths = {}
            layer_token.child = {}
            cur_layer[cur_key] = layer_token
        else
            layer_token.count = layer_token.count + 1
        end
        insert_paths(layer_token.paths, path)

        if parent_layer_token then
            local child = parent_layer_token.child
            local ref_count = child[cur_key] or 0
            ref_count = patt_token.any and (ref_count-1) or (ref_count+1)
            child[cur_key] = ref_count  -- negative number is any token
        end
        parent_layer_token = layer_token
    end
end


local function delete_patt(self, patt, del_count)
    local function delete_paths(paths, path, del_count)
        assert(#paths == #path)
        for i, v in ipairs(path) do
            local c = paths[i]
            local tc = type(c)
            if tc == "table" then
                c[v] = c[v] - del_count
                assert(c[v]>=0)
            elseif tc == "string" then
                paths[i] = false
            else
                error("invalid path type:" .. tc)
            end
        end
    end

    local root = self.root
    local parent_layer_token = false
    for i,patt_token in ipairs(patt) do
        local cur_layer = root[i]
        local key = patt_token.key
        local patt_value = patt_token.value
        local layer_token = cur_layer[key]
        layer_token.count = layer_token.count - del_count
        if patt_token.ttype == "A" then
            local tk = self.alpha_tokens[patt_value]
            assert(tk)
            tk = tk - 1
            if tk <= 0 then
                self.alpha_tokens[patt_token] = nil
            end
        end

        delete_paths(layer_token.paths, patt_token.path, del_count)
        if layer_token.count == 0 then
            cur_layer[key] = nil
        end
        if parent_layer_token then
            local ref_count = parent_layer_token.child[key]
            if ref_count < 0 then
                ref_count = ref_count + del_count
                assert(ref_count <= 0)
            elseif ref_count > 0 then
                ref_count = ref_count - del_count
                assert(ref_count >= 0)    
            else
                assert(false)
            end
            parent_layer_token.child[key] = ref_count ~= 0 and ref_count or nil
        end
        parent_layer_token = layer_token
    end
end


local function insert_line(self, line)
    if string.match(line, "^%s*$") then
        return
    end

    local patt = parser_line(self, line)
    insert_patt(self, patt)
end


local function delete_line(self, line, del_count)
    if string.match(line, "^%s*$") then
        return
    end

    local patt = parser_line(self, line)
    delete_patt(self, patt, del_count)
end


local function _substr(s, sub_s)
    return not not string.find(s, sub_s, 1, true)
end


local function _search_layer_by_value(self, cur_layer_index, search_token)
    local cur_layer = self.root[cur_layer_index]
    if not cur_layer then
        return
    end

    local result = {}
    for k, layer_token in pairs(cur_layer) do
        local search_value = search_token.value
        if layer_token.ttype == search_token.ttype and _substr(layer_token.value, search_value) then
            result[#result+1] = layer_token
        end
    end
    return result
end


local function check_path(p1, p2, c)
    c = c or 1
    if #p2 >= #p1 then
        for i,v in ipairs(p1) do
            if v ~= "*" then
                local v2 = p2[i]
                local tv2 = type(v2)
                local c2 = tv2 == "table" and v2[v] or 1
                if tv2 == "table" and not v2[v] then
                    return false
                end
                if tv2 == "string" and v2 ~= v then
                    return false
                end
                if c2 < c then
                    return false
                end
            end
        end
        return true
    end
    return false
end


local function gen_complete(self, cur_layer_index, layer_token, search_token_list, root_layer_path, result, match_score)
    local function _gen_cpl_str(self, root_layer_path, cur_layer_index, layer_token, search_token_list, buf, result, match_score)
        local is_any = layer_token.any
        local ttype = layer_token.ttype
        local child = layer_token.child
        local shape = layer_token.shape
        local new_value
        if not is_any then
            new_value = layer_token.value
        else
            local ref = layer_token.ref or cur_layer_index
            local ref_token = search_token_list[ref]
            if not ref_token then
                if #buf > 0 then
                    result[#result+1] = {table.concat(buf), match_score}
                end
                return
            end
            new_value = ref_token.value
            if shape then
                new_value = shape_token(new_value)
            end
        end
        local last_search_token = search_token_list[#search_token_list]
        local last_ttype = last_search_token.ttype
        local last_value = last_search_token.value
        local buf_index = #buf+1
        if buf_index == 1 and last_ttype ~= "A" and last_value == new_value then
            buf[buf_index] = nil
        else
            buf[buf_index] = new_value
        end
        local is_final = true
        local cur_root_layer_path_index = #root_layer_path+1
        for k, ref_count in pairs(child) do
            local next_layer_token = self.root[cur_layer_index+1][k]
            local correct_path = check_path(root_layer_path, next_layer_token.paths, 2)
            if correct_path and (ref_count <= -2 or ref_count >= 2) then
                is_final = false
                root_layer_path[cur_root_layer_path_index] = next_layer_token.key
                _gen_cpl_str(self, root_layer_path, cur_layer_index+1, next_layer_token, search_token_list, buf, result, match_score)
                root_layer_path[cur_root_layer_path_index] = nil
            end
        end
        if is_final and #buf>0 then
            result[#result+1] = {table.concat(buf), match_score}
        end
        -- assert(#buf == buf_index)
        buf[buf_index] = nil
    end
    _gen_cpl_str(self, root_layer_path, cur_layer_index, layer_token, search_token_list, {}, result, match_score)
end


local MATCH_SCORE = {
    full = 6,
    sub = 5,
    last = 4,
    any = 2,
    type = 1,
}
local function _complete(self, cur_layer_index, layer_token, search_token_list, search_token_index, root_layer_path, result, match_score)
    local cur_root_layer_path_index = #root_layer_path+1
    root_layer_path[cur_root_layer_path_index] = layer_token.key
    local next_layer = self.root[cur_layer_index+1]
    if not next_layer or not layer_token then
        root_layer_path[cur_root_layer_path_index] = nil
        return
    end

    -- print("_complete!!!!! layer_token", layer_token.key, layer_token.value)
    -- is final match
    local cur_search_token = search_token_list[search_token_index]
    if not cur_search_token then
        -- print("gen_complete!!!!", layer_token.value, layer_token.key)
        gen_complete(self, cur_layer_index, layer_token, search_token_list, root_layer_path, result, match_score)
        root_layer_path[cur_root_layer_path_index] = nil
        return
    end

    local search_token_key = cur_search_token.key
    local is_last_search_token = #search_token_list == search_token_index
    local full_match_list = {}
    local last_match_list = {}
    local any_match_list = {}
    local ttype_match_list = {}
    local ttype_match_map = {}
    local need_type_match = true
    for k, ref_count in pairs(layer_token.child) do
        local next_layer_token = next_layer[k]
        -- full match
        if search_token_key == k then
            need_type_match = false
            full_match_list[#full_match_list+1] = next_layer_token

        -- last match
        elseif is_last_search_token and  _substr(next_layer_token.value, cur_search_token.value) then
            need_type_match = false
            result[#result+1] = {next_layer_token.value, match_score+MATCH_SCORE.sub}
            last_match_list[#last_match_list+1] = next_layer_token
        
        -- any match
        elseif ref_count <= -2 and check_path(root_layer_path, next_layer_token.paths, 2) then
            -- need_type_match = false
            any_match_list[#any_match_list+1] = next_layer_token

        -- type match
        elseif cur_search_token.ttype == next_layer_token.ttype then
            ttype_match_list[#ttype_match_list+1] = next_layer_token
        end
    end

    local function do_ttype_match_list()
        for i,next_layer_token in ipairs(ttype_match_list) do
            local next_layer2 = self.root[cur_layer_index+2]
            local next_child = next_layer_token.child
            root_layer_path[cur_root_layer_path_index+1] = "*"
            for k,v in pairs(next_child) do
                local next_layer_token2 = next_layer2[k]
                if next_layer_token2.count >= 2 and check_path(root_layer_path, next_layer_token2.paths, 2) then
                    ttype_match_map[k] = next_layer_token2
                end
            end
            root_layer_path[cur_root_layer_path_index+1] = nil
        end
    end

    local function _complete_list(match_list, offset, score)
        offset = offset or 1
        match_score = match_score + score
        for _, next_layer_token in pairs(match_list) do
            _complete(self, cur_layer_index+offset, next_layer_token, 
                search_token_list, search_token_index+offset, 
                root_layer_path, result, match_score)
        end
        match_score = match_score - score
    end

    _complete_list(full_match_list, 1, MATCH_SCORE.full)
    _complete_list(last_match_list, 1, MATCH_SCORE.last)
    _complete_list(any_match_list, 1, MATCH_SCORE.any)

    if need_type_match then
        do_ttype_match_list()
        root_layer_path[cur_root_layer_path_index+1] = "*"
        _complete_list(ttype_match_map, 2, MATCH_SCORE.type)
        root_layer_path[cur_root_layer_path_index+1] = nil
    end

    root_layer_path[cur_root_layer_path_index] = nil
end


local function parser_complete_line(complete_line, complete_col)
    complete_col = complete_col or #complete_line
    local cap = line.capture_line(complete_line)
    local search_token_list = {}
    local len = #cap
    local prefix = ""
    for i=1, len, 3 do
        local begin_index = cap[i]
        local ttype = cap[i+1]
        local token = cap[i+2]
        local end_index = begin_index + #token - 1
        if complete_col >= begin_index and complete_col < end_index then
            break
        end

        if end_index <= complete_col then
            local search_token = {
                value = token,
                ttype = ttype,
            }
            local k = gen_patt_token_key(search_token, prefix)
            search_token.key = k
            prefix = k
            search_token_list[#search_token_list+1] = search_token
        end
    end

    if #search_token_list <= 0 then
        return
    end
    return search_token_list
end


local function complete_at(self, search_token_list)
    local first_layer_tokens = _search_layer_by_value(self, 1, search_token_list[1])
    if not first_layer_tokens then
        return
    end

    table.sort(first_layer_tokens, function (a, b) return a.count > b.count end)
    local result = {}
    for i, layer_token in ipairs(first_layer_tokens) do
        _complete(self, 1, layer_token, search_token_list, 2, {}, result, MATCH_SCORE.full)
    end
    -- print("#### result ####")
    -- print_r(result)
    table.sort(result, function (a, b)
        local l1 = #a[1]
        local s1 = a[2]
        local l2 = #b[1]
        local s2 = b[2]
        return s1 > s2 or 
               s1 == s2 and l1 > l2
    end)

    local ret_map = {}
    local ret = {}
    for i,v in ipairs(result) do
        local value = v[1]
        if not ret_map[value] then
            ret[#ret+1] = value
            ret_map[value] = true
        end
    end
    return ret
end


local function resolve_diff(self, source, complete_row)
    local lines_map = self.lines_map
    local new_lines = {}
    local new_lines_map = {}
    local row = 1
    local complete_line = false
    for line in string.gmatch(source, "([^\r\n]*)[\r\n]?") do
        local v = line
        if complete_row == row then
            complete_line = v
            v = ""
        end
        new_lines[row] = v
        row = row + 1
        new_lines_map[v] = (new_lines_map[v] or 0)+1
    end

    local modify_count = 0
    local add_lines_map = {}
    local del_lines_map = {}
    for k,v in pairs(new_lines_map) do
        local ov = lines_map[k]
        if not ov then
            modify_count = modify_count+1
            add_lines_map[k] = v
        elseif ov > v then
            modify_count = modify_count+1
            del_lines_map[k] = ov-v
        elseif ov < v then
            modify_count = modify_count+1
            add_lines_map[k] = v-ov
        end
        lines_map[k] = nil
    end
    for k,v in pairs(lines_map) do
        assert(del_lines_map[k] == nil)
        modify_count = modify_count+1
        del_lines_map[k] = v
    end

    local total_count = #self.file_lines
    self.lines_map = new_lines_map
    self.file_lines = new_lines
    -- full source insert when modify_count beyond 30%
    if modify_count >= total_count * 0.3 then
        self.root = {}
        self.alpha_tokens = {}
        for i,v in ipairs(new_lines) do
            insert_line(self, v)
        end
    else
        for k,v in pairs(del_lines_map) do
            delete_line(self, k, v)
        end
        for k,v in pairs(add_lines_map) do
            for i=1,v do
                insert_line(self, k)
            end
        end
    end
    return complete_line
end

local function complete_tokens(self, last_patt_token)
    local patt =  parser_line(self, complete_line)
    local list = {}
    if last_patt_token.ttype == "A" then
        local patt_value = last_patt_token.value
        for k,v in pairs(self.alpha_tokens) do
            if _substr(k, patt_value) then
                table.insert(list, k)
            end
        end
    end
    return list
end

local function complete_up(self, search_token_list, begin_row, max_complete_count)
    local up_ctx = M.new_context()
    local c = 0
    local idx = 0
    while true do
        if c >= max_complete_count then
            break
        end
        
        idx = idx + 1
        local l = self.file_lines[begin_row-idx]
        if not l then
            break
        end
        if not string.match(l, "^%s*$") then
            c = c + 1
            insert_line(up_ctx, l)
        end
    end

    local result = complete_at(up_ctx, search_token_list)
    return result
end


local max_complete_count = 8
function mt:complete_at(source, complete_row, complete_col)
    assert(source)
    assert(complete_row)
    local complete_line = resolve_diff(self, source, complete_row)
    assert(complete_line)
    local result_map = {}
    complete_col = complete_col or #complete_line

    local result = {}
    local result_map = {}
    local function merge_into_result(t)
        if not t then
            return
        end
        for i,v in ipairs(t) do
            if not result_map[v] then
                result[#result+1] = v
                result_map[v] = true
            end
        end
    end

    local search_token_list = parser_complete_line(complete_line, complete_col)
    if search_token_list and #search_token_list<= 8 then
        local up2_result = complete_up(self, search_token_list, complete_row, 2)
        local up8_result = complete_up(self, search_token_list, complete_row, 8)
        local up32_result = complete_up(self, search_token_list, complete_row, 32)
        local total_result = complete_at(self, search_token_list)
        merge_into_result(up2_result)
        merge_into_result(up8_result)
        merge_into_result(up32_result)
        merge_into_result(total_result)

        if max_complete_count and #result > max_complete_count then
            local len = #result
            for i=max_complete_count+1, len do
                result[i] = nil
            end
        end
    end

    local alpha_result = complete_tokens(self, search_token_list[#search_token_list])
    merge_into_result(alpha_result)
    return result
end


function M.new_context(source)
    local raw = {
        root = {},
        file_lines = {},
        lines_map = {},
        alpha_tokens = {},
    }
    local obj = setmetatable(raw, {__index = mt})
    if source then
        resolve_diff(obj, source)
    end
    return obj
end


return M