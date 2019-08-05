
mingw: line.dll

line.dll: line.c
	gcc -g -O2 -Wall -shared -o $@ $^ -I../lua-5.3.5/src -L../lua-5.3.5/src -llua53

macosx: line.so

line.so: line.c
	clang -g -O2 -Wall -undefined dynamic_lookup -shared -o $@  $^