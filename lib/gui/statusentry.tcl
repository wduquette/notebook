#-----------------------------------------------------------------------
# TITLE:
#	statusentry.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#	The statusentry serves graphically as a message/status line, and
#	also as an application command and argument entry field.
#
#	Data entry is done in the form of transactions.  A transaction
#	involves displaying one or more prompts and acquisition of a 
#	data value for each.
#
#	There are two kinds of transaction: synchronous and asynchronous.
#       In an asynchronous transaction, the caller specifies one or more 
#	prompts, possibly with additional data for each, and a command to
#	be executed when all of the responses have been acquired.  The 
#       statusentry sets the first prompt and returns immediately.  
#       As responses are acquired, they are appended to the command, 
#       which finally is executed.
#
#	In a synchronous transaction, the statusentry grabs the event focus
#       so that user has to either complete or cancel the transaction before
#       interacting with any other part of the program.  In this case, the
#	request method returns a list of the responses, or an empty list
#	if the transaction is cancelled.
#
#	The transaction is asynchronous if the request method is passed a
#       -command, and synchronous otherwise.
#
#-----------------------------------------------------------------------

snit::widget ::gui::statusentry {
    #-------------------------------------------------------------------
    # Components

    # The prompt label component
    variable prompt

    # The entry widget component
    variable input

    #-------------------------------------------------------------------
    # Variables


    # The window which had the focus when the statusentry was activated.
    variable focusWin

    # Entry history is governed by two variables: a list
    # of past responses and a history pointer.  This pointer is set to -1 
    # initially, and is updated by the up and down arrow.  It indicates 
    # which item in the history list (counting from the end) to retrieve.  
    # 0 means the final item, 1 means the means the one before that, and 
    # so on.
    variable history {}
    variable histpos -1

    # Response completion is controlled by the "validResponses"
    # variable, which lists all valid responses.  It's set at the 
    # time the prompt is displayed.  If strict is 1, the response
    # *must* be from the list; otherwise not.
    variable validResponses {}
    variable strict 0

    # The transaction state:
    #
    # off       No transaction in process.
    # working   A prompt is shown.
    variable state off

    # While working, the syncflag indicates whether we're running
    # synchronously or asynchronously.
    variable syncflag 0

    # While working, the command to execute when all prompting is done.
    # responses are lappended to this command as the transaction proceeds.
    variable command {}

    # While working, a list of the remaining prompt specs.  Each prompt spec
    # is a list like this:
    #   {-prompt <prompt> options...}
    # All of the possible options are represented, with defaults if
    # necessary.
    variable prompts {}

    #-------------------------------------------------------------------
    # Options

    # The messagecommand is a command prefix which gets one additional
    # argument, a block of text (with no trailing newline).  It's called
    # once for each call to the msg method.
    option -messagecommand {}

    # This option controls the number of actions and argument values to
    # be saved in the history list.
    option -maxhistory 50

    # A command to call if an error is thrown when calling the command
    # at the end of an asynchronous transaction.
    # The command will be passed three arguments, the error message, 
    # error code, and error info.
    option -errorcommand {}

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        $hull configure -background white

        set prompt [label $win.prompt \
                        -foreground black -background white \
                        -highlightthickness 0 \
                        -borderwidth 0 \
                        -font {Courier 12} \
                        -text ""]

        set input [entry $win.text -width 1 \
                       -foreground black -background white \
                       -disabledforeground "" \
                       -disabledbackground "" \
                       -highlightthickness 0 \
                       -borderwidth 0 \
                       -selectborderwidth 0 \
                       -selectforeground black \
                       -selectbackground "#99ffff" \
                       -font {Courier 12} \
                       -state disabled]

        label $win.spacer \
            -foreground white -background white \
            -highlightthickness 0 \
            -borderwidth 0 \
            -font {Courier 12} \
            -text "MMM"

        pack $prompt -side left
        pack $input -side left -expand 1 -fill x
        pack $win.spacer -side right
        
        $self configurelist $args

        # The Return key accepts the current input.
        bind $input <Return> "[mymethod Accept]; break"

        # The Escape key ends the transaction, regardless.
        bind $input <Escape> "[mymethod Escape]; break"

        # The Tab key triggers entry completion if we're in a 
        # transaction; otherwise it does nothing.
        bind $input <Tab> "[mymethod Tab]; break"

        # The Up key steps backward through the current history list.
        bind $input <Up> "[mymethod Up]; break"

        # The Down key steps forward through the current history list.
        bind $input <Down> "[mymethod Down]; break"
        
    }

    #--------------------------------------------------------------------
    # Simple commands

    method msg {text} {
        # If a message is written while we're in a transaction, we can't
        # display it in the statusentry itself.  But give it to the
        # message handler anyway.
        if {$state eq "off"} {
            set lines [split $text "\n"]
            set line [lindex $lines 0]

            # The specified text replaces any old text.
            $prompt configure -text ""
            $input configure -state normal
            $input delete 0 end
            $input insert 0 $line
            $input icursor 0
            $input configure -state disabled
        }

        # Pass the lines to the message handler.
        if {$options(-messagecommand) ne ""} {
            set h $options(-messagecommand)
            lappend h $text
            uplevel \#0 $h
        }
    }

    #--------------------------------------------------------------------
    # Transactions
    
    # The request method begins a transaction.  The "args" is a sequence
    # of options and values, as follows:
    #
    # -command command	        The command to receive the responses.  
    #                           There should be exactly one of these.
    # -prompt prompt            A prompt string.  There must be at least
    #                           one of these.
    #
    # The following options follow a -prompt option and modify it.
    #
    # -enum responses           Gives a list of valid entries for response
    #                           completion.
    # -strict 0|1               Modifies -enum.  If 1, the response must
    #                           belong to the -enum responses.  If 0
    #                           (the default), there's no such limitation.
    # -default value            Gives a default value; the user can
    #                           accept the default by pressing Return, 
    #                           or simply begin typing to replace it.
    #
    # If args consists of a single element, it's assumed to be a list of
    # options and values as described above.

    method request {args} {
        # FIRST, one argument or many?
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        # NEXT, we can't handle a request when we're in a transaction.
        if {$state ne "off"} {
            bell
            return
        }

        # NEXT, save the details of the transaction
        set command {}
        set syncflag 0
        set prompts {}

        set promptDefaults {
            -prompt  {}
            -default {}
            -enum    {}
            -strict 0
        }

        array set pspec $promptDefaults

        foreach {option value} $args {
            switch -exact -- $option {
                -command {
                    set command $value
                }
                -prompt {
                    if {$pspec(-prompt) ne ""} {
                        lappend prompts [array get pspec]
                        array set pspec $promptDefaults
                    }
                    set pspec(-prompt) $value
                }
                -default {
                    set pspec(-default) $value
                }
                -enum {
                    set pspec(-enum) $value
                }
                -strict {
                    set pspec(-strict) $value
                }
                default {
                    error "unknown option: '$option'"
                }
            }
        }

        if {$command eq ""} {
            set syncflag 1
        }

        if {$pspec(-prompt) eq ""} {
            error "no -prompt specified"
        }

        lappend prompts [array get pspec]

        # NEXT, save the focus so that we can restore it; then
        # move the focus to the input widget, make it editable, 
        # clear it, and go on to the first prompt.
        set focusWin [focus]
        focus $input
        $input configure -state normal

        $self SetState working

        if {$syncflag} {
            grab set $win
            after 1 [mymethod NextPrompt 1]
            tkwait variable [varname state]
            grab release $win

            # In this case, command just contains the list of responses.
            # Return it.
            return $command
        } else {
            $self NextPrompt 1 
        }
    }

    # Sets the state
    method SetState {newstate} {
        set state $newstate

        if {$state eq "working"} {
            $prompt configure -background yellow
        } else {
            $prompt configure -background white
        }
    }

    # Retrieves the next prompt from prompts and sets everything up.
    method NextPrompt {firstflag {response ""}} {
        assert {$state eq "working"}

        # FIRST, append the response to the command we're building, unless
        # this is the first prompt.
        if {!$firstflag} {
            lappend command $response
            $self SaveHistory $response
        }

        # NEXT, is there another prompt?  If not, then we have the
        # whole command
        if {[llength $prompts] == 0} {
            # End the transaction
            $input configure -state disabled
            $prompt configure -text ""
            focus $focusWin
            $self SetState off

            # If we're running asynchronously, execute the command.
            if {!$syncflag} {
                # FIRST, if no error handler just let nature take
                # its course.
                if {$options(-errorcommand) eq {}} {
                    uplevel \#0 $command
                    return
                }

                # OTHERWISE, catch any error and pass it to the error handler.
                # If the error handler throws an error, then again let nature
                # take its course.
                if {[catch {uplevel \#0 $command} msg]} {
                    global errorCode
                    global errorInfo

                    uplevel \#0 $options(-errorcommand) \
                        [list $msg $errorInfo $errorCode]
                }
            }
            return
        }

        # NEXT, there's another prompt.  Display the prompt, set up
        # the default value, prepare to get values from the history list,
        # and set up the valid responses.
        array set pspec [unshift prompts]

        $prompt configure -text "$pspec(-prompt): "
        update idletasks
        
        $input delete 0 end
        $input insert 0 $pspec(-default)
        $input select range 0 end
        $input icursor 0

        set validResponses $pspec(-enum)
        set strict $pspec(-strict)
        
        set histpos -1
    }

    # Add the most recent response to the history list.
    method SaveHistory {newvalue} {
        lappend history $newvalue

        set first [expr {[llength $history] - $options(-maxhistory)}]

        if {$first > 0} {
            set history [lrange $history $first end]
        }
    }

    # They pressed Return in the input widget.
    method Accept {} {
        assert {$state eq "working"}

        # If -strict, try to complete the value.  If -strict, 
        # they might want the partial string.  If it can't be
        # completed, return; they need to work on it some more.
        if {$strict} {
            if {![$self CompleteResponse accept]} {
                bell
                return
            }
        }

        # Get the entered text and clear the entry field.
        set response [$input get]
        $input delete 0 end

        # Go on to the next state, given this input.
        $self NextPrompt 0 $response
    }

    # They pressed Escape in the input widget.
    method Escape {} {
        assert {$state eq "working"}

        $self SetState off
        $input configure -state disabled
        $self msg "Cancelled"
        focus $focusWin

        # If this is a synchronous transaction, we need to clear the
        # command variable, so that it's empty when returned.
        set command {}
    }

    # They pressed Tab in the input field.  Try to complete their entry.
    method Tab {} {
        if {![$self CompleteResponse tab]} {
            bell
        }
    }

    # Attempt to complete the entered text.  Return 1 on successful
    # completion (or if no completion is attempted), and 0 otherwise.
    # The context is "tab" or "accept"; on "accept", we'll return 1
    # if the entered text is a valid entry, even if it also matches
    # longer entries.  On "tab" we'll beep in this case.
    method CompleteResponse {context} {
        assert {$state eq "working"}

        # We can't complete the value if we don't have a list of valid
        # entries.
        if {[llength $validResponses] == 0} {
            return 1
        }

        # First, get the input text and match it against the registered
        # command names.
        set response [$input get]

        if {$context eq "accept" &&
            [lsearch -exact $validResponses $response] != -1} {
            return 1
        }

        set names [MatchResponse $validResponses $response]

        # If there's only one match, we'll put it in the entry
        # instead. Otherwise, we'll look for the longest prefix among
        # the matching names, and insert that with a beep.

        set numMatches [llength $names]

        if {$numMatches == 0} {
            # They've already typed a bum entry.
            return 0
        } elseif {$numMatches == 1} {
            # They've entered enough to match one entry; insert it.
            $input delete 0 end
            $input insert 0 [lindex $names 0]

            return 1
        } else {
            # there are several candidates; insert the longest prefix.
            set prefix [LongestCommonPrefix $names]

            if {$prefix ne $response} {
                $input delete 0 end
                $input insert 0 $prefix
            }
            return 0
        }
    }

    # Get the previous response in the history list.
    method Up {} {
        while {$histpos + 1 < [llength $history]} {
            incr histpos

            set candidate [lindex $history "end-$histpos"]

            # If the desired response must strictly be from the validResponses
            # list, and the candidate isn't from that list, look again.
            if {$strict && [lsearch -exact $validResponses $candidate] == -1} {
                continue
            }

            # Get the text and replace the current text with it.
            $input delete 0 end
            $input insert 0 $candidate
            return
        }

        bell
        return
    }

    # Get the previous entry in the history list; and if we're at the
    # very bottom, clear the entry.
    method Down {} {
        while {$histpos > -1} {
            incr histpos -1

            if {$histpos eq -1} {
                set candidate ""
            } else {
                set candidate [lindex $history "end-$histpos"]

                # If the desired response must strictly be from 
                # the validResponses list, and the candidate isn't from 
                # that list, look again.
                if {$strict && 
                    [lsearch -exact $validResponses $candidate] == -1} {
                    continue
                }
            }

            # Get the text and replace the current text with it.
            $input delete 0 end
            $input insert 0 $candidate
            return
        }

        bell
        return
    }

    #--------------------------------------------------------------------
    # Utility procs

    # Given a list of strings, return the sublist that matches the response.
    proc MatchResponse {strings response} {
        set pattern "$response*"
        set result {}
        foreach string $strings {
            if {[string match $pattern $string]} {
                lappend result $string
            }
        }

        return $result
    }

    # Given a list of strings, returns the longest common prefix.
    proc LongestCommonPrefix {strings} {
        set res {}
        set i 0
        foreach char [split [lindex $strings 0] ""] {
            foreach string [lrange $strings 1 end] {
                if {[string index $string $i] != $char} {
                    return $res
                }
            }
            append res $char
            incr i
        }
        set res
    }

    # Get the first element from a list variable, removing it from
    # the variable's value.  If the list variable is empty, return "".
    proc unshift {listvar} {
        upvar $listvar theList

        if {[llength $theList] <= 1} {
            set element [lindex $theList 0]
            set theList ""
        } else {
            set element [lindex $theList 0]
            set theList [lrange $theList 1 end]
        }

        return $element
    }
}