#-----------------------------------------------------------------------
# TITLE:
#       pageviewer.tcl
#
# AUTHOR:
#       Will Duquette
#
# DESCRIPTION:
#       A viewer for browsing Notebook pages.
#
# LICENSE:
#       Copyright (C) 2005 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

snit::widget pageviewer {
    #-------------------------------------------------------------------
    # Creation Options
    #
    # These options should only be set at creation time.  This isn't
    # enforced, so be careful

    # 1 if we're read-only, and 0 otherwise.
    option -readonly 0

    # A command to use for outputting messages.  The message will be
    # appended.
    option -messagecommand {}

    # The notebook file directory, used as the root for relative paths.
    option -dbdir {}

    #-------------------------------------------------------------------
    # Other options

    # A command that's called when the displayed page changes. The
    # command gets one argument, the page name.
    option -pagecommand {}

    # A command that's called when we try to display a page that
    # doesn't exist.
    option -unknowncommand {}

    #-------------------------------------------------------------------
    # Components

    # The toplevel window (the notebookbrowser)
    variable top
    
    # The renderpane is the component that actually displays the
    # rendered page.
    variable rp

    #--------------------------------------------------------------------
    # Other variables

    # The history list is a list of {PageName PagePos} pairs.
    variable history {}

    # The histPos is the index of the currently displayed page in the
    # history list.  It's initially -1 because there's nothing in the
    # list.
    variable histPos -1

    # A list of recently displayed pages.  Each page appears only once,
    # regardless of how often (and where) it appears in the history list.
    # There will be ten pages listed, maximum; no more than one of them 
    # are guaranteed to still exist.
    variable recentPages {}

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Get the toplevel widget
        set top [winfo toplevel $win]

        # As yet we have no option delegation, so go ahead and get the
        # args
        $self configurelist $args

        # Create the renderpane.
        install rp using renderpane $win.rp \
            -yscrollcommand "$win.scroll set" \
            -querycommand      [list $top pageexists] \
            -titlecommand      [mymethod TitleHandler] \
            -linkcommand       [mymethod LinkHandler] \
            -buttoncommand     [mymethod ButtonHandler] \
            -macroerrorcommand [mymethod MacroErrorHandler] \
            -messagecommand    $options(-messagecommand) \
            -dbdir             $options(-dbdir)

        scrollbar $win.scroll \
            -command "$win.rp yview"

        # Pack them in.
        pack $win.scroll  -side right -fill y    -expand false
        pack $rp          -side top   -fill both -expand true

        #---------------------------------------------------------------
        # User Interactions

        # Add the pageviewer window itself to the renderpane's bindtags,
        # so that keys bound to the pageviewer will take effect when the
        # renderpane has focus
        set tags [bindtags $rp]
        lappend tags $win
        bindtags $rp $tags

        # Go to the previous page when <BackSpace> is pressed.
        bind $rp <BackSpace> [list $self backpage]

        # User Menu.
        menu $rp.user -tearoff no -postcommand [mymethod PostUserMenu]

        $rp.user add command -label "User Menu"
        $rp.user add separator
        $rp.user add command -label "Dummy"

        bind $rp <Control-1> [list tk_popup $rp.user %X %Y 2]
        bind $rp <3>         [list tk_popup $rp.user %X %Y 2]

        # Recent Pages Menu.
        menu $rp.recent -tearoff no -postcommand [mymethod PostRecent]

        $rp.recent add command -label "Recent Pages"
        $rp.recent add separator
        $rp.recent add command -label "Dummy"

        bind $rp <Shift-1> [list tk_popup $rp.recent %X %Y 2]

        #---------------------------------------------------------------
        # Prepare to receive preferences events; unregister on 
        # destroy.
        prefs register $selfns [mymethod UsePreferences]
    }

    destructor {
        catch {prefs unregister $selfns}
    }

    method UsePreferences {} {
        # Update the display when the preferences change.
        $self showpage
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method searchfor to rp

    # Returns the name of the currently displayed page, or "" if none.
    # Note that during a deletion or page renaming the named page
    # is not guaranteed to exist.
    method current {} {
        return [lindex $history $histPos 0]
    }

    # Tells the pageviewer to take the keyboard focus.
    # If -friendly, we take the focus only if our toplevel already
    # has it (e.g., we take the focus back from the search box).
    method focus {{option {}}} {
        set focusWin [focus]

        if {$focusWin eq ""} {
            return
        }

        if {$option ne "-friendly" || 
            [winfo toplevel $win] eq [winfo toplevel $focusWin]} {
            focus $rp
        }
    }

    # Shows the named page.  The -unknowncommand is called if the
    # page doesn't exist.
    method showpage {{name ""}} {
        # FIRST, remember the position for the page we're showing now.
        if {$histPos >= 0} {
            lset history $histPos 1 [$self GetPos]
        }

        # NEXT, default to the current page.
        if {$name eq ""} {
            set name [$self current]

            if {$name eq ""} {
                error "no current page."
            }
        }

        # NEXT, if the page doesn't exist, call the -unknowncommand.
        if {![$top pageexists $name]} {
            if {$options(-unknowncommand) ne {}} {
                set command $options(-unknowncommand)
                lappend command $name
                uplevel \#0 $command
            } else {
                $return -code error -errorcode USER "No such page: '$name'"
            }

            return
        }

        # NEXT, save the new page in the history list.  When we show
        # a new page, any pages forward of our position go away.
        set history [lrange $history 0 $histPos]
        lappend history [list [$top pagename $name] 0]
        incr histPos

        # NEXT, display it.
        $self DisplayPage
    }

    # Steps back one page, if possible
    method backpage {} {
        # FIRST, remember the position for the page we're showing now.
        if {$histPos >= 0} {
            lset history $histPos 1 [$self GetPos]
        }

        # NEXT, Look back through the history list for a page that exists,
        # and is also different than the current page.
        set current [lindex $history $histPos 0]
        set pos [expr {$histPos - 1}]

        while {$pos >= 0} {
            set candidate [lindex $history $pos 0]

            if {[$top pageexists $candidate]} {

                if {![string equal -nocase $candidate $current]} {
                    break
                }
            }

            incr pos -1
        }

        if {$pos < 0} {
            bell
            return
        }

        set histPos $pos

        $self DisplayPage
    }

    # Steps forward one page, if possible
    method forwardpage {} {
        # FIRST, remember the position for the page we're showing now.
        if {$histPos >= 0} {
            lset history $histPos 1 [$self GetPos]
        }

        # NEXT, Look forward through the history list for a page that exists,
        # and is also different than the current page.
        set current [lindex $history $histPos 0]
        set pos [expr {$histPos + 1}]
        set len [llength $history]

        while {$pos < $len} {
            set candidate [lindex $history $pos 0]

            if {[$top pageexists $candidate]} {

                if {![string equal -nocase $candidate $current]} {
                    break
                }
            }

            incr pos
        }

        if {$pos >= $len} {
            bell
            return
        }

        set histPos $pos

        $self DisplayPage
    }

    # Shows the page from the beginning of the Recent Pages list, if it exists.
    method cyclerecent {} {
        foreach id $recentPages {
            if {[$top pageexists $id]} {
                $self showpage $id
                break
            }
        }
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Display the current page
    method DisplayPage {} {
        # FIRST, Get the current page specs
        set name [$top pagename [lindex $history $histPos 0]]
        set ypos [lindex $history $histPos 1]

        # NEXT, add the name to the list of recent pages
        $self SaveRecentPage $name

        # NEXT, Expand the requested page and display it.
        set pagetext [$top pageexpand $name]

        $rp render $name $pagetext
        $rp searchfor [$top searchtext]

        # NEXT, give the renderpane the focus so that we don't
        # need to click in it.
        $self focus -friendly

        $self setpos $ypos

        # NEXT, notify those concerned.
        if {$options(-pagecommand) ne {}} {
            set command $options(-pagecommand)
            lappend command $name
            uplevel \#0 $command
        }
    }

    # Save the specified page to the recent pages list, removing
    # any previous entry with the same name.  Names are stored
    # in lower case.  No more than ten names are stored.
    method SaveRecentPage {name} {
        set name [string tolower $name]

        set ndx [lsearch -exact $recentPages $name]

        if {$ndx != -1} {
            set recentPages [lreplace $recentPages $ndx $ndx]
        }

        lappend recentPages $name
        
        # Cut down back to ten, if need be
        if {[llength $recentPages] == 11} {
            set recentPages [lreplace $recentPages 0 0]
        }
    }
    

    # Get the y-position of the text at the top of the window.
    method GetPos {} {
        lindex [$rp yview] 0
    }

    # Set the y-position of the text at the top of the window.
    method setpos  {ypos} {
        $rp yview moveto $ypos
    }

    # Called when the user clicks on the title text.
    method TitleHandler {title} {
        $top showsearch $title
    }

    # Called when the user clicks on a link; shows the linked page.
    method LinkHandler {linkName} {
        $self showpage $linkName
    }

    # Called when the user clicks on a magic button; calls the button's script
    method ButtonHandler {script} {
        $top evaluser $script
    }

    # Finds the macro error text and displays the error message.
    method MacroErrorHandler {macro} {
        $top evaluser $macro
        # TBD: If macros are disabled, then clicking on this won't 
        # display an error.  We need to handle this somehow.
    }

    # Called before the Recent Pages context menu is popped up.
    method PostRecent {} {
        # FIRST, delete any existing items.
        $rp.recent delete 2 end

        # NEXT, add items for the recent items.
        foreach id $recentPages {
            if {[$top pageexists $id]} {
                set name [$top pagename $id]
                $rp.recent add command \
                    -label $name \
                    -command [list $self showpage $name]
            }
        }
    }

    # Called before the User Menu context menu is popped up.
    method PostUserMenu {} {
        # FIRST, delete any existing items.
        $rp.user delete 2 end

        # NEXT, retrieve the user's choices
        set items [$top evaluser usermenu]

        # NEXT, add items for the user's choices.
        foreach {label command} $items {
            if {$label eq "separator"} {
                $rp.user add separator
            } else {
                $rp.user add command \
                    -label $label \
                    -command [list $top evaluser $command]
            }
        }
    }
}



