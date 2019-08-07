
mingw: line.dll lfs.dll

line.dll: line.c
	gcc -g -O2 -Wall -shared -o $@ $^ -I../lua-5.3.5/src -L../lua-5.3.5/src -llua53

lfs.dll: lfs.c
	gcc -g -O2 -Wall -shared -o $@ $^ -I../lua-5.3.5/src -L../lua-5.3.5/src -llua53

macosx: line.so lfs.so

line.so: line.c
	clang -g -O2 -Wall -undefined dynamic_lookup -shared -o $@  $^

lfs.so: lfs.c
	clang -g -O2 -Wall -undefined dynamic_lookup -shared -o $@  $^

clean:
	rm -rf *.dll *.so