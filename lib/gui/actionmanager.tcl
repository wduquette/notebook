#-----------------------------------------------------------------------
# TITLE:
#	actionmanager.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       A manager for user actions.
#
#-----------------------------------------------------------------------

snit::type ::gui::actionmanager {
    #-------------------------------------------------------------------
    # Options

    # A command to call if an error is thrown on invocation of an action.
    # The command will be passed three arguments, the error message, 
    # error code, and error info.
    option -errorcommand {}

    # A command to call to check the state (normal or disabled) of an
    # action.
    option -statecommand {}

    #-------------------------------------------------------------------
    # Instance Variables
    
    # A list of action names:
    variable actions {}

    # The following variables constitute the action database.  Each
    # is an array, keyed on the action name.

    variable command      ;# The Tcl command to execute when invoked.
    variable state        ;# 1 or 0; enabled or disabled.
    variable label        ;# The label, for menus and buttons.
    variable requires     ;# List of condition tags.
    variable options      ;# List of options and values
    variable keycodes     ;# list: key-sequence menu-accelerator
    variable widgets      ;# list: widget names

    #-------------------------------------------------------------------
    # Constructor

    # At present, no constructor is needed.

    #-------------------------------------------------------------------
    # Public Methods

    # Creates a new action with the specified name and options.
    method add {action args} {
        if {![regexp {^\S+$} $action]} {
            error "action name '$action' contains whitespace"
        }

        if {[info exists command($action)]} {
            error "action '$action' is already defined"
        }

        # Initialize the database.
        lappend actions $action

        set command($action)  {}
        set label($action)    {}
        set state($action)    normal
        set requires($action) {}
        set options($action)  {}
        set keycodes($action) {}
        set widgets($action)  {}

        # Handle the options
        foreach {opt value} $args {
            switch -exact -- $opt {
                -command {
                    set command($action) $value
                }
                -requires {
                    set requires($action) $value
                }
                -label {
                    # Figure out the underline index and update the label
                    set underline [string first "&" $value]
        
                    if {$underline < 0} {
                        set underline 0
                        set lbl $value
                    } else {
                        set lbl [string replace $value $underline $underline]
                    }

                    lappend options($action) -underline $underline
                    set label($action) $lbl
                }
                -image -
                -tooltip {
                    lappend options($action) $opt $value
                }
                -state {
                    $self setstate $action $value
                }
                -keycodes {
                    if {([llength $value] % 2) != 0} {
                        error "invalid -keycodes: '$value'"
                    }
                    set gui [tk windowingsystem]

                    array set codes $value
                    
                    if {[info exists codes($gui)]} {
                        set keycodes($action) $codes($gui)
                    } elseif {[info exists codes(any)]} {
                        set keycodes($action) $codes(any)
                    }
                }
                -keytag {
                    $self bindkey $value $action
                }
                default {
                    error "unknown option '$opt'"
                }
            }
        }
    }

    # Returns a list of all existing actions.  If the state is given,
    # (normal | disabled) then it returns a list of all actions 
    # that have that state.  Note that updatestate is *NOT* called.
    # Call it explicitly if you want it.
    method list {{whichstate ""}} {
        if {$whichstate eq ""} {
            return $actions
        }

        set result {}
        foreach action $actions {
            if {$state($action) eq $whichstate} {
                lappend result $action
            }
        }

        return $result
    }

    # Invokes the action, e.g., calls its -command. This is done whether
    # the action is enabled or not, as it allows the command to present 
    # a suitable error message.
    method invoke {action args} {
        # FIRST, if no error handler just let nature take its course.
        if {$options(-errorcommand) eq {}} {
            uplevel \#0 $command($action) $args
            return
        }

        # OTHERWISE, catch any error and pass it to the error handler.
        # If the error handler throws an error, then again let nature
        # take its course.
        if {[catch {uplevel \#0 $command($action) $args} msg]} {
            global errorCode
            global errorInfo

            uplevel \#0 $options(-errorcommand) \
                [list $msg $errorInfo $errorCode]
        }

        return
    }

    # Sets the state of the named action to normal or disabled.
    method setstate {action newstate} {
        if {$newstate ne "normal" && $newstate ne "disabled"} {
            error "Invalid state: '$newstate'"
        }

        set state($action) $newstate

        foreach {type widget} $widgets($action) {
            switch -exact $type {
                button {
                    $widget configure -state $newstate
                }
                menu {
                    set ndx [$widget index $label($action)]

                    $widget entryconfigure $ndx -state $newstate
                }
                default {
                    error "Invalid widget type: $type"
                }
            }
        }
    }

    # Update state: For every action that has a -requires value, 
    # run the state command, passing it the action's name and its requirements.
    # The state command must return the new state.
    method updatestate {} {
        if {[llength $options(-statecommand)] == 0} {
            return
        }

        foreach action $actions {
            if {$requires($action) ne ""} {
                set cmd $options(-statecommand)
                lappend cmd $action $requires($action)

                $self setstate $action [uplevel \#0 $cmd]
            }
        }

        # Without this, sometimes widget states aren't updated promptly
        # on Aqua.
        update idletasks
    }

    # bindkey tag action ?break?
    #
    # If a keysequence exists for the action,
    # binds the action to the tag (usually a window).
    # break is included, the binding will "break".
    #
    # If there's no keysequence defined, then no binding is done.
    
    method bindkey {tag action {break ""}} {
        # Get the binding for this GUI.  If none found, we're done.
        set seq [lindex $keycodes($action) 0]

        if {$seq eq ""} {
            return
        }

        # Do the binding, adding "break" as requested.
        set cmd [mymethod invoke $action]

        if {$break eq "break"} {
            append cmd "; break"
        }

        # If the binding is a modified letter key, do both upper and 
        # lower case.
        if {[regexp {^<(.*)-([a-z])>$} $seq dummy root letter]} {
            set upper [string toupper $letter]
            set lower [string tolower $letter]

            bind $tag <$root-$upper> $cmd
            bind $tag <$root-$lower> $cmd
        } else {
            bind $tag $seq $cmd
        }
    }

    # Configures a button to invoke this action; also sets the button's 
    # label or icon, etc.
    
    method addbutton {button action args} {
        array set opt $options($action)

        button $button \
            -command [mymethod invoke $action] \
            -state $state($action)

        if {[info exists opt(-image)]} {
            $button configure -image $opt(-image)
        } else {
            $button configure -text $label($action) -underline $opt(-underline)
        }

        eval $button configure $args

        # Enable tool tips--except with aqua on Mac OS X, because it
        # causes the focus to go away.
        if {[info exists opt(-tooltip)]} {
            tooltip register $button $opt(-tooltip)
        }

        lappend widgets($action) button $button

        return $button
    }


    # Adds a command item for the action to the named menu, and configures
    # additional options if desired.
    
    method addmenuitem {menu action args} {
        array set opt $options($action)

        $menu add command \
            -command [mymethod invoke $action] \
            -label $label($action) \
            -underline $opt(-underline) \
            -state $state($action) \
            -accelerator [lindex $keycodes($action) 1]

        set ndx [$menu index $label($action)]

        foreach {option value} $args {
            $menu entryconfigure $ndx $option $value
        }

        lappend widgets($action) menu $menu

        # Add a post command to the menu to update the state.
        # TBD: Consider making this explicit.
        $menu configure -postcommand [mymethod updatestate]
    }
}

