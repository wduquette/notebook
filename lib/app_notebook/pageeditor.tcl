#-----------------------------------------------------------------------
# TITLE:
#	pageeditor.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       A editor for editing notebook pages.
#
# LICENSE:
#       Copyright (C) 2004 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

snit::widget pageeditor {
    #-------------------------------------------------------------------
    # Creation Options:  These must be set at creation time, and 
    # shouldn't be changed thereafter.

    # The notebook database
    option -db

    #--------------------------------------------------------------------
    # Other Options

    # Commands to get and save text for a page, and to call when done
    # editing.
    option -endcmd

    #-------------------------------------------------------------------
    # Components
    
    # Delegate unknown options to the text editor pane.
    delegate option * to ed

    # The toplevel window (i.e., the notebookbrowser)
    variable top

    # The context menu component
    variable menu

    # The notebook database (set by -db)
    variable db

    #-------------------------------------------------------------------
    # Instance variables

    # Name of the current page.
    variable current ""

    # Template for new pages
    variable template ""

    # Finding/Replacing
    variable lastFind ""          ;# Index of last string found.
    variable lastTarget ""        ;# Last string found, or "".

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        #---------------------------------------------------------------
        # Preliminaries

        # FIRST, get the notebookbrowser, so that we can invoke actions.
        set top [winfo toplevel $win]

        #---------------------------------------------------------------
        # Create GUI Components

        # FIRST, create the text widget.  All unknown options are delegated
        # to the text widget, so go ahead and configure the creation 
        # arguments.  Finally, user preferences can affect the text widget's
        # size and so forth, so apply the current preferences at the same time.
        install ed using text $win.ed -width 80 -height 30 \
            -borderwidth 5 \
            -relief flat \
            -setgrid true \
            -undo 1 \
            -yscrollcommand "$win.scroll set"

        $self configurelist $args

        $self UsePreferences

        # NEXT, create the scrollbar
        scrollbar $win.scroll -command "$win.ed yview"

        # NEXT, pack the widgets.
        pack $win.scroll  -side right -fill y    -expand false
        pack $win.ed    -side left  -fill both -expand true

        # NEXT, make the database more easily available
        set db $options(-db)

        #---------------------------------------------------------------
        # Define User Interactions

        # FIRST, copy all of the default Text bindings to the text 
        # widget itself, and remove Text from the bindtags.  That way, 
        # the widget will get all of the default text widget behavior, 
        # but our bindings will replace the default bindings instead of 
        # augmenting them. 
        #
        # ALSO, include the pageeditor window itself in the text widget's
        # bindtags, so that keys bound to the pageeditor will take effect
        # when the text widget has focus.

        foreach sym [bind Text] {
            bind $ed $sym [bind Text $sym]
        }

        set bt [bindtags $ed]
        set ndx [lsearch -exact $bt Text]
        set bt [lreplace $bt $ndx $ndx]
        lappend bt $win
        bindtags $ed $bt

        # NEXT, define non-action key commands.

        bind $ed <Control-comma>        [list $ed insert insert "&lt;"]
        bind $ed <Control-period>       [list $ed insert insert "&gt;"]
        bind $ed <Control-bracketleft>  [list $ed insert insert "&lb;"]
        bind $ed <Control-bracketright> [list $ed insert insert "&rb;"]

        bind $ed <Tab>                  "$self ElectricTab ; break"
        bind $ed <space>                [mymethod ElectricSpace]
        bind $ed <Return>               [mymethod ElectricReturn]

        # NEXT, handle <<Paste>> so that the insertion point is always
        # visible after the paste.
        bind $ed <<Paste>> {tk_textPaste %W ; %W see insert}

        # NEXT, define the Context Menu
        install menu using menu $ed.menu \
            -tearoff no \
            -postcommand [mymethod PostEditMenu]

        $menu add command -label "Edit Menu"
        $menu add separator
        $menu add command -label "Dummy"

        bind $ed <Control-1> [list tk_popup $menu %X %Y 2]
        bind $ed <3>         [list tk_popup $menu %X %Y 2]

        #---------------------------------------------------------------
        # Other interactions
        
        # Prepare to receive preferences events
        prefs register $selfns [mymethod UsePreferences]

    }

    #-------------------------------------------------------------------
    # Destructor

    destructor {
        catch {prefs unregister $selfns}
    }

    #-------------------------------------------------------------------
    # Public Methods: general

    # Gives the editor the focus
    method focus {} {
        focus $ed
    }

    # Returns 1 if we're editing a page, and 0 otherwise.
    method editing {} {
        return [expr {$current ne ""}]
    }

    # Returns the name of the page we're editing, or ""
    method current {} {
        return $current
    }
    
    # Tag text that matches the search text.
    # TBD: This is a duplicate of code from renderpane.tcl; it should
    # probably be generalized into the gui package.
    method searchfor {searchText} {
        $ed tag remove search 1.0 end

        set pattern [string trim $searchText]

        if {$pattern eq ""} {
            return
        }

        set done 0
        set index 1.0
        set count 0
        while {1} {
            set index [$ed search -nocase -count count -- $pattern $index end]

            if {$index eq ""} {
                break
            }

            set endIndex [$ed index "$index + $count chars"]

            $ed tag add search $index $endIndex

            set index $endIndex
        }
    }

    #-------------------------------------------------------------------
    # Public Methods: Beginning the editing session.

    # Begins an editing session.  Locks the named page, and loads its text
    # into the editor.  Note that it's the caller's job to make sure that 
    # the editor is visible.
    method edit {name {tmplt ""}} {
        require {![$self editing]} "Already editing a page."

        # Clear the template, so that we load the real thing.
        set template $tmplt
        set current $name

        $db lock $current
        $self Revert
        $self searchfor [$top searchtext]
    }

    #-------------------------------------------------------------------
    # Public Methods: While editing

    # Inserts the specified text into the editor at 
    # the insertion mark. 
    method insert {textToInsert} {
        require {[$self editing]} "Not editing a page."

        $ed insert insert $textToInsert
        $ed see insert
    }

    # Find the target within the current page, searching down from
    # the insertion point.  If there's nothing but whitespace
    # between the insertion point and the end, move the insertion
    # point to the beginning before searching.
    #
    # Returns 1 if the string was found, and 0 otherwise.
    method find {target} {
        require {[$self editing]} "Not editing a page."

        set lastInsert [$ed index insert]

        if {[string trim [$ed get insert end]] eq ""} {
            $ed mark set insert 1.0
        }

        set lastTarget $target
        set lastFind [$ed search -exact -nocase -- $target insert end]

        if {$lastFind eq ""} {
            $ed mark set insert $lastInsert
        }

        if {$lastFind eq ""} {
            return 0
        } else {
            $ed mark set insert $lastFind
            $ed see insert
            return 1
        }
    }

    # Find the target again.
    method findagain {} {
        require {[$self editing]}   "Not editing a page."
        require {$lastTarget ne ""} "No previous string to find."

        if {$lastFind eq ""} {
            set lastFind "1.0"
        }

        set lastFind [$ed search -exact -nocase -- \
                          $lastTarget "$lastFind + 1 chars" end]

        require {$lastFind ne ""} "'$lastTarget' not found."

        $ed mark set insert $lastFind
        $ed see insert
    }

    # Replace all occurrences of fromString at or following the 
    # cursor with toString.
    method replace {fromString toString} {
        require {[$self editing]} "Not editing a page."

        # First, get the lengths of the from and to strings
        # for reference.
        set flen [string length $fromString]
        set tlen [string length $toString]

        # Next, search for the string the first time.
        set index [$ed search -exact -- $fromString insert end]

        require {$index ne ""} "'$fromString' not found."

        # Next, this should be undone as a unit.
        $ed configure -autoseparators 0
        $ed edit separator

        # Next, replace every occurrence.
        set counter 0
        while {$index ne ""} {
            incr counter

            $ed delete $index "$index + $flen chars"
            $ed insert $index $toString

            set endIndex "$index + $tlen chars"

            set index [$ed search -exact -- $fromString $endIndex end]
        }

        # Next, counter is the number of replacements, and $endIndex
        # is the position just after the last one.

        $ed mark set insert $endIndex
        $ed see insert

        # Return to normal undo mode.
        $ed edit separator
        $ed configure -autoseparators 1

        return $counter
    }

    # Grab the rest of the word under the insertion point, if any.
    # This definition may need some help, depending on your definition
    # of what the end of the current word is.
    method wordend {} {
        require {[$self editing]} "Not editing a page."

        return [string trim [$ed get insert "insert wordend"]]
    }

    # Grab the word under the insertion point, if any.
    method thisword {} {
        require {[$self editing]} "Not editing a page."

        return [string trim [$ed get "insert wordstart" "insert wordend"]]
    }

    #-------------------------------------------------------------------
    # Public Methods: Ending the edit session

    # Save current edits, but remain editing.
    method saveandcontinue {} {
        require {[$self editing]} "Not editing a page."

        $self Save
    }

    # Save current edits and end the session, unlocking the page.
    method saveedits {} {
        require {[$self editing]} "Not editing a page."

        $self Save
        $db unlock $current
        set current ""

        # Notify the parent, so that they can hide the
        # editor.
        uplevel \#0 $options(-endcmd)
    }

    # Cancel editing, unlocking the page.
    method canceledits {} {
        require {[$self editing]} "Not editing a page."

        # Verify that the really want to throw away their edits.
        if {[$ed edit modified] == 1} {
            if {![$top askyesno "Return to browser without saving?"]} {
                return
            }
        }
        
        # Unlock the page, so that it can be edited later.
        $db unlock $current
        set current ""

        # Notify the parent, so that they can hide the editor.
        uplevel \#0 $options(-endcmd)
    }

    #-------------------------------------------------------------------
    # Private methods: Component set up

    # Sets up the widget's appearance based on the preferences.
    method UsePreferences {} {
        # First, figure out the size of four-space monospace tab 
        # stop in pixels
        set tabWidth [font measure [prefs get monotext] "1234"]

        $ed configure \
            -foreground [prefs get editorfg] \
            -background [prefs get editorbg] \
            -font [prefs get monotext] \
            -tabs [list $tabWidth [expr $tabWidth*2]]

        $ed tag configure search \
            -foreground [prefs get searchfg] \
            -background [prefs get searchbg]

        # Give highest priority to the selection to make it visible when some
        # text with a non-default background is selected
        $ed tag raise sel
    }

    # Called before the Edit Menu context menu is popped up.
    method PostEditMenu {} {
        # FIRST, delete any existing items
        $menu delete 2 end

        # NEXT, retrieve the user's menu items
        set items [$top evaluser editmenu]

        # NEXT, add the items.
        foreach {label command} $items {
            if {$label eq "separator"} {
                $menu add separator
            } else {
                $menu add command \
                    -label $label \
                    -command [list $top evaluser $command]
            }
        }
    }

    #-------------------------------------------------------------------
    # Private Methods: Edit Session Control

    # Save the current text, clearing any template.
    method Save {} {
        set template ""

        $db unlock $current
        # TBD: That should be end-1.
        $db set $current [$ed get 1.0 end]
        $db lock $current
        $db save

        $ed edit modified 0
    }

    # Replace the current text with the unchanged text of the current page.
    method Revert {} {
        $ed delete 1.0 end

        # FIRST, insert the page text, if any.
        if {[$db exists $current]} {
            $ed insert end [$db get $current]
        }

        # NEXT, insert the template, if any.
        if {[string length $template] > 0} {
            $ed insert end $template
        }

        # TBD: This shouldn't be necessary--I just need to delete the
        # unneeded "\n" off of the end when I save.
        if {![string equal [$ed index insert] 1.0]} {
            $ed insert end "\n"
        }

        # NEXT, position the cursor at the beginning or at the end.
        if {[prefs get editbottom]} {
            $ed see end
            $ed mark set insert end
        } else {
            $ed see 1.0
            $ed mark set insert 1.0
        }
        focus $ed

        # Clear the undo stack so that we can only undo the user's changes.
        $ed edit reset 
        $ed edit modified 0
    }


    #-------------------------------------------------------------------
    # Private Methods: Editing

    # Insert a space, wrapping the line if appropriate.
    method ElectricSpace {} {
        if {[$self ElectricWrap " "]} {
            return
        }

        # Normal case, just insert a space.
        $ed insert insert " "
    }

    # Insert a newline, wrapping the line if appropriate.
    method ElectricReturn {} {
        if {[$self ElectricWrap "\n"]} {
            return
        }

        # Normal case, just insert a newline.
        $ed insert insert "\n"
        $ed see insert
    }

    # Wraps to the next line, if necessary, inserting the next desired 
    # character if necessary.  Return 1 if we wrapped, and 0 otherwise.  
    method ElectricWrap {nextchar} {
        if {![prefs get autowrap]} {
            return 0
        }
    
        set wrapcol [prefs get wrapcolumn]

        if {[$self InsertCol] <= $wrapcol} {
            return 0
        }

        # So long as the column is after the wrap column, insert newlines
        # to wrap.
        while {[$self InsertCol] > $wrapcol} {
       
            # Find some whitespace to wrap at; replace it with a newline.
            # Get the index of the previous space character, if any.
       
            for {
                set mark [$ed index \
                              "insert linestart +$wrapcol c"]
                set endmark [$ed index "insert linestart"]
            } {"" != $mark} {
                set mark [$ed search -backwards -regexp -- {\s} \
                              $mark $endmark]
            } {
                if {[lindex [split $mark "."] 1] < $wrapcol} {
                    break
                }
            } 

            # spos is the position of the whitespace, if any.
            set spos $mark

            # If there's no good whitespace, that's special.
            if {[string length $spos] == 0} {
                # If there's no space, just put in a newline.
                $ed insert insert "\n"
                
                # If they entered a space, then we should auto-indent, because
                # they haven't ended the paragraph.  But if they entered a
                # carriage return, we shouldn't, since they just got what they
                # asked for.
                if {" " == $nextchar} {
                    $self ElectricIndent
                }

                $ed see insert
                
                return 1
            }

            # Next, there's a good place to wrap.  Delete the whitespace 
            # character, insert a newline, and indent the line (if needed.)
            while {" " == [$ed get $spos]} {
                $ed delete $spos
            }
            $ed insert $spos "\n"
            $self ElectricIndent
        }

        # Finally, we've wrapped enough.  Insert the character.
        $ed insert insert $nextchar
        $ed see insert

        return 1
    }

    # Return column of insert mark
    method InsertCol {} {
        lindex [split [$ed index insert] "."] 1
    }

    # Handle special Tab character handling.
    method ElectricTab {} {
        # First, get the position on the line.
        set pos [split [$ed index insert] "."]
        set line [lindex $pos 0]
        set column [lindex $pos 1]

        # Next, try to auto-indent if we're at the beginning of the line.
        # If we don't auto-indent, tab normally.
        if {$column == 0} {
            if {[$self ElectricIndent]} {
                return
            }
        }

        # Next, compute spaces to next tab stop, and insert them.
        set tw [prefs get tabwidth]
        set fullTab [string repeat " " $tw]
        set neededTab [string range $fullTab [expr {$column % $tw}] end]
        $ed insert insert $neededTab
    }

    # Automatically indents the beginning of the line to match the previous
    # line.  The current line is indicated by the insert mark.  Returns the
    # number of inserted characters.
    method ElectricIndent {} {
        if {![prefs get autoindent]} {
            return 0
        }

        # First, get the line number.
        set pos [split [$ed index insert] "."]
        set line [lindex $pos 0]
        
        # Next, auto-indent if the previous line is indented, 
        # disregarding leading "*" or ":" characters.
        if {$line > 1} {
            # Get the previous line.
            set pline [$ed get \
                           "insert linestart -1 line" \
                           "insert linestart -1 line lineend"]

            if {[regexp -- {^((\**)|(:*))\s*} $pline matched]} {
                set indent [string length $matched]

                if {$indent > 0} {
                    $ed insert "insert linestart" \
                        [string repeat " " $indent]
                    return $indent
                }
            }
        }
        
        return 0
    }
}

