# META NAME completion plugin
# META DESCRIPTION enables completion for objects
# META AUTHOR <Yvan Volochine> yvan.volochine@gmail.com
# META VERSION 0.41

# TODO
# - add user arguments (tabread $1 ...)


package require Tcl 8.5
namespace eval ::completion:: {
    variable ::completion::config
    variable external_filetype ""
    variable completion_empty "(none)"
}

###########################################################
# overwritten
rename pdtk_text_editing pdtk_text_editing_old
rename ::dialog_font::ok ::dialog_font::ok_old

############################################################
# GLOBALS

# default
set ::completion::config(user_objects_list) "~/pd/list_of_my_objects.txt"
set ::completion::config(lines) 7
set ::completion::config(font) "DejaVu Sans Mono"
set ::completion::config(font_size) 9 ;# FIXME ???
set ::completion::config(bg) "#418bd4"
set ::completion::config(fg) white

# private
set ::toplevel ""
set ::current_canvas ""
set ::current_tag ""
set ::current_text ""
set ::erase_text ""
set ::completions {}
set ::completion_keywords(sr)
set ::completion_keywords(arr)
set ::new_object false
set ::editx 0
set ::edity 0

# all pd internals (hopefully)
set ::all_externals {abs abs~ adc~ append atan atan2 bag bang bang~ bendin \
bendout biquad~ block bng bp~ canvas catch~ change clip clip~ cos cos~ cpole~ \
cputime ctlin ctlout curve czero_rev~ czero~ dac~ dbtopow dbtopow~ dbtorms \
dbtorms~ declare delay delread~ delwrite~ div drawnumber env~ exp exp~ fft~ \
float framp~ ftom ftom~ get getsize hip~ hradio hslider ifft~ inlet inlet~ int \
key keyname keyup line line~ list {list append} {list length} {list prepend} \
{list split} {list trim} loadbang log log~ lop~ makefilename makenote max max~ \
metro midiclkin midiin midiout midirealtimein min min~ mod moses mtof mtof~ \
namecanvas nbx netreceive netsend noise~ notein noteout openpanel osc~ outlet~ \
pack pgmin pgmout phasor~ pipe plot poly polytouchin polytouchout pow powtodb \
powtodb~ pow~ print qlist random readsf realtime receive receive~ rfft~ rifft~ \
rmstodb rmstodb~ route rpole~ rsqrt~ rzero_rev~ rzero~ samphold~ samplerate~ \
savepanel sel send send~ serial set setsize sig~ sin snapshot~ soundfiler spigot \
sqrt sqrt~ stripnote struct sublist swap switch~ symbol sysexin table tabosc4~ \
tabplay~ tabread tabread4 tabread4~ tabread~ tabwrite tabwrite~ tan template \
textfile threshold~ throw~ timer toggle touchin touchout trigger unpack until \
value vcf~ vd~ vline~ vradio vslider vsnapshot~ vu wrap wrap~ writesf~}


proc ::completion::init {} {
    variable external_filetype
    ::completion::read_config
    switch -- $::windowingsystem {
        "aqua"  { set external_filetype *.pd_darwin }
        "win32" { set external_filetype *.dll }
        "x11"   { set external_filetype *.pd_linux }
    }
    bind all <Tab> {+::completion::trigger}
    ::completion::add_user_externals
    ::completion::add_user_objects $::completion::config(user_objects_list)
    set ::all_externals [lsort $::all_externals]
}

# taken from kiosk-plugin.tcl by Iohannes
proc ::completion::read_config {{filename completion.cfg}} {
    if {[file exists $filename]} {
        set fp [open $filename r]
    } else {
        set filename [file join $::current_plugin_loadpath $filename]
        if {[file exists $filename]} {
            set fp [open $filename r]
        } else {
            puts "completion.cfg not found"
            return False
        }
    }
    while {![eof $fp]} {
        set data [gets $fp]
        if { [string is list $data ] } {
            if { [llength $data ] > 1 } {
                set ::completion::config([lindex $data 0]) [lindex $data 1]
            }
        }
    }
 return True
}

proc ::completion::add_user_externals {} {
    variable external_filetype
    foreach pathdir [concat $::sys_searchpath $::sys_staticpath] {
        set dir [file normalize $pathdir]
        if { ! [file isdirectory $dir]} {continue}
        foreach filename [glob -directory $dir -nocomplain -types {f} -- \
                              $external_filetype] {
            set basename [file tail $filename]
            set name [file rootname $basename]
            lappend ::all_externals $name
        }
    }
}

proc ::completion::add_user_objects {afile} {
    set filename [file join $afile]
    if {
        $afile ne ""
        && [file exists $filename]
        && [file readable $filename]
    } {
        set fl [open $filename r]
        while {[gets $fl line] >= 0} {
            if {[string index $line 0] ne "#"} {
                lappend ::all_externals $line
            }
        }
        close $fl
    }
}

proc ::completion::trigger {} {
    variable completion_empty
    if {$::current_text eq ""} {
        set ::current_text \
            [$::current_canvas itemcget $::current_tag -text]
        ::completion::trimspaces
    }
    if {$::new_object && $::current_text ne ""} {
        bind $::current_canvas <KeyRelease> {::completion::text_keys %K}
        if {![winfo exists .pop]} {
            ::completion::search
            ::completion::try_common_prefix
            set length [llength $::completions]
            set first [lindex $::completions 0]
            if {$length == 1 && $first ne $completion_empty} {
                ::completion::replace_text $first
                ::completion::popup_destroy
            }
        } {
            if {[llength $::completions] == 1} {
                ::completion::choose_selected
            } {
                ::completion::increment
            }
        }
    }
}

proc ::completion::search {{text ""}} {
    # without the arg there are some bugs when keys come from listbox
    set ::erase_text $::current_text
    if {$text ne ""} {
        set ::current_text $text
        set ::erase_text $text
    } {    
        set ::current_text \
            [$::current_canvas itemcget $::current_tag -text]
    }
    ::completion::trimspaces
    if {$::current_text ne ""} {
        # prevent wildcards ? ;# FIXME
        set ::completions [lsearch -all -inline -glob \
                               $::all_externals $::current_text*]
    } { set ::completions {} }
    ::completion::update_gui
}

proc ::completion::update_gui {} {
    ::completion::popup_draw
    ::completion::scrollbar_check
    if {$::completions == {}} { ::completion::empty }
}

proc ::completion::empty {} {
    if {[winfo exists .pop.f.lb]} {
        set ::completions {"(none)"}
        .pop.f.lb selection clear 0 end
        .pop.f.lb selection set 0
        ::completion::scrollbar_check
    }
}

proc ::completion::increment {} {
    focus .pop.f.lb
    set selected [.pop.f.lb curselection]
    set updated [expr {($selected + 1) % [llength $::completions]}]
    .pop.f.lb selection clear 0 end
    .pop.f.lb selection set $updated
    # FIXME and wrap
    .pop.f.lb yview scroll 1 units
}

# store keywords (send/receive or array)
proc ::completion_store {tag} {
    # TODO throw~/catch~
    set kind(sr) {s r send receive send~ receive~}
    set kind(arr) {tabosc4~ tabplay~ tabread tabread4 \
                         tabread4~ tabread~ tabwrite tabwrite~}
    # send/receive
    if {[regexp {^(s|r|send|receive|throw|catch)\~*\s(\S+)$} $tag \
             -> any name]} {
        set which sr
    }
    # array
    if {[regexp {^table\s(\S+)$} $tag -> name]} {
        set which arr
    }
    if {[info exists name]} {
        foreach key $kind($which) {
            if {[lsearch -all -inline -glob $::all_externals $key] eq ""} {
                lappend ::completion_keywords($which) [list $key $name]
            }
        }
    }
}

proc ::completion::choose_selected {} {
    set selected [.pop.f.lb curselection]
    ::completion::popup_destroy
    ::completion::replace_text [lindex $::completions $selected]
    set ::current_text [lindex $::completions $selected]
    set ::completions {}
    focus -force $::current_canvas
}

# keys with listbox focus
proc ::completion::lb_keys {key} {
    if {[regexp {^[a-zA-Z0-9~/\._\+]{1}$} $key]} {
        ::completion::insert_key $key; return
    }
    switch -- $key {
        "space"     { ::completion::insert_key " " } ;# search
        "Return"    { ::completion::choose_selected }
        "BackSpace" { ::completion::chop } ;# search
    }
}

# keys from textbox
proc ::completion::text_keys {key} {
    switch -- $key {
        "plus"   { set key "+" }
        "minus"   { set key "-" }
        "Escape" { ::completion::popup_destroy 1 }
    }
    if {[regexp {^[a-zA-Z0-9~/\._\+\-\*]{1}$} $key]} {
        ::completion::search
    } elseif {$key eq "space"} {
        ::completion::search
    } elseif {$key eq "BackSpace"} {
        after 10; ::completion::search ;# FIXME
    } elseif {$key eq "Return"} {
        if {[winfo exists .pop]} {
            ::completion::choose_selected
        } {
            ::completion::text_unedit
        }
    }
}

proc ::completion::insert_key {key} {
    scan $key %c keynum
    pdsend "pd key 1 $keynum 0"
    append ::current_text $key
    # for some reason this does not work without passing the arg
    ::completion::search $::current_text
    focus -force $::toplevel
    focus -force $::current_canvas ;# FIXME
    pdtk_text_editing $::toplevel $::current_tag 1
}

proc ::completion::popup_update_selection {inc} {
    set newsel [expr {[.pop.lb curselection] + $inc}]
    set newsel [expr {[expr {$newsel<0}]?0:$newsel}]
    .pop.lb selection clear [.pop.lb curselection]
    .pop.lb selection set $newsel
    # boring hack: keep cursor at the end of textbox
    $::current_canvas icursor $::current_tag 80
}

proc ::completion::erase_text {} {
    # simulate backspace keys
    set i [expr {[string length $::erase_text] + 2}] ;# FIXME
    while {--$i > 0} {
        pdsend "$::toplevel key 1 8 0"
        pdsend "$::toplevel key 0 8 0"
        incr i -1
    }
}

# replace text from object box
proc ::completion::replace_text {args} {
    set text ""
    ::completion::erase_text
    # in case of spaces
    foreach arg $args { set text [concat $text $arg] }
    for {set i 0} {$i < [string length $text]} {incr i 1} {
        set cha [string index $text $i]
        scan $cha %c keynum
        pdsend "pd key 1 $keynum 0"
    }
    # to be able to erase it later
    set ::erase_text $text
}

proc ::completion::text_unedit {} {
    set x [expr {$::editx - 2}]
    set y [expr {$::edity - 2}]
    ::completion::mouse $x $y
    set x [expr {$::editx + 2}]
    ::completion::mouseup $x $y
    pdtk_text_editing $::toplevel $::current_tag 0
    set ::new_object 0
}

proc ::completion::chop {} {
    pdsend "$::toplevel key 1 8 0" ;# BackSpace
    pdsend "$::toplevel key 0 8 0"
    set ::current_text [string replace $::current_text end end]
    ::completion::search $::current_text
    if {[winfo exists .pop]} {
        .pop.f.lb selection clear 0 end
        .pop.f.lb selection set 0
    }
    focus -force $::current_canvas
}

proc ::completion::popup_draw {} {
    if {![winfo exists .pop]} {
        set menuheight 32
        if {$::windowingsystem ne "aqua"} { incr menuheight 24 }
        set geom [wm geometry $::toplevel]
        # fix weird bug on osx
        set decoLeft 0
        set decoTop 0
        regexp -- {([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)} $geom -> \
            width height decoLeft decoTop
        set left [expr {$decoLeft + $::editx}]
        set top [expr {$decoTop + $::edity + $menuheight}]

        catch { destroy .pop }
        toplevel .pop
        wm overrideredirect .pop 1
        wm geometry .pop +$left+$top
        frame .pop.f

        pack configure .pop.f
        .pop.f configure -relief solid -borderwidth 1 -background white

        listbox .pop.f.lb \
            -selectmode browse -height $::completion::config(lines) \
            -listvariable ::completions -activestyle none \
            -highlightcolor $::completion::config(fg) \
            -selectbackground $::completion::config(bg) \
            -selectforeground $::completion::config(fg) -width 24 \
            -yscrollcommand [list .pop.f.sb set] -takefocus 0

        pack .pop.f.lb -side left -expand 1 -fill both
        .pop.f.lb configure -relief flat \
            -font [list $::completion::config(font) $::completion::config(font_size)]
        .pop.f.lb selection set 0 0

        pack .pop.f.lb [scrollbar ".pop.f.sb" -command [list .pop.f.lb yview]] \
            -side left -fill y -anchor w
        bind .pop.f.lb <Escape> \
            {after idle { ::completion::popup_destroy 1 }}
        bind .pop.f.lb <KeyRelease> {::completion::lb_keys %K}
        bind .pop.f.lb <ButtonRelease> {after idle {::completion::choose_selected}}
        focus .pop.f.lb
    }
}

proc ::completion::popup_destroy {{unbind 0}} {
    catch { destroy .pop }
    focus -force $::current_canvas
    if {$unbind} {
        bind $::current_canvas <KeyRelease> {}
    }
}

proc ::completion::scrollbar_check {} {
    if {[winfo exists .pop]} {
        if {[llength $::completions] < $::completion::config(lines)} {
            pack forget .pop.f.sb
        } else {
            pack .pop.f.sb -side left -fill y
        }
    }
}

proc ::completion::mouse {x y} {
    pdsend "$::toplevel mouse [$::current_canvas canvasx $x] [$::current_canvas canvasy $y] 1 0"
}

proc ::completion::mouseup {x y} {
    pdsend "$::toplevel mouseup [$::current_canvas canvasx $x] [$::current_canvas canvasy $y] 1"
}

###########################################################
# overwritten

proc pdtk_text_editing {mytoplevel tag editing} {
    set ::toplevel $mytoplevel
    set tkcanvas [tkcanvas_name $mytoplevel]
    set rectcoords [$tkcanvas bbox $tag]
    if {$rectcoords ne ""} {
        set ::editx  [expr {int([lindex $rectcoords 0])}]
        set ::edity  [expr {int([lindex $rectcoords 3])}]
    }
    if {$editing == 0} {
        selection clear $tkcanvas
        # completion
        set ::completions {}
        catch { destroy .pop }
	# TODO
        #::completion_store $::current_text
    } {
        set ::editingtext($mytoplevel) $editing
        # completion
        set ::current_canvas $tkcanvas
        if {$tag ne ""} {
            # unbind Keys if new object
            if {$tag ne $::current_tag} {
                bind $::current_canvas <KeyRelease> {}
            }
            set ::current_tag $tag
        }
    }
    set ::new_object $editing
    $tkcanvas focus $tag
}

proc ::dialog_font::ok {gfxstub} {
    variable fontsize
    apply $gfxstub $fontsize
    cancel $gfxstub
    # completion
    set ::completion::config(font_size) [expr {$fontsize - 1}];# linux only ?
}

############################################################
# utils

# `prefix' from Bruce Hartweg <http://wiki.tcl.tk/44>
proc ::completion::prefix {s1 s2} {
    regexp {^(.*).*\0\1} "$s1\0$s2" all pref
    return $pref
}

proc ::completion::try_common_prefix {} {
    set prefix [::completion::common_prefix]
    if {$prefix ne $::current_text && $prefix ne ""} {
        ::completion::replace_text $prefix
        # prevent errors in pdtk_text_editing
        catch { focus .pop.f.lb }
        set ::current_text $prefix
        set found 1
    }
}

proc ::completion::common_prefix {} {
    set prefix ""
    if {[llength $::completions] > 1} {
        set prefix [::completion::prefix \
                        [lindex $::completions 0] \
                        [lindex $::completions end]]
    }
    return $prefix
}

proc ::completion::trimspaces {} {
    set ::current_text [string trimright $::current_text " "]
}

###########################################################
# main

::completion::init