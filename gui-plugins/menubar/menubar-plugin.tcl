# META NAME menubar-plugin
# META DESCRIPTION adds usual ALT shortcuts to pd menubar
# META AUTHOR <Yvan Volochine> yvan.volochine@gmail.com
# META VERSION 0.11

package require Tcl 8.4
package require pdwindow 0.1


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
    . configure -menu .menubar
}

if {$::windowingsystem eq "x11"} {
    recreate_menubar
    pdtk_post "loaded: menubar-plugin 0.1\n"
} {
    pdtk_post "WARNING:\nmenubar-plugin is for linux only\n"
}
