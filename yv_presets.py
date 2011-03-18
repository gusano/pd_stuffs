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

	ui     = "" # type of object (hsl, tgl, ...)
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

	path  = ''
	ui    = ['hsl', 'vsl', 'tgl', 'nbx', 'floatatom', 'hradio', 'vradio']
	txt   = []   # patch as text
	uis   = []   # found ui objects
	arg   = None # $1 argument
	found = False

	def __init__(self, path):
		self.uis = [] # weird bug otherwise
		self.arg = None
		f = open(str(path), 'r')
		self.txt = f.readlines()
		f.close()
		self.reformat()


	def reformat(self):
		"""in case the patch as text has \n characters"""

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
				

	def validate_send_receive(self, arr):
		"""check that send and receive symbols are correct (not 'empty' neither '-')"""

		valid = True
		wrong = ['-', 'empty']
		for a in arr:
			if a in wrong:
				valid = False
				break
		return valid

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
			# this could/should be better
			s = r"(\S+[a-zA-Z_]+\S*)\s+(\S*[a-zA-Z_]+\S*)\s+(\S*[a-zA-Z_]+\S*)"
			reg = re.findall(s, l)
			if len(reg) > 0:
				send, receive, label = reg[0]

		if self.validate_send_receive([send, receive]):
			u.s_name = send.replace("\\", "")
			u.r_name = receive.replace("\\", "")
			# replace $1 and #1 with provided argument
			if self.arg:
				u.s_name = u.s_name.replace("$1", str(self.arg))
				u.r_name = u.r_name.replace("$1", str(self.arg))
				u.s_name = u.s_name.replace("#1", str(self.arg))
				u.r_name = u.r_name.replace("#1", str(self.arg))
			self.uis.append(u)
			self.found = True




class Preset(pyext._class):
	"""main class"""

	_inlets  = 1
	_outlets = 0
	patches  = []
	found    = []   # all UI objects in patch and abstractions
	preset   = {}   # current state
	presets  = {}   # all presets
	current  = ""   # current object being queried
	special  = None # special case for toggle (needs 2 bangs)
	verbose  = True

	def __init__(self,*args):
		"""Class constructor"""

		self.clean()
		print "\n##############\n# Presets Manager #\n##############\n"


	def clean(self):
		self.patches = []
		self.preset  = {}
		self.presets = {}
		self.found   = []


	def reset_1(self):
		"""clean all"""

		self.clean()


	def path_1(self, *args):
		"""path of a patch that will be using presets
		can be on the form [path PATH/TO/ABSTRACTION ARGUMENT(
		ARGUMENT will replace '$1' in receive symbols of UI objects"""

		path = os.path.expanduser(str(args[0]))
		patch = Patch(path)
		if len(args) > 1: patch.arg = args[1]
		if self.verbose: print "added ", path
		# store and bind the UI objects
		if patch.find_uis():
			self.patches.append(patch)
			self.bind_uis(patch)


	def bind_uis(self, patch):
		"""bind objects send symbol to recv method"""

		for u in patch.uis:
			self.found.append(u)
			self._bind(u.s_name, self.recv)
			if self.verbose: print "bound ", u.ui, " &s_name: ", u.s_name, " &r_name: ", u.r_name


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
			self.special = None
		self.presets[a] = self.preset
		self.preset = {}
		print "stored ", a


	def recall_1(self, a):
		"""recall method"""

		new = None
		try:
			new = self.presets[a]
			for k in new.keys():
				self._send(k, new[k])
		except:
			print "no preset ", a


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
		print "presets written to ", path


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
