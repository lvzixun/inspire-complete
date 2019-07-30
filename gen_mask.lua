
local mask_map = {}
local function set_mask(b, e, t)
    if t == nil then
        b = string.byte(b)
        mask_map[b] = e
    else
        b = string.byte(b)
        e = string.byte(e)
        for i=b, e do
            mask_map[i] = t
        end
    end
end

-- char
set_mask('A', 'Z', "A")
set_mask('a', 'z', "A")
set_mask('_', 'A')
set_mask('0', '9', "N")
set_mask('+', 'F')
set_mask('-', 'F')
set_mask('*', 'F')
set_mask('/', 'F')
set_mask('%', 'F')
set_mask(',', 'F')
set_mask('.', 'F')
set_mask(':', 'F')
set_mask(']', 'F')
set_mask('[', 'F')
set_mask('}', 'F')
set_mask('{', 'F')
set_mask('$', 'F')
set_mask('#', 'F')
set_mask(';', 'F')
set_mask('\\', 'F')
set_mask(' ', 'S')
set_mask('\r', 'S')
set_mask('\n', 'S')
set_mask('\t', 'S')
set_mask('~', 'L')
set_mask('@', 'L')
set_mask('?', 'L')
set_mask('!', 'L')
set_mask('&', 'L')
set_mask('|', 'L')
set_mask('~', 'L')
set_mask('<', 'L')
set_mask('>', 'L')
set_mask('=', 'L')
set_mask('\'', 'C')
set_mask('\"', 'C')


local function dump()
    local t = {"static char cmask[] = {\n"}
    for i=0,0xff do
        local c = mask_map[i] and string.format("'%s', ", mask_map[i]) or "'U', "
        if (i+1) % 32 == 0 then
            c = c .. "\n"
        end
        t[#t+1] = c
    end
    return table.concat(t) .. "\n};"
end

print(dump())

