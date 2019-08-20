local mt = {}

local function new_node(k)
    local node = {
        key = k,
        ref = 0,
        child = false,
        value = false,
    }
    return node
end

local function new()
    local raw = {
        root = new_node('.Root'),
    }
    return setmetatable(raw, {__index = mt})
end


local function get_node(parent, key)
    local child = parent.child
    if not child then
        child = {}
        parent.child = child
    end
    local v = child[key]
    if not v then
        v = new_node(key)
        child[key] = v
    end
    return v
end


function mt:insert(str)
    local parent = self.root
    for _, c in utf8.codes(str) do
        local v = get_node(parent, c)
        v.ref = v.ref + 1
        parent = v
    end
    assert(parent.value == false)
    parent.value = str
end


local function is_empty(t)
    return not not next(t)
end

function mt:delete(str)
    local parent = self.root
    for _, c in utf8.codes(str) do
        local child = parent.child
        local node = child and child[c]
        if not node then
            return
        end
        local ref = node.ref - 1
        node.ref = ref
        assert(ref >= 0)
        if ref <= 0 then
            child[c] = nil
        end
        parent = node
    end
end


function mt:search(prefix)
    local parent = self.root
    for _, c in utf8.codes(prefix) do
        local child = parent.child
        local node = child and child[c]
        if not node then
            return
        end
        parent = node
    end


    local function dump_token(node, out)
        local value = node.value
        if value then
            out[#out+1] = value
        end
        local child = node.child
        if child then
            for k,v in pairs(child) do
                dump_token(v, out)
            end
        end
    end

    local out = {}
    dump_token(parent, out)
    return out
end


return new

