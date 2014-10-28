#-----------------------------------------------------------------------
# TITLE:
#	userprefs.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Notebook application user preferences.
#
# LICENSE:
#       Copyright (C) 2002,2003,2004,2005 by William H. Duquette.  
#       This file may be used subject to the terms in license.txt.

package require Tk

#-----------------------------------------------------------------------
# UserPrefs

# prefs could be implemented as an ensemble: a type with no instances but
# only typemethods.  For historical reasons, though, it's been 
# implemented as a normal type with just one instance.
snit::type ::Notebook::prefsmanager {
    # Preferences array
    variable prefs

    # Observers array.  index is observer name, value is command to execute.
    variable observers

    # System font lists
    variable fonts

    # Pseudo-preferences
    #
    # Pseudo-preferences aren't saved to the preferences file.
    variable pseudoprefs {
        defaultscaling
    }

    constructor {} {
        # Scaling Preference
        set prefs(defaultscaling) [tk scaling]
        set prefs(scaling)        [tk scaling]

        # Font preferences
        set prefs(bodytext)    {Times 12}
        set prefs(monotext)    {Courier 10}
        set prefs(header1text) {Helvetica 16 bold}
        set prefs(header2text) {Helvetica 14 bold}
        set prefs(header3text) {Helvetica 12 bold}
        set prefs(titletext)   {Helvetica 20}
        set prefs(smalltext)   {Helvetica 8}

        # Color preferences
        set prefs(editorfg)  black
        set prefs(editorbg)  white
        set prefs(normalfg)  black
        set prefs(normalbg)  white
        set prefs(prefg)     black
        set prefs(prebg)     white
        set prefs(tclfg)     black
        set prefs(tclbg)     white
        set prefs(titlefg)   blue
        set prefs(titlebg)   white
        set prefs(linkfg)    blue
        set prefs(linkbg)    white
        set prefs(buttonfg)  magenta
        set prefs(buttonbg)  white
        set prefs(warningfg) red
        set prefs(warningbg) white
        set prefs(searchfg)  white
        set prefs(searchbg)  red

        # Editor preferences
        set prefs(tabwidth)   4
        set prefs(autowrap)   1
        set prefs(wrapcolumn) 74
        set prefs(autoindent) 1

        # Tcl/Tk Preferences
        set prefs(extpath) {}

        # Miscellaneous Options
        set prefs(includetour)       1
        set prefs(editbottom)        0
        set prefs(displaydirectives) 0
        set prefs(silentcreation)    0
        set prefs(showsidebar)       0
        set prefs(incrementalsearch) 1
        set prefs(contentsearch)     1

        # Initialize font lists
        set fonts(all) {}
        set fonts(mono) {}
        set fonts(prop) {}
    }

    # Register observer.  obj is the observing object; command is the
    # command to execute when preferences are saved.
    method register {obj command} {
        set observers($obj) $command
    }

    # Unregister observer.  obj is the observing object.
    method unregister {obj} {
        unset observers($obj)
    }

    # Set a preference variable's value
    method set {var value} {
        # HACK: handle translation of "headertext" to "header[123]text"
        # This handles a preferences change in V2.1.1
        if {$var eq "headertext"} {
            $self set header1text $value
            $self set header2text $value
            $self set header3text $value
            return
        }

        # Retain and save unknown preferences; this means they can
        # switch between this version and a later version with more
        # preferences and not have any trouble.
        set prefs($var) $value
    }

    # Get a preference variable's value
    method get {var} {
        if {[info exists prefs($var)]} {
            return $prefs($var)
        } else {
            error "Unknown prefs variable: '$var'"
        }
    }

    # Load the preferences from disk.  The file name is system-dependent.
    method load {} {
        set fname [PrefFileName]

        if {[file exists $fname]} {
            try {
                source [PrefFileName]
                tk scaling $prefs(scaling)
            } catch -msg errmsg {
                msg "Error in user preferences file '$fname'; preferences might not be set.  The error was: $errmsg"
            }
        }
    }

    # Save the preferences and notify observers.
    method save {} {
        try {
            set f [open [PrefFileName] w]

            puts $f "# Notebook [version] Preferences File"
            foreach name [array names prefs] {
                if {[lsearch -exact $pseudoprefs $name] != -1} {
                    continue
                }
                puts $f [list prefs set $name $prefs($name)]
            }
            puts $f "# End of preferences"
            close $f
        } catch -msg errmsg {
            msg "Could not save user preferences to [PrefFileName]: $errmsg"
        }

        $self NotifyObservers
    }

    # Pop up the preferences dialog; create it if it hasn't yet been
    # seen.
    method dialog {} {
        # Create the dialog, if one doesn't exist.
        if {"" == [info commands .prefsdialog]} {
            ::Notebook::prefsdialog .prefsdialog
        }

        # Make sure it's visible.
        .prefsdialog show
    }

    # Return a list of monospace fonts defined by the system.
    method monofonts {} {
        $self LoadFonts
        return $fonts(mono)
    }

    # Return a list of proportional fonts defined by the system.
    method propfonts {} {
        $self LoadFonts
        return $fonts(prop)
    }

    # Return a list of *all* fonts defined by the system.
    method fonts {} {
        $self LoadFonts
        return $fonts(all)
    }

    #-----------------------------------------------------------------------
    # Private methods and procs 

    # Determine the preference file name based on the platform
    proc PrefFileName {} {
        global tcl_platform
        global env

        # This is the only way to reference Tcl/Tk Aqua as opposed to
        # the X11 version
        if {[tk windowingsystem] eq "aqua"} {
            return [file join $env(HOME) "Library/Preferences/NotebookPrefs"]
        }

        switch $tcl_platform(platform) {
            "macintosh" {
                # This is classic Mac only
                return [file join $env(PREF_FOLDER) "Notebook Preferences"]
            }
            "windows" {
                if {[info exists env(HOME)]} {
                    return [file join $env(HOME) "notebook.cfg"]
                } else {
                    return [file join "C:/" "notebook.cfg"]
                }
            }
            "unix" -
            default {
                if {[info exists env(DOTDIR)]} {
                    return "$env(DOTDIR)/.notebookrc"
                } else {
                    return "$env(HOME)/.notebookrc"
                }
            }
        }
    }

    # Notify all registered observers that preferences have changed.
    method NotifyObservers {} {
        foreach name [array names observers] {
            uplevel #0 $observers($name)
        }
    }

    # Load system fonts, if they've not already been loaded.
    method LoadFonts {} {
        if {[llength $fonts(all)] != 0} {
            return
        }

        # Get all fonts.
        set fontnames [font families]

        # Tcl defines these names on all platforms, so add them to list
        # if they aren't already there.
        foreach name {Courier Times Helvetica} {
            if {[lsearch $fontnames $name] == -1} {
                lappend fontnames $name
            }
        }

        # On Tcl/Tk Aqua there are some problematic font names;
        # they all begin with non-alpha characters.
        foreach font $fontnames {
            set initial [string index $font 0]
            if {![string is alpha $initial]} {
                continue
            }

            lappend fonts(all) $font
        }
    
        set fonts(all) [lsort $fonts(all)]

        # Create lists of monospace and proportional fonts.
        foreach font $fonts(all) {
            if {[font metrics [list $font] -fixed]} {
                lappend fonts(mono) $font
            } else {
                lappend fonts(prop) $font
            }
        }
    }
}

# Create one instance of this object.
::Notebook::prefsmanager create ::Notebook::prefs

namespace eval ::Notebook:: {
    namespace export prefs
}


