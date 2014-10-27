#-----------------------------------------------------------------------
# TITLE:
#	searchentry.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       A searchentry is an ornamented entry field.  The entry is flanked
#       on the left by a pulldown that lets the user select one of a number
#       search modes, and on the right by a clear button.  All three 
#	components are contained in a single visible border.
#
#	The pulldown entries are determined by a widget option.
#       The active pulldown selection is also an option.
#       The searchentry supports incremental and non-incremental search.
#	When the search text is ready, a user-supplied command is called;
#	it is passed the search text and the current pulldown option.
#
#-----------------------------------------------------------------------

snit::widget ::gui::searchentry {
    #-------------------------------------------------------------------
    # Components

    # The arrow button
    variable arrow

    # The entry
    delegate option -width to entry

    # The clear button
    variable clear

    # The mode menu
    variable modemenu

    #-------------------------------------------------------------------
    # Variables

    # TBD

    #-------------------------------------------------------------------
    # Creation Time Options
    #
    # These options should only be set at creation time.  Note that
    # at present there's no error checking to prevent them from being
    # set later.

    # A list of mutually exclusive search modes and labels, e.g.,
    # -modelist {title "Title Only" all "Title and Contents"}
    option -modelist {}

    #--------------------------------------------------------------------
    # Other Options

    # The selected search mode: defaults to the first mode in the
    # -modelist, or "default" if there is no -modelist.  
    #
    # WARNING: If there's a -modelist, this should only be set to one 
    # of the modes defined in it.  Note that there's no error checking
    # on this at present.
    option -mode default

    # The user's callback command.  It should take two arguments,
    # the search mode and the search text.  If {}, no command is called.
    option -searchcmd {}

    # 1 if we're to do incremental search, and 0 otherwise.
    option -incremental 1

    # The search text; maps to the entry's contents.  Setting initiates
    # a search.
    option -searchtext -configuremethod CfgSearchText

    method CfgSearchText {opt value} {
        set options($opt) $value

        $self UpdateClear
        $self DoSearch complete
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, set the hull's border
        $hull configure -relief solid -borderwidth 1 -background white

        # NEXT, get the modelist, since we need it early
        set options(-modelist) [from args -modelist]

        # NEXT, identify the search box
        label $win.search  \
            -relief flat \
            -borderwidth 0 \
            -background white \
            -foreground black \
            -image ::gui::search

        # NEXT, create the pulldown's arrow button
        install arrow using label $win.arrow \
            -relief flat \
            -borderwidth 0 \
            -background white \
            -foreground black \
            -image ::gui::downarrow

        # Next, create the popup.
        install modemenu using menu $win.modemenu \
            -tearoff no
        bind $arrow <1> [mymethod PostModeMenu]

        $modemenu add radiobutton \
            -variable [myvar options(-incremental)] \
            -value 1 \
            -label "Incremental Search"

        $modemenu add radiobutton \
            -variable [myvar options(-incremental)] \
            -value 0 \
            -label "Non-Incremental Search"

        # If we have modes, add them.
        if {[llength $options(-modelist)] > 1} {

            set options(-mode) [lindex $options(-modelist) 0]

            $modemenu add separator

            foreach {mode label} $options(-modelist) {
                $modemenu add radiobutton \
                    -variable [myvar options(-mode)] \
                    -value $mode \
                    -label $label \
                    -command [mymethod DoSearch]
            }
        }

        # NEXT, create the entry
        install entry using entry $win.entry \
            -width 20 \
            -background white \
            -foreground black \
            -borderwidth 0 \
            -relief flat \
            -highlightthickness 0 \
            -textvariable [myvar options(-searchtext)]

        bindtags $entry [concat [bindtags $entry] $win]

        bind $win <KeyPress> [mymethod KeyPress]
        bind $win <Return>   [mymethod Return]
        bind $win <Escape>   [mymethod Clear]

        # NEXT, if the megawidget gets the focus, it should go to the entry.
        bind $win <FocusIn> [mymethod FocusIn]

        # NEXT, create the clear button
        install clear using label $win.clear \
            -relief flat \
            -borderwidth 0 \
            -background white \
            -foreground black \
            -image ::gui::closex \
            -state disabled
        bind $clear <1> [mymethod Clear]

        # Pack all of the components into the hull
        pack $win.search -side left  -fill y    -padx 2 -pady 2
        pack $arrow      -side left  -fill y    -padx 2 -pady 2
        pack $clear      -side right -fill y    -padx 2 -pady 2
        pack $entry      -side left  -fill both         -pady 2 -expand 1

        # Apply the arguments
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Private methods

    method FocusIn {} {
        focus $entry
        $entry selection range 0 end
    }

    method KeyPress {} {
        $self UpdateClear

        if {!$options(-incremental)} {
            return
        }

        $self DoSearch incremental
        
        # We must have had the focus before, since this call only comes
        # because of a KeyPress.  So put the focus back in the entry
        # widget in case the search callback changed it.
        focus $entry
    }

    method UpdateClear {} {
        if {[string length $options(-searchtext)] > 0} {
            $clear configure -state normal
        } else {
            $clear configure -state disabled
        }
    }

    method Return {} {
        $self DoSearch complete

        # We don't want to call KeyRelease, so break the event.
        return -code break
    }
    
    method DoSearch {searchtype} {
        # Call the search command
        set command $options(-searchcmd)
        lappend command $options(-mode) $searchtype $options(-searchtext)
        uplevel \#0 $command
    }

    method Clear {} {
        set options(-searchtext) ""
        $clear configure -state disabled
        $self DoSearch complete
    }

    method PostModeMenu {} {
        set x [winfo rootx $arrow]
        set y [expr {[winfo rooty $arrow] + [winfo height $arrow]}]

        tk_popup $modemenu $x $y
    }
}

