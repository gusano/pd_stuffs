# Recentfiles plugin

This Gui-plugin adds keyboard shortcuts to recent files list in [pure-data](http://puredata.info).


### Note

The original behavior of this plugin (recent files list when quitting/restarting Pd)
has been added to Pd vanilla >=0.43.


### Bugs

Send bug reports to `contact@yvanvolochine.com`

-----------------------------------------------------------------

### Version history

#### 0.21
 - protect against empty file list

#### 0.2
 - now just adds ALT shortcuts (original plugin was added to distro)
 - FIX: META descriptions

#### 0.13
 - FIX win users now have linux behavior (no more registry)
 - FIX pd would hang if plugin was launched without saved file

#### 0.12
 - FIX proc was cut (pdtk_saveas)

#### 0.11
 - add keyboard shortcuts (1..5) for recent files
 - better error handling when win32 tcl package regitry is missing
 - FIX bad max numbers of recent