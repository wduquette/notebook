#-----------------------------------------------------------------------
# TITLE:
#	misc.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       GUI Helper Functions for notebook's gui package.
#
#-----------------------------------------------------------------------

# Does window $win have a binding for the event in any of its 
# bind tags?
proc ::gui::hasbinding {win event} {
    if {$win eq ""} {
        return 0
    }

    foreach tag [bindtags $win] {
        if {[bind $tag $event] ne ""} {
            return 1
        }
    }

    return 0
}

# require expression message
#
# GUIs often have to do a lot of checking to see whether a given 
# user-requested action is valid or not, both in terms of program state
# and in terms of the user's input.  Procs that implement these actions 
# consequently usually begin with a series of if statements; each statement 
# checks a condition, emits some appropriate error message to the user, and
# returns.  In many cases, this is the bulk of the command.
#
# require streamlines this kind of code, and makes it work better when nested.
# require evaluates the expression.  If it's true, require returns
# silently.  But if it's false, require throws an error using the
# given message and an errorcode of "USER".  This has a number of
# effects on procs written using require:
#
# * They are useful programmatically.
# * They don't need to know how errors are reported to the user.
# * They allow the caller to distinguish between user input errors
#   and unexpected programming errors.
# * They can't be attached directly to menu items, buttons, etc.,
#   because they need a mediator to catch and present the error.
#
# Thus, using require necessitates some kind of glue mechanism, like
# an action manager of some kind.

proc ::gui::require {expression message} {
    if {[uplevel [list expr $expression]]} {
        return
    }

    return -code error -errorcode USER $message
}

# assert expression
#
# Assert is like require, but is used for checking invariants--in 
# correctly written code, the expression should invariably be true.
# If the assertion fails an error is thrown indicating 
# that an assertion failed and what the condition was.

proc ::gui::assert {expression} {
    if {[uplevel [list expr $expression]]} {
        return
    }

    return -code error -errorcode ASSERT "Assertion failed: $expression"
    
}