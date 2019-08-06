#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <lua.h>
#include <lauxlib.h>


static char cmask[] = {
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'S', 'S', 'U', 'U', 'S', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'S', '!', 'C', '#', '$', 'F', '&', 'C', 'U', 'U', 'F', 'F', ',', 'F', '.', 'F', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', ':', ';', 'L', '=', 'L', '?',
    '@', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', '[', 'F', ']', 'U', 'A',
    'U', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', '{', '|', '}', '~', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U'
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
        unsigned char c = (unsigned char)s[i];
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

    // int sc = read_type(line, 0, len, 'S'); // pass begin space
    lua_newtable(L);
    int idx = 0;
    int sc = 0;
    for(i=sc; i<len; i++) {
        unsigned char c = (unsigned char)line[i];
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


static int
lshape_token(lua_State* L) {
    size_t len = 0;
    const char* s = luaL_tolstring(L, 1, &len);
    luaL_Buffer b;
    size_t new_sz = len *2;
    char * buffer = luaL_buffinitsize(L, &b, new_sz);
    size_t i=0;
    size_t buf_idx = 0;
    bool is_shape = false;
    for(i=0; i<len; i++) {
        char c = s[i];
        if(c >='A' && c <= 'Z') {
            if(i > 0) {
                buffer[buf_idx++] = '_';
            }
            buffer[buf_idx++] = c - 'A' + 'a';
            is_shape = true;
        }else if (c == '_') {
            char nc = ((i+1)<len)?(s[i+1]):('\0');
            if(nc >= 'a' && nc <= 'z') {
                buffer[buf_idx++] = nc - 'a' + 'A';
                is_shape = true;
                i++;
            }else {
                buffer[buf_idx++] = c;                
            }
        }else if(i ==0 && c >='a' && c <= 'z') {
            buffer[buf_idx++] = c - 'a' + 'A';
            is_shape = true;
        }else {
            buffer[buf_idx++] = c;
        }
    }
    luaL_pushresultsize(&b, buf_idx);
    lua_pushboolean(L, is_shape);
    return 2;
}


int
luaopen_line_c(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        {"capture_line", lline_capture_line},
        {"shape_token", lshape_token},
        {NULL, NULL}
    };

    luaL_newlib(L, l);
    return 1;
}