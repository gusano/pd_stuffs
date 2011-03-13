# py/pyext - python script objects for PD and MaxMSP
#
# Copyright (c) 2002-2005 Thomas Grill (gr@grrrr.org)
# For information on usage and redistribution, and for a DISCLAIMER OF ALL
# WARRANTIES, see the file, "license.txt," in this distribution.  

# yv_presets.py
# yvan.volochine@gmail.com - 20100313

"""This is a preset management script that I wrote for my friend.
I thought it would be a nice exercise and a good way to learn how to use [py/pyext].

You can:
- manage presets for all UI objects that have proper send/receive symbols


There are several classes exposing py/pyext features:
- UiObject: A class for the UI objects (with their type and send/receive symbols)
- Patch: A class for patches as text. patches are parsed to find UI objects inside it
- Preset: the main class

"""

try:
	import pyext
except:
	print "ERROR: This script must be loaded by the PD/Max pyext external"


import os, re, pickle



class UiObject(object):

	ui = "" # type of object (hsl, tgl, ...)
	s_name = ""
	r_name = ""
	l_name = ""

	def __init__(self, ui):
		self.ui = ui


class Patch(object):
	"""for some reasons, pd patches are weirdly formatted (with extra \n).
	this class reformats the patch and checks each line to find whether 
	there's an UI object or not.
	the UI objects *must* have send/receive names to respond to presets.
	this might not be the best way to do it (parsing lines is not so elegant)
	but it's the only one I thought about"""

	path = ''
	txt = '' # patch as text
	ui = ['hsl', 'vsl', 'tgl', 'nbx', 'floatatom', 'hradio', 'vradio']
	uis = [] # found ui objects
	found = False

	def __init__(self, path):
		self.uis = [] # weird bug otherwise
		self.path = str(path)
		f = open(self.path, 'r')
		self.txt = f.readlines()
		f.close()
		self.reformat()


	def reformat(self):
		"""in case the patch as text has \n characters, we reformat it
		is that really necessary ???"""

		self.txt = ''.join(self.txt)
		self.txt = self.txt.split(';')


	def find_uis(self):
		"""parse each line of the patch and look for UI objects"""

		for l in self.txt:
			# search UI objects
			for u in self.ui:
				if re.search(u, l):
					x = UiObject(u)
					self.find_send_receive(l, x)
					break

		return self.found
				

	def find_send_receive(self, l, u):
		"""look for 3 words in a row, which means send symbol,
		receive symbol and label (floatatom has those in reverse order)
		"""

		label, send, receive = ['empty', 'empty', 'empty']
		# special case for floatatom: line ends with 'label, receive, send'
		if u.ui == 'floatatom':
			l = l.replace(';', '')
			l = l.split(" ")
			label, receive, send = l[-3:]
		else:
			# this could be better
			s = r"(\S+[a-zA-Z]+\S*)\s+(\S*[a-zA-Z]+\S*)\s+(\S*[a-zA-Z]+\S*)"
			reg = re.findall(s, l)
			if len(reg) > 0:
				send, receive, label = reg[0]

		if [send, receive] != ['empty', 'empty']:
			# cleanup $ char
			u.s_name = send.replace("\\", "")
			u.r_name = receive.replace("\\", "")
			u.l_name = label.replace("\\", "")
			self.uis.append(u)
			self.found = True




class Preset(pyext._class):
	"""main class"""

	# number of inlets and outlets
	_inlets = 1
	_outlets = 0
	found = []     # all UI objects in patch and abstractions
	preset = {}    # current state
	presets = {}   # all presets
	current = ""   # current object being queried
	special = None # special case for toggle (needs 2 bangs)


	def __init__(self,*args):
		"""Class constructor"""

		print "\n##############\n# Presets Manager #\n##############\n"


	def path_1(self, *args):
		"""paths of the patches using presets"""

		patches = []
		for a in args:
			path = os.path.expanduser(str(a))
			current = Patch(path)
			# first store and then bind the UI objects (crash otherwise)
			if current.find_uis():
				patches.append(current)

		for p in patches:
			self.bind_uis(p)


	def bind_uis(self, patch):
		"""bind objects send symbol to recv method"""

		for u in patch.uis:
			self.found.append(u)
			self._bind(u.s_name, self.recv)


	def store_1(self, a):
		"""loop through all UI objects and send them a bang to get
		their current value and store it"""

		for f in self.found:
			# unlock and prepare to store the first received value
			self.current = f.r_name # receive symbol
			self._send(f.r_name, "bang", ()) # send a bang
			if f.ui == 'tgl':
				self.special = f.r_name
		# lock recv function, store and clean
		self.current = ""
		if self.special != None:
			# special case with [tgl]:
			# sending it a bang changes its state so it has to recover
			# its initial state
			self.preset[self.special] = 1 - self.preset[self.special]
			self._send(self.special, "bang", ()) # send a second bang
			self.special = None # reset
		self.presets[a] = self.preset
		self.preset = {} # cleanup otherwise things are messed up
		print "stored ", a


	def recall_1(self, a):
		"""recall method"""

		new = None
		try:
			new = self.presets[a]
		except:
			print "no preset ", a
		if new:
			for k in new.keys():
				self._send(k, new[k])


	def recv(self, arg):
		"""receive method"""

		# store the value if unlocked
		if self.current != "":
			self.preset[self.current] = arg
			# lock again
			self.current = ""


        def bind_1(self, s_name):
		"""bind object to recv method"""

		self._bind(s_name, self.recv)


	def write_1(self, path):
		"""write presets to file"""

		path = os.path.expanduser(str(path))
		f = open(path, 'w')
		pickle.dump(self.presets, f)
		f.close()
		print "presets saved to ", path


	def read_1(self, path):
		"""read presets from file"""

		path = os.path.expanduser(str(path))
		f = open(path, 'rb')
		self.presets = pickle.load(f)
		f.close()


	def print_1(self):
		print self.presets


	def __del__(self):
		"""Class destructor"""

		pass
