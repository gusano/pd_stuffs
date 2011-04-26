# META NAME recentfiles-plugin
# META DESCRIPTION Add ALT shortcuts to recentfiles
# META AUTHOR <Yvan Volochine> yvan.volochine@mail.com
# META VERSION 0.2

package require Tcl 8.5

###########################################################
# overwritten procedures
rename ::pd_menus::update_recentfiles_on_menu \
       ::pd_menus::update_recentfiles_on_menu_old


proc ::pd_menus::update_recentfiles_on_menu {mymenu {write}} {
    set lastitem [$mymenu index end]
    set i 1
    while {[$mymenu type [expr $lastitem-$i]] ne "separator"} {incr i}
    set bottom_separator [expr $lastitem-$i]
    incr i

    while {[$mymenu type [expr $lastitem-$i]] ne "separator"} {incr i}
    set top_separator [expr $lastitem-$i]
    if {$top_separator < [expr $bottom_separator-1]} {
        $mymenu delete [expr $top_separator+1] [expr $bottom_separator-1]
    }
    # insert the list from the end because we insert each element on the top
    set i [llength $::recentfiles_list]
    while {[incr i -1] > -1} {

        set filename [lindex $::recentfiles_list $i]
        set j [expr {$i + 1}]
        $mymenu insert [expr {$top_separator+1}] command \
            -label [concat "$j. " [file tail $filename]] -command \
            "open_file {$filename}" -underline 0
    }

    # write to config file
    if {$write == true} { ::pd_guiprefs::write_recentfiles }
}


if {[llength $::recentfiles_list] > 0} {
    ::pd_menus::update_recentfiles_menu false
}

pdtk_post "loaded: recentfiles-plugin 0.2\n"
