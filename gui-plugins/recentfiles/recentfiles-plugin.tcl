# META NAME auto-complete plugin
# META DESCRIPTION Does auto-completion for objects
# META AUTHOR <Yvan Volochine> yvan.pd@mail.com
# META VERSION 0.12

package require Tcl 8.4

namespace eval ::pd_guiprefs:: {
    namespace export init
    namespace export write_recentfiles
    namespace export update_recentfiles
}

namespace eval ::recentfiles:: {}

# TODO:
# - list overwritten procedures
# - cleanup the mess


# store that last 5 files that were opened
set recentfiles_list {}
set total_recentfiles 10
set total_recentfiles 5


set ::recentfiles_key ""
set ::recentfiles_domain ""



#################################################################
# global procedures
#################################################################
# ------------------------------------------------------------------------------
# init preferences
#
proc ::recentfiles::init {} {
    switch -- $::windowingsystem {
        "aqua"  { ::recentfiles::init_aqua }
        "win32" { ::recentfiles::init_win }
        "x11"   { ::recentfiles::init_x11 }
    }
    # assign gui preferences
    # osx special case for arrays
    set arr [expr { $::windowingsystem eq "aqua" }]
    set ::recentfiles_list [get_config $::recentfiles_domain $::recentfiles_key $arr]
    if {[llength $::recentfiles_list] > 0} {
        ::pd_menus::update_recentfiles_menu false
    }
}

proc ::recentfiles::init_aqua {} {
    # osx has a "Open Recent" menu with 10 recent files (others have 5 inlined)
    set ::recentfiles_domain org.puredata
    set ::recentfiles_key "NSRecentDocuments"
    set ::total_recentfiles 10
}

proc ::recentfiles::init_win {} {
    # windows uses registry if available
    # FIXME: no package `registry' available on pd tcl right now so we use the
    # same behavior as on linux and write to ~/AppData/Local/Pure-Data/RecentDocs.txt
    #set ::recentfiles_domain "HKEY_CURRENT_USER\\Software\\Pure-Data"
    #set ::recentfiles_key "RecentDocs"
    #pdtk_post "Warning: recentfiles-plugin is buggy on windows!\n"
    set ::recentfiles_domain "~/AppData/Local/Pure-Data"
    set ::recentfiles_key "RecentDocs.txt"
    # FIXME: this should not be there if registry becomes available
    ::recentfiles::prepare_configdir
}

proc ::recentfiles::init_x11 {} {
    # linux uses ~/.config/pure-data dir
    set ::recentfiles_domain "~/.config/pure-data"
    set ::recentfiles_key "recentfiles.conf"
    ::recentfiles::prepare_configdir
}

# ------------------------------------------------------------------------------
# write recent files
#
proc ::pd_guiprefs::write_recentfiles {} {
    write_config $::recentfiles_list $::recentfiles_domain $::recentfiles_key true
}

# ------------------------------------------------------------------------------
# this is called when opening a document (wheredoesthisshouldgo.tcl)
#
proc ::pd_guiprefs::update_recentfiles {afile} {
    # remove duplicates first
    set index [lsearch -exact $::recentfiles_list $afile]
    set ::recentfiles_list [lreplace $::recentfiles_list $index $index]
    # insert new one in the beginning and crop the list
    set ::recentfiles_list [linsert $::recentfiles_list 0 $afile]
    set ::recentfiles_list [lrange $::recentfiles_list 0 \
        [expr $::total_recentfiles - 1]]
    ::pd_menus::update_recentfiles_menu
}

#################################################################
# main read/write procedures
#################################################################

# ------------------------------------------------------------------------------
# get configs from a file or the registry
#
proc get_config {adomain {akey} {arr}} {
    switch -- $::windowingsystem {
        "aqua"  { set conf [get_config_aqua $adomain $akey $arr] }
        "win32" { set conf [get_config_x11 $adomain $akey $arr] }
        "x11"   { set conf [get_config_x11 $adomain $akey $arr] }
    }
    return $conf
}

# ------------------------------------------------------------------------------
# write configs to a file or to the registry
# $arr is true if the data needs to be written in an array
#
proc write_config {data {adomain} {akey} {arr false}} {
    switch -- $::windowingsystem {
        "aqua"  { write_config_aqua $data $adomain $akey $arr }
        "win32" { write_config_x11 $data $adomain $akey }
        "x11"   { write_config_x11 $data $adomain $akey }
    }
}

#################################################################
# os specific procedures
#################################################################

# ------------------------------------------------------------------------------
# osx: read a plist file
#
proc get_config_aqua {adomain {akey} {arr false}} {
    if {![catch {exec defaults read $adomain $akey} conf]} {
        if {$arr} {
            set conf [plist_array_to_tcl_list $conf]
        }
    } {
        # initialize NSRecentDocuments with an empty array
        exec defaults write $adomain $akey -array
        set conf {}
    }
    return $conf
}

# ------------------------------------------------------------------------------
# win: read in the registry
#
proc get_config_win {adomain {akey} {arr false}} {
    if {![catch {package require registry}]} {
        if {![catch {registry get $adomain $akey} conf]} {
            return [expr {$conf}]
        } {
            return {}
        }
    } {
        return {}
        ::pdwindow::error "ERROR:\nrecentfiles-plugin: package \
            'registry' was not found\n"
    }
}

# ------------------------------------------------------------------------------
# linux: read a config file and return its lines splitted.
#
proc get_config_x11 {adomain {akey} {arr false}} {
    set filename [file join $adomain $akey]
    set conf {}
    if {
        [file exists $filename] == 1
        && [file readable $filename]
    } {
        set fl [open $filename r]
        while {[gets $fl line] >= 0} {
           lappend conf $line
        }
        close $fl
    }
    return $conf
}

# ------------------------------------------------------------------------------
# osx: write configs to plist file
# if $arr is true, we write an array
#
proc write_config_aqua {data {adomain} {akey} {arr false}} {
    # FIXME empty and write again so we don't loose the order
    if {[catch {exec defaults write $adomain $akey -array} errorMsg]} {
        puts stderr "ERROR: write_config_aqua $akey: $errorMsg"
    }
    if {$arr} {
        foreach filepath $data {
            exec defaults write $adomain $akey -array-add $filepath
        }
    } {
        exec defaults write $adomain $akey $data
    }
}

# ------------------------------------------------------------------------------
# win: write configs to registry
# if $arr is true, we write an array
#
proc write_config_win {data {adomain} {akey} {arr false}} {
    if {![catch {package require registry}]} {
        # FIXME
        if {$arr} {
            registry set $adomain $akey $data multi_sz
        } {
            registry set $adomain $akey $data sz
        }
    } {
        ::pdwindow::verbose 1 "WARNING:\nrecentfiles-plugin: package \
            'registry' was not found\n"
    }
}

# ------------------------------------------------------------------------------
# linux: write configs to USER_APP_CONFIG_DIR
#
proc write_config_x11 {data {adomain} {akey}} {
    # right now I (yvan) assume that data are just \n separated, i.e. no keys
    set data [join $data "\n"]
    set filename [file join $adomain $akey]
    if {[catch {set fl [open $filename w]} errorMsg]} {
        ::pdwindow::error "ERROR:\nwrite_config_x11 $data $akey: $errorMsg\n"
    } {
        puts -nonewline $fl $data
        close $fl
    }
}

#################################################################
# utils
#################################################################

# ------------------------------------------------------------------------------
# linux only! : look for pd config directory and create it if needed
#
proc ::recentfiles::prepare_configdir {} {
    if {[file isdirectory $::recentfiles_domain] != 1} {
        if {! [catch {file mkdir $::recentfiles_domain}] } {
            ::pdwindow::verbose 1 "$::recentfiles_domain was created.\n"
        } {
            ::pdwindow::error "ERROR:\nrecentfiles-plugin could not create \
                $::recentfiles_domain\n"
        }
    }
}

# ------------------------------------------------------------------------------
# osx: handles arrays in plist files (thanks hc)
#
proc plist_array_to_tcl_list {arr} {
    set result {}
    set filelist $arr
    regsub -all -- {("?),\s+("?)} $filelist {\1 \2} filelist
    regsub -all -- {\n} $filelist {} filelist
    regsub -all -- {^\(} $filelist {} filelist
    regsub -all -- {\)$} $filelist {} filelist

    foreach file $filelist {
        set filename [regsub -- {,$} $file {}]
        lappend result $filename
    }
    return $result
}

proc ::pd_menus::build_file_menu {mymenu} {
    # run the platform-specific build_file_menu_* procs first, and config them
    [format build_file_menu_%s $::windowingsystem] $mymenu
    $mymenu entryconfigure [_ "New"]        -command {menu_new}
    $mymenu entryconfigure [_ "Open"]       -command {menu_open}
    $mymenu entryconfigure [_ "Save"]       -command {menu_send $::focused_window menusave}
    $mymenu entryconfigure [_ "Save As..."] -command {menu_send $::focused_window menusaveas}
    #$mymenu entryconfigure [_ "Revert*"]    -command {menu_revert $::focused_window}
    $mymenu entryconfigure [_ "Close"]      -command {menu_send_float $::focused_window menuclose 0}
    $mymenu entryconfigure [_ "Message..."] -command {menu_message_dialog}
    $mymenu entryconfigure [_ "Print..."]   -command {menu_print $::focused_window}
    # update recent files
    ::pd_menus::update_recentfiles_menu false
}
 
proc ::pd_menus::update_recentfiles_menu {{write true}} {
    variable menubar
    switch -- $::windowingsystem {
        "aqua"  {::pd_menus::update_openrecent_menu_aqua .openrecent $write}
        "win32" {::pd_menus::update_recentfiles_on_menu $menubar.file $write}
        "x11"   {::pd_menus::update_recentfiles_on_menu $menubar.file $write}
    }
}

 
proc ::pd_menus::clear_recentfiles_menu {} {
    set ::recentfiles_list {}
    ::pd_menus::update_recentfiles_menu
    # empty recentfiles in preferences (write empty array)
    ::pd_guiprefs::write_recentfiles
}
 

proc ::pd_menus::update_openrecent_menu_aqua {mymenu {write}} {
    if {! [winfo exists $mymenu]} {menu $mymenu}
    $mymenu delete 0 end

    # now the list is last first so we just add
    foreach filename $::recentfiles_list {
        $mymenu add command -label [file tail $filename] \
            -command "open_file {$filename}"
    }
    # clear button
    $mymenu add  separator
    $mymenu add command -label [_ "Clear Menu"] \
        -command "::pd_menus::clear_recentfiles_menu"
    # write to config file
    if {$write == true} { ::pd_guiprefs::write_recentfiles }
}


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
    while {[incr i -1]} {
        set filename [lindex $::recentfiles_list $i]
        set basename [file tail $filename]
        set j [expr $i + 1]
        $mymenu insert [expr $top_separator+1] command \
            -label [concat "$j. " $basename] -command \
            "open_file {$filename}" -underline 0
    }
    set filename [lindex $::recentfiles_list 0]
    set basename [file tail $filename]
    $mymenu insert [expr $top_separator+1] command \
        -label [concat "1. " $basename] -command \
        "open_file {$filename}" -underline 0

    # write to config file
    if {$write == true} { ::pd_guiprefs::write_recentfiles }
}


proc ::pd_menus::build_file_menu_aqua {mymenu} {
    variable accelerator
    $mymenu add command -label [_ "New"]       -accelerator "$accelerator+N"
    $mymenu add command -label [_ "Open"]      -accelerator "$accelerator+O"
    # this is now done in main ::pd_menus::build_file_menu
    #::pd_menus::update_openrecent_menu_aqua .openrecent
    $mymenu add cascade -label [_ "Open Recent"] -menu .openrecent
    $mymenu add  separator
    $mymenu add command -label [_ "Close"]     -accelerator "$accelerator+W"
    $mymenu add command -label [_ "Save"]      -accelerator "$accelerator+S"
    $mymenu add command -label [_ "Save As..."] -accelerator "$accelerator+Shift+S"
    #$mymenu add command -label [_ "Save All"]
    #$mymenu add command -label [_ "Revert to Saved"]
    $mymenu add  separator
    $mymenu add command -label [_ "Message..."]
    $mymenu add  separator
    $mymenu add command -label [_ "Print..."]   -accelerator "$accelerator+P"
}
 

proc pdtk_canvas_saveas {name initialfile initialdir} {
    if { ! [file isdirectory $initialdir]} {set initialdir $::env(HOME)}
    set filename [tk_getSaveFile -initialfile $initialfile -initialdir $initialdir \
                      -defaultextension .pd -filetypes $::filetypes]
    if {$filename eq ""} return; # they clicked cancel

    set extension [file extension $filename]
    set oldfilename $filename
    set filename [regsub -- "$extension$" $filename [string tolower $extension]]
    if { ! [regexp -- "\.(pd|pat|mxt)$" $filename]} {
        # we need the file extention even on Mac OS X
        set filename $filename.pd
    }
    # test again after downcasing and maybe adding a ".pd" on the end
    if {$filename ne $oldfilename && [file exists $filename]} {
        set answer [tk_messageBox -type okcancel -icon question -default cancel\
                        -message [_ "\"$filename\" already exists. Do you want to replace it?"]]
        if {$answer eq "cancel"} return; # they clicked cancel
    }
    set dirname [file dirname $filename]
    set basename [file tail $filename]
    pdsend "$name savetofile [enquote_path $basename] [enquote_path $dirname]"
    set ::filenewdir $dirname
    # add to fecentfiles
    ::pd_guiprefs::update_recentfiles $filename
}


proc open_file {filename} {
    set directory [file normalize [file dirname $filename]]
    set basename [file tail $filename]
    if {
        [file exists $filename]
        && [regexp -nocase -- "\.(pd|pat|mxt)$" $filename]
    } then {
        ::pdtk_canvas::started_loading_file [format "%s/%s" $basename $filename]
        pdsend "pd open [enquote_path $basename] [enquote_path $directory]"
        # now this is done in pd_guiprefs
        ::pd_guiprefs::update_recentfiles $filename
    } {
        ::pdwindow::post [format [_ "Ignoring '%s': doesn't look like a Pd-file"] $filename]
    }
}

::recentfiles::init

pdtk_post "loaded: recentfiles-plugin 0.12\n"
