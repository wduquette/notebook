#-----------------------------------------------------------------------
# TITLE:
#	welcomer.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       This component is created if Notebook is invoked
# 	with no file name.  It welcomes the user to Notebook and allows
#	them to open or create a notebook file.  As such, it's a baby
#	version of a notebookbrowser.  I'll duplicate the action and
#	menu code for now; but ultimately that will need to be fixed.
#
# LICENSE:
#       Copyright (C) 2003 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

snit::widget welcomer {
    # This is a toplevel window
    hulltype toplevel
    delegate option * to hull

    #-------------------------------------------------------------------
    # Options

    # An error stating why the welcomer was used.
    option -errormsg ""

    #-------------------------------------------------------------------
    # Instance Variables

    variable greeting {
        |Click on the highlighted text to:
        |
        |* [%Open|open-notebook%] an existing notebook.
        |* [%Create|new-notebook%] a new notebook
        |* [%Browse|help-introduction%] the on-line help.
        |
        |If you've never used Notebook before, then you'll want to
        |[%create|new-notebook%] a new notebook.  It will be created 
        |with an initial set of pages that will tell you
        |the things you need to know to get started.
    }

    #-------------------------------------------------------------------
    # Components

    variable am         ;# The actionmanager
    variable status     ;# The statusentry
    variable render     ;# The renderpane

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        #---------------------------------------------------------------
        # Preliminaries

        # FIRST, withdraw the window, so they don't see it building.
        wm withdraw $win

        # NEXT, set the window title
        wm title $win "Welcome to Notebook"

        # NEXT, Go ahead and configure the widget options, if any; none are
        # delegated to anything but the hull.
        $self configurelist $args

        # NEXT, prepare for window closing
        windowmanager register $win

        #---------------------------------------------------------------
        # Create Components

        # FIRST, create the actionmanager and define the actions.
        install am using nbactionmanager %AUTO% \
            -toplevel $win \
            -windowtype welcomer \
            -errorcommand [mymethod ErrorHandler]

        # NEXT, create the statusentry.  It provides a GUI for displaying
        # status and entering arguments.
        install status using statusentry $win.status \
            -errorcommand [mymethod ErrorHandler] \
            -messagecommand [list messagelog logmessage]

        # NEXT, create the renderpane for the welcome message
        install render using renderpane $win.render \
            -buttoncommand [mymethod ButtonHandler] \
            -width 45 \
            -height 20

        # Next, pack the components
        pack $status -side bottom -fill x -expand false
        pack $render -side top -fill both -expand true

        #---------------------------------------------------------------
        # Render the welcome message

        regsub -all -line {^\s*\|} [string trim $greeting] {} greeting
        $render render "Welcome to Notebook!" $greeting

        #---------------------------------------------------------------
        # Final Preparations

        # NEXT, update the state of all actions.
        $am updatestate

        # NEXT, The GUI is fully created; display it!
        # 
        # We call "update" to make sure that everything has taken its final 
        # size before we deiconify.
        update
        wm deiconify $win

        # NEXT, if there's an error message, display it.
        if {$options(-errormsg) ne ""} {
            $status msg $options(-errormsg)
        }
    }

    #-------------------------------------------------------------------
    # Private Methods
 
    method ButtonHandler {action} {
        $am invoke $action
    }

    # Called when the welcomer's work is done.
    method Withdraw {} {
        wm withdraw $win

        # TBD: Is the "after 1" really necessary?
        after 1 [list windowmanager destroy $win]
    }

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


    #-------------------------------------------------------------------
    # Delegate Action Handlers

    delegate method about-notebook         to am
    delegate method close-window           to am
    delegate method copy-string            to am
    delegate method cut-string             to am
    delegate method edit-preferences       to am
    delegate method help-on                to am
    delegate method help-introduction      to am
    delegate method help-index             to am
    delegate method help-on-actions        to am
    delegate method help-on-commands       to am
    delegate method help-on-markup         to am
    delegate method notebook-license       to am
    delegate method notebook-release-notes to am
    delegate method paste-string           to am
    delegate method redo-change            to am
    delegate method request-action         to am
    delegate method undo-change            to am
    delegate method show-version           to am

    #-------------------------------------------------------------------
    # Action Handlers
    #
    # These methods are registered as actions with the actionmanager
    # component.  Actions can be invoked by typing their names into the
    # statusentry widget, or programmatically; they can get input
    # from the user via the statusentry widget.
    #
    # When actions are invoked programmatically, none or all of their
    # arguments can be specified programmatically; the action will prompt
    # for the remaining arguments.
    #
    # When called programmatically, the action's state is NOT checked.
    # Thus, every action must explicitly check the same conditions as
    # its -statecommand, giving a good USER error if they are not met.
    #
    # Every action has a handler with the same name.  In some cases,
    # this handler implements the entire action.  For actions that have
    # arguments, it's usual to implement the handler as two methods.
    # The first has the usual name, and will do the following:
    #
    # * Require any conditions for execution of the action that do not
    #   depend on the argument values.
    #
    # * Request the arguments, passing control to the second command when
    #   they've been entered.
    #
    # * The second method simply takes the arguments and does what's
    #   necessary.  The second method is not intended to be called by
    #   anyone but the first method; it's called "Do-<action name>",
    #   and should follow immediately after the first method.


    # Action: new-notebook
    #
    # Creates a new notebook file and opens it, prompting for the file
    # name
    method new-notebook {} {
        $am new-notebook

        # On success the welcomer isn't needed anymore.
        $self Withdraw
    }

    # Action: open-notebook
    #
    # Opens a notebook file in the page browser, replacing the
    # existing notebook. 

    method open-notebook {} {
        $am open-notebook

        # On success the welcomer isn't needed anymore.
        $self Withdraw
    }
}
