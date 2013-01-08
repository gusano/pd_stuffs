# completion-plugin

This plugin enables auto-completion for Pd objects.
Just hit the TAB key while typing into an object to trigger completion mode.

## Screenshot

![completion-plugin screenshot](http://www.yvanvolochine.com/media/images/completion_new.gif)

You can see a video demo of the plugin [on vimeo](https://vimeo.com/23557543).

## Install:

 - copy the whole `completion` folder anywhere and add it to your `PD PATH`

## Notes:

By default, only Pd internals are available, but you can add your own
objects|abstractions names:

 - add them into any `*.txt` file inside
 `user_objects` subfolder
 - these files should contain one object|abstraction name per line (no commas at the end of the
line)

Some other options can be tweaked in the `completion.cfg` config file, it should
be pretty straightforward.

Some libraries will automatically get their externals added if they were loaded
with -lib (like Gem, gridflow, ...).
Their objects list can be found in the subfolder `lib_objects`.

Send bug reports to `contact@yvanvolochine.com`.

# Version history:

## 0.42:

 - add `user_objects` file support
 - add optional offset for popup position
 - add forgotten drawpolygon

## 0.41:

 - cleanup, simplify focus behavior, remove unused proc, better bindings
 - add support to remember `send, receive, table, delread, ...` argument names
 - add libraries objects lists (Gem, gridflow, py)
 - various fixes

## 0.40:

 - new GUI
 - rename to 'completion-plugin.tcl'
 - add bash completion mode
 - add support for osx and win32
 - add *.cfg file for user options
 - TODO add support for user arguments (like [tabread foo], etc) ??

## 0.33:

 - cosmetic fixes for osx
 - better box coordinates
 - bugfix: popup menu wrongly placed with huge fonts

## 0.32:

 - add colors
 - bugfix: cycling has 1 step too much
 - bugfix: first completed doesn't erase typed text

## 0.31:

 - add TAB support to cycle through completions

## 0.3:

 - simplify cycling code
 - bugfix: nameclash with right-click popup (sic)
 - bugfix: missing or mispelled internals

## 0.2:

 - add popup menu for completion

## 0.12:

 - fix namespace