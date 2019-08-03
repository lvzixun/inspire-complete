# -*- coding: utf-8 -*-

import time
from subprocess import Popen, PIPE, STDOUT


p = Popen(['lua', 'inspire.lua'], stdout=PIPE, stdin=PIPE, stderr=STDOUT)
def write_line(l):
	l = bytes(l, 'utf-8')
	p.stdin.write(l)
	p.stdin.write(b'\n')

def flush():
	p.stdin.flush()

def write_data(data):
	size = len(data)
	data = bytes(data, 'utf-8')
	s = "%d\n" % (size)
	sz = bytes(s, 'UTF-8')
	p.stdin.write(sz)
	p.stdin.write(data)

def read_line():
	data = p.stdout.readline()
	data = str(data, "UTF-8")
	data = data.replace("\r", "")
	data = data.replace("\n", "")
	return data


source = [
['''
struct {
	unsigned int aa;
	unsigned int bb;
	unsigned int cc;
	uns
}
''', 6, 7],

['''
local dd = test.group[1].value
local self = test.group[2].value
local cc
''', 4, 8],

['''
for i,v in ipairs(table_name) do
    print(i,v)
end
for i,v in ipairs(table_name) do
    print(i,v)
end
for
''', 8, 3],

['''
local cc = require "ui.cc"
local bb = require "ui.bb"
local s
local s1 = 1123
local s2 = 1123
''', 4, 7],

['''
local TestComplete = require "ui.test_complete"
local BoxWidget = require "ui.box_widget"
local TestShapeWidget =
''', 4, 23]
]


def complete_at(filename, s, row, col):
	write_line(filename)
	loc = "%d %d" % (row, col)
	write_line(loc)
	write_data(s)
	flush()

	result = []
	count = int(read_line())
	for i in range(count):
		l = read_line()
		result.append(l)
	return result



def do_complete():
	idx = 1
	for info in source:
		filename = "test_file%d" % (idx)
		s = info[0]
		row = info[1]
		col = info[2]
		result = complete_at(filename, s, row, col)
		print(s)
		print("---------- complete ------------")
		print(result)
		print("--------------------------------")
		time.sleep(1)
		idx = idx + 1



do_complete()