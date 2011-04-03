# META NAME auto-complete plugin
# META DESCRIPTION Does auto-completion for objects
# META AUTHOR <Yvan Volochine> yvan.pd@mail.com
# META VERSION 0.1

package require Tcl 8.4
package require pdwindow 0.1

# GLOBALS
set ::pdwindow_menubar ".menubar"
set ::patch_menubar   ".menubar"

proc recreate_menubar {} {
    # FIXME delete menubar and re-create it
    .menubar delete 0 6

    set menulist "file edit put find media window help"
    foreach mymenu $menulist {    
        if {$mymenu eq "find"} {
            set underlined 3
        } {
            set underlined 0
        }
        .menubar add cascade -label [_ [string totitle $mymenu]] \
            -underline $underlined -menu .menubar.$mymenu
    }
    if {$::windowingsystem eq "aqua"} {create_apple_menu .menubar}
    if {$::windowingsystem eq "win32"} {create_system_menu .menubar}
    . configure -menu .menubar
}

recreate_menubar

pdtk_post "loaded: menubar-plugin 0.1\n"
