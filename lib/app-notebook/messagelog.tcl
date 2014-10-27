#-----------------------------------------------------------------------
# TITLE:
#	messagelog.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       This window is created at application start-up, but is immediately
#	withdrawn.  It contains a scrolling log of all messages written
#	to any statusentry in the program, along with all unexpected
#	stack traces.
#
# LICENSE:
#       Copyright (C) 2003 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

snit::widget messagelog {
    # This is a toplevel window
    hulltype toplevel
    delegate option * to hull

    #-------------------------------------------------------------------
    # Type Methods

    typemethod init {} {
        messagelog .messagelog
    }

    typemethod logmessage {text} {
        .messagelog logmessage $text
    }

    typemethod logerror {msg einfo ecode} {
        .messagelog logerror $msg $einfo $ecode
    }

    typemethod show {} {
        wm deiconify .messagelog
        raise .messagelog
    }

    #-------------------------------------------------------------------
    # options

    # Number of lines to retain.
    option -maxlines 200

    #-------------------------------------------------------------------
    # Components

    variable am     
    variable status 
    variable log    

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        #---------------------------------------------------------------
        # Preliminaries

        # FIRST, withdraw the window; we'll bring it back when the
        # want to see it.
        wm withdraw $win

        # NEXT, set the window title
        wm title $win "Notebook: Message Log"

        # NEXT, Go ahead and configure the widget options, if any; none are
        # delegated to anything but the hull.
        $self configurelist $args

        # NEXT, prepare for window closing
        wm protocol $win WM_DELETE_WINDOW [list wm withdraw $win]

        #---------------------------------------------------------------
        # Create Components

        # FIRST, create the actionmanager and define the actions.
        install am using nbactionmanager %AUTO% \
            -toplevel $win \
            -windowtype messagelog \
            -errorcommand [mymethod ErrorHandler]

        # NEXT, create the statusentry.  It provides a GUI for displaying
        # status and entering arguments.
        install status using statusentry $win.status \
            -errorcommand [mymethod logerror] \
            -messagecommand [mymethod logmessage]


        # NEXT, create the rotext pane.
        install log using rotext $win.text \
            -yscrollcommand "$win.scroll set" \
            -width 80 \
            -height 24 \
            -foreground black \
            -background white \
            -highlightthickness 0

        $log tag configure errortext \
            -foreground darkred

        scrollbar $win.scroll \
            -command "$win.text yview"

        # Next, pack the components
        pack $status -side bottom -fill x -expand false
        pack $win.scroll -side right -fill y -expand false
        pack $log -side top -fill both -expand true

        # Add better navigation keys
        bind $win <Key-Down>  [list $log yview scroll  1 units]
        bind $win <Key-Up>    [list $log yview scroll -1 units]
        bind $win <Key-Next>  [list $log yview scroll  1 pages]
        bind $win <Key-Prior> [list $log yview scroll -1 pages]

        # NEXT, update the action state now that everything's created.
        $am updatestate
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Handles errors from the statusentry and actionmanager components.
    method ErrorHandler {msg einfo ecode} {
        if {$ecode eq "USER"} {
            $status msg $msg
            bell
        } else {
            messagelog logerror $msg $einfo $ecode

            $status msg "$msg -- go to Message Log for more."
        }
    }

    # Truncates the log if it gets too long.
    method Truncate {} {
        $log del $options(-maxlines).0 end
    }

    #-----------------------------------------------------------------------
    # Public Methods

    # Log an error.
    method logerror {msg einfo ecode} {
        $log ins 1.0 "\n$einfo\n\n" errortext
        $log see 1.0
        $log mark set insert 1.0
        
        $self Truncate
        bell
    }

    # Log a normal message
    method logmessage {msg} {
        if {$msg ne ""} {
            $log ins 1.0 "$msg\n"
            $log see 1.0
            $log mark set insert 1.0

            $self Truncate
        }
    }

    #-------------------------------------------------------------------
    # Non-Delegated Action Handlers

    # Action: close-window
    method close-window {} {
        wm withdraw $win
    }

    #-------------------------------------------------------------------
    # Delegated Action Handlers

    delegate method about-notebook         to am
    delegate method copy-string            to am
    delegate method cut-string             to am
    delegate method edit-preferences       to am
    delegate method help-on                to am
    delegate method help-introduction      to am
    delegate method help-index             to am
    delegate method help-on-actions        to am
    delegate method help-on-commands       to am
    delegate method help-on-markup         to am
    delegate method new-notebook           to am
    delegate method notebook-license       to am
    delegate method notebook-release-notes to am
    delegate method open-notebook          to am
    delegate method paste-string           to am
    delegate method redo-change            to am
    delegate method request-action         to am
    delegate method undo-change            to am
    delegate method show-version           to am
}

