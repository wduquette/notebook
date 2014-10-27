#-----------------------------------------------------------------------
# TITLE:
#	tooltip.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Tool tips for notebook's gui package.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Tooltip type
#
# The tooltip command is an instance of TooltipType, so that we can
# have options.

snit::type ::gui::TooltipType {
    #-------------------------------------------------------------------
    # Options

    option -font {Helvetica 12}
    option -background "#FFFFC0"
    option -topbackground black
    option -foreground black
    option -delay 800

    #-------------------------------------------------------------------
    # Variables

    # Tool tip text.  An array, indexed by window name
    variable tiptext

    # Tool tip timeout, or {}
    variable timeout {}

    # Tool tip window, or {}
    variable tipwin {}

    #-------------------------------------------------------------------
    # Constructor

    # Implicit

    #-------------------------------------------------------------------
    # Public methods

    method register {window text} {
        set tiptext($window) $text

        bind $window <Enter> [mymethod Enter $window]
        bind $window <Leave> [mymethod Leave $window]
    }

    method unregister {window} {
        unset tiptext($window)
    }

    #-------------------------------------------------------------------
    # Private Methods

    # When the mouse pointer enters the window, set the timer.
    method Enter {window} {
        set timeout [after $options(-delay) [mymethod Popup $window]]
    }

    # Pop up the tooltip.
    method Popup {window} {
        # FIRST, the timeout has fired, so we can forget it.
        set timeout {}

        # NEXT, the tooltip will be a child of the window's toplevel.
        set top [winfo toplevel $window]

        # NEXT, the tooltip's name depends on which toplevel it is.
        set tipwin ".gui_tooltip_window"

        if {$top ne "."} {
            set tipwin "$top$tipwin"
        }

        # NEXT, create the tooltip window.
        frame $tipwin \
            -background $options(-topbackground)

        label $tipwin.label \
            -text $tiptext($window) \
            -foreground $options(-foreground) \
            -background $options(-background) \
            -font $options(-font)

        # Pack the label with a 1 pixel gap, so that there's a box 
        # around it.
        pack $tipwin.label -padx 1 -pady 1

        # NEXT, the tipwin will be placed in the toplevel relative to
        # the position of the registered window.  We'll figure this out
        # by getting the position of both relative to the root window.

        set tx [winfo rootx $top]
        set ty [winfo rooty $top]

        set wx [winfo rootx $window]
        set wy [winfo rooty $window]

        # We want to the tip to appear below and to the right of the
        # registered window.  
        set offset [expr {[winfo width $window]/2}]

        # Compute the final position.
        set x [expr {($wx - $tx) + $offset}]
        set y [expr {($wy - $ty) + [winfo height $window] + 2}]

        # Finally, place the tipwin in its position.
        place $tipwin -anchor nw -x $x -y $y

        # If the tipwin runs off the right edge, we slide it left; if
        # it sticks off the bottom edge, we put it above the button instead.
        # If it still can't be seen, that's too bad.
        #
        # NOTE: I don't know of any way to determine the size of the
        # tipwin without letting it pop up, which causes an ugly 
        # jump when it has to be moved.
        update idletasks

        set nx $x
        set ny $y 

        set rightEdge [expr {$x + [winfo width $tipwin]}]
        set topWid [winfo width $top]

        if {$rightEdge >= $topWid} {
            set nx [expr {$x - ($rightEdge - $topWid + 2)}]
        }

        set bottomEdge [expr {$y + [winfo height $tipwin] + 2}]
        set topHt [winfo height $top]

        if {$bottomEdge >= $topHt} {
            set ny [expr {($wy - $ty) - [winfo height $tipwin] - 2}]
        }

        if {$nx != $x || $ny != $y} {
            place $tipwin -anchor nw -x $nx -y $ny
        }
    }

    # When the mouse pointer leaves the window, cancel the timer or
    # popdown the window, as needed.
    method Leave {window} {
        if {$timeout ne ""} {
            after cancel $timeout
            set timeout ""
            return
        }

        if {$tipwin ne ""} {
            destroy $tipwin
            set tipwin ""
        }
    }
}

#-----------------------------------------------------------------------
# The tooltip command

::gui::TooltipType ::gui::tooltip
