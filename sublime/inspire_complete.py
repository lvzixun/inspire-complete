# -*- coding: utf-8 -*-

import threading
import re
import os
import sublime, sublime_plugin
from subprocess import Popen, PIPE, STDOUT
import subprocess

cmask = [
	'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'S', 'S', 'U', 'U', 'S', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'S', 'L', 'C', 'F', 'F', 'F', 'L', 'C', 'U', 'U', 'F', 'F', 'F', 'F', 'F', 'F', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'F', 'F', 'L', 'L', 'L', 'L',
    'L', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'F', 'F', 'F', 'U', 'A',
    'U', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'A', 'F', 'L', 'F', 'L', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
    'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U',
]

def char2type(char):
	code = int(bytes(char, 'utf-8')[0])
	if code < 0 or code >= len(cmask):
		return 'U'
	else:
		return cmask[code]


def check_need_completion(view):
	point = view.sel()[0].begin() - 1
	if point < 0:
		return False

	cur_char = view.substr(point)
	ct = char2type(cur_char)
	prev_char = view.substr(point-1)
	pt = char2type(prev_char)
	if cur_char != '\n' and ct != pt or cur_char == 'A':
		return True
	else:
		return False


def get_startup_info(platform):
	if platform == "windows":
		info = subprocess.STARTUPINFO()
		info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
		return info
	else:
		return None


class InspireComplete(object):
	def __init__(self):
		work_dir = 'C:\\Users\\zixun\\AppData\\Roaming\\Sublime Text 3\\Packages\\line-complete'
		inspire_lua =  os.path.join(work_dir, "inspire.lua")
		self._inspire_server = Popen(['lua', inspire_lua, 'windows', work_dir], 
			stdout=PIPE, stdin=PIPE, stderr=PIPE, 
			startupinfo=get_startup_info(sublime.platform()))
		def check_servier():
			poll = self._inspire_server.poll()
			if poll != None:
				err = self._inspire_server.stderr.readline()
				print("self._inspire_server", self._inspire_server, "poll:", poll, "err", err)
				self._inspire_server.terminate()
		sublime.set_timeout(check_servier, 400)

	def _write_line(self, l):
		l = bytes(l, 'utf-8')
		self._inspire_server.stdin.write(l)
		self._inspire_server.stdin.write(b'\n')

	def _flush(self):
		self._inspire_server.stdin.flush()

	def _write_data(self, data):
		size = len(data)
		data = bytes(data, 'utf-8')
		s = "%d\n" % (size)
		sz = bytes(s, 'UTF-8')
		self._inspire_server.stdin.write(sz)
		self._inspire_server.stdin.write(data)

	def _read_line(self):
		data = self._inspire_server.stdout.readline()
		data = str(data, "UTF-8")
		data = data.replace("\r", "")
		data = data.replace("\n", "")
		return data

	def complete_at(self, filename, source, row, col):
		self._write_line(filename)
		loc = "%d %d" % (row, col)
		self._write_line(loc)
		self._write_data(source)
		self._flush()

		result = []
		count = int(self._read_line())
		for i in range(count):
			l = self._read_line()
			result.append(l)
		return result


class InspirListener(sublime_plugin.EventListener):
	def __init__(self):
		self.inspire_complete = InspireComplete()

	def on_modified(self, view):
		b = check_need_completion(view)
		if b:
			self.per_complete()

	def per_complete(self):
		sublime.active_window().run_command("hide_auto_complete")
		def hack2():
			sublime.active_window().run_command("auto_complete",{
				'disable_auto_insert': True,
				'api_completions_only': True,
				'next_competion_if_showing': False})
		hack2()
		sublime.set_timeout(hack2, 1)

	def on_query_completions(self, view, prefix, locations):
		row, col = view.rowcol(locations[0])
		row += 1

		file_name = view.file_name()
		suffix = file_name and file_name.split(".")[-1]
		if not suffix or suffix == "" or suffix == "log":
			return

		flag = 0
		source = view.substr(sublime.Region(0, view.size()))
		result = self.inspire_complete.complete_at(file_name, source, row, col)
		# print(result)

		ret = []
		for v in result:
			entry = ("%s\tinspire"%(v), v)
			ret.append(entry)
		return (ret, flag)