#include <stdlib.h>
#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>


static char cmask[] = {
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'S', 'S', 'U', 'U', 'S', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'S', 'L', 'C', 'S', 'S', 'F', 'L', 'C', 'U', 'U', 'F', 'F', 'F', 'F', 'F', 'F', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'F', 'S', 'L', 'L', 'L', 'L',
    'L', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'F', 'S', 'F', 'U', 'A',
    'U', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'F', 'L', 'F', 'L', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
};
#define ctype(c) (cmask[(int)(c)])

// static int
// read_string(const char* s, size_t b, size_t e) {
//     int read_count = 0;
//     size_t i;
//     char close = s[b];
//     b++;
//     for(i=b; i<e; i++) {
//         char c = s[i];
//         if(c != close) {
//             read_count++;
//         }else {
//             break;
//         }
//     }
//     return read_count;
// }


static int 
read_id(const char* s, size_t b, size_t e) {
    int read_count = 0;
    size_t i;
    for(i=b; i<e; i++) {
        char c = s[i];
        char ct = ctype(c);
        if(ct == 'A' || ct == 'N') {
            read_count++;
        }else {
            break;
        }
    }
    return read_count;
}


static int
read_type(const char* s, size_t b, size_t e, char t) {
    int read_count = 0;
    size_t i;
    for(i=b; i<e; i++) {
        char c = s[i];
        char ct = ctype(c);
        if(ct == t) {
            read_count++;
        }else {
            break;
        }
    }
    return read_count;
}


static int
lline_capture_line(lua_State* L) {
    size_t len = 0;
    size_t i=0;
    int read_count = 0;
    const char* line = luaL_tolstring(L, 1, &len);
    if(line == NULL || len == 0) {
        return 0;
    }

    int sc = read_type(line, 0, len, 'S'); // pass begin space
    lua_newtable(L);
    int idx = 0;
    for(i=sc; i<len; i++) {
        char c = line[i];
        char ct = ctype(c);
        switch(ct) {
            case 'A': {
                read_count = read_id(line, i, len);
            }break;
            // case 'S': {  // pass space
            //     continue;
            // }break;
            // case 'C': {
            //     read_count = read_string(line, i, len);
            //     lua_pushfstring(L, "%c", ct);
            //     lua_seti(L, -2, ++idx); // set type
            //     lua_pushlstring(L, line+i+1, read_count);
            //     lua_seti(L, -2, ++idx); // set string
            //     i += read_count+1;
            //     continue;
            // }break;
            default: {
                read_count = read_type(line, i, len, ct);
            }break;
        }
        if(read_count <= 0) {
            luaL_error(L, "invalid read_count");
        }
        lua_pushinteger(L, i+1);
        lua_seti(L, -2, ++idx);  // set capture begin string index

        lua_pushfstring(L, "%c", ct);
        lua_seti(L, -2, ++idx); // set type

        lua_pushlstring(L, line+i, read_count);
        lua_seti(L, -2, ++idx); // set string
        i += (read_count-1);
    }
    return 1;
}


int
luaopen_line_c(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        {"capture_line", lline_capture_line},
        {NULL, NULL}
    };

    luaL_newlib(L, l);
    return 1;
}