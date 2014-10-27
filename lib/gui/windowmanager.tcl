#-----------------------------------------------------------------------
# TITLE:
#	windowmanager.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       notebook-gui component: manages multiple toplevel windows so that
#	the when the last one is destroyed, the application termiantes.
#
#	To participate, toplevel windows register with the windowmanager
#	on creation.  A WM_DELETE_WINDOW handler is created automatically.
#	If a registered toplevel window wishes to destroy itself, it must
#	call "windowmanager destroy $win", which will in turn destroy the
#	window.
#
#	windowmanager doesn't withdraw "."; the application must do that
#	for itself.
#
#-----------------------------------------------------------------------

# windowmanager is a snit::type used as a singleton.

snit::type ::gui::windowmanager {
    pragma -hasinstances no
    pragma -hastypedestroy no
    
    #-------------------------------------------------------------------
    # Type Variables

    # Tracks the open windows.  When all are closed, the
    # program is terminated.
    typevariable windowList

    #-------------------------------------------------------------------
    # typemethods

    # Shadow the default create method
    typemethod create {args} {
        error "invalid method"
    }

    # register a new window
    typemethod register {window} {
        lappend windowList $window

        wm protocol $window WM_DELETE_WINDOW [list $type destroy $window]
    }
    
    # destroy a window
    typemethod destroy {window} {
        set ndx [lsearch -exact $windowList $window]

        if {$ndx == -1} {
            error "can't destroy '$window': not registered with windowmanager"
        }

        set windowList [lreplace $windowList $ndx $ndx]

        destroy $window

        if {[llength $windowList] == 0} {
            exit 0
        }
    }

    # Return the list of windows
    typemethod windows {} {
        return $windowList
    }

    # Raise the named window
    typemethod raise {window} {
        raise $window
        wm deiconify $window
    }
}

