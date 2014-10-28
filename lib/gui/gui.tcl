#-----------------------------------------------------------------------
# TITLE:
#	gui.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Main file for the gui package.  This package contains
#	reusable GUI components written for the Notebook application.
#
#-----------------------------------------------------------------------

package provide gui 1.0

package require BWidget 1.9

namespace eval ::gui:: {
    variable library [file dirname [info script]]
    variable defaultBackground [. cget -background]

    namespace export actionmanager
    namespace export assert
    namespace export hasbinding
    namespace export require
    namespace export rotext
    namespace export searchentry
    namespace export statusentry
    namespace export tooltip
    namespace export windowmanager
    namespace export windowmenu
}

#-----------------------------------------------------------------------
# Widget Tweaks for all windowing systems

# Menu widget
option add *Menu.tearOff no

#-----------------------------------------------------------------------
# Widget Tweaks for X11

if {[tk windowingsystem] eq "x11"} {
    # On X11, there are quite a few widget option tweaks we'd like to 
    # do.
    
    # Text widgets
    option add *Text.background        white
    option add *Text.foreground        black
    option add *Text.selectBorderWidth 0

    # Scrollbar widgets
    option add *Scrollbar.activeBackground $::gui::defaultBackground

    # Button widgets
    option add *Button.activeBackground $::gui::defaultBackground
    option add *Button.borderWidth      1

    # Menu widgets
    option add *Menu.activeBackground  "dark blue"
    option add *Menu.activeForeground  white
    option add *Menu.activeBorderWidth 0
    option add *Menu.borderWidth       1

    # Entry widgets
    option add *Entry.background        white
    option add *Entry.foreground        black
    option add *Entry.selectBorderWidth 0
}

#-----------------------------------------------------------------------
# Widget Tweaks for Mac OS X

if {[tk windowingsystem] eq "aqua"} {
    bind Listbox <Command-1>  [bind Listbox <Control-1>]
}



#-----------------------------------------------------------------------
# Virtual Event Definitions

# Cut, Copy, Paste, Undo, Redo

if {[tk windowingsystem] eq "x11"} {
    # On X11, we want the standard win32 keybindings for cut, copy, paste,
    # undo, and redo to work throughout.  So make those keybindings generate
    # the relevant virtual events.
    #
    # 4/28/05: Make sure both upper and lower case work the same.

    event add <<Cut>>   <Control-x>
    event add <<Cut>>   <Control-X>
    event add <<Copy>>  <Control-c>
    event add <<Copy>>  <Control-C>
    event add <<Paste>> <Control-v>
    event add <<Paste>> <Control-V>
    event add <<Undo>>  <Control-z>
    event add <<Undo>>  <Control-Z>

    # Note that <Control-Key-Z> is already defined as <<Redo>>,
    # mean <Control-Shift-Z>; I need to get rid of that, or <Control-Z>
    # won't work for <<Undo>>
    event delete <<Redo>>

    # On X11, <<Redo>> should be <Control-Shift-z>.  Provide it in
    # both flavors.
    event add <<Redo>>  <Control-Shift-z>
    event add <<Redo>>  <Control-Shift-Z>

    # In text widgets, the Control-v key can be bound to something else on
    # X11.  So explicitly unbind it.
    bind Text <Control-Key-v> ""
} elseif {[tk windowingsystem] eq "win32"} {
    # On Windows, we want the uppercase version of control keys to
    # work just like the lower case.  So add them all.  Include
    # the regular ones, just to be explicit.

    event add <<Cut>>   <Control-x>
    event add <<Cut>>   <Control-X>
    event add <<Copy>>  <Control-c>
    event add <<Copy>>  <Control-C>
    event add <<Paste>> <Control-v>
    event add <<Paste>> <Control-V>
    event add <<Undo>>  <Control-z>
    event add <<Undo>>  <Control-Z>
    event add <<Redo>>  <Control-y>
    event add <<Redo>>  <Control-Y>
} elseif {[tk windowingsystem] eq "aqua"} {
    # On Mac OS X, we want the uppercase version of control keys to
    # work just like the lower case.  So add them.

    event add <<Cut>>   <Command-x>
    event add <<Cut>>   <Command-X>
    event add <<Copy>>  <Command-c>
    event add <<Copy>>  <Command-C>
    event add <<Paste>> <Command-v>
    event add <<Paste>> <Command-V>
    event add <<Undo>>  <Command-z>
    event add <<Undo>>  <Command-Z>

    # Tk.tcl erroneously adds Command-y for <<Redo>>;
    # get rid of it before adding the correct keys.
    event delete <<Redo>>

    event add <<Redo>>  <Command-Shift-z>
    event add <<Redo>>  <Command-Shift-Z>
}


#-----------------------------------------------------------------------
# GUI Component Definitions

source [file join $::gui::library misc.tcl]
source [file join $::gui::library icon.tcl]
source [file join $::gui::library actionmanager.tcl]
source [file join $::gui::library windowmanager.tcl]
source [file join $::gui::library statusentry.tcl]
source [file join $::gui::library searchentry.tcl]
source [file join $::gui::library rotext.tcl]
source [file join $::gui::library tooltip.tcl]

