line.so: line.c
	clang -g -Wall -undefined dynamic_lookup -shared -o $@  $^