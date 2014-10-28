#-----------------------------------------------------------------------
# TITLE:
#	notebookbrowser.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       A browser for notebook files.
#
#	NOTE: A pagebrowser is a GUI component that can be packed in a
#	window.  A notebookbrowser is a toplevel window.
#
# LICENSE:
#       Copyright (C) 2005 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required Packages

package require BWidget

# export name ?"as" username?
#
# This macro is used to export method names that should be aliased
# into the User Code interpreter.  Use the "as" clause to give the
# alias a different name than the original method.
#
# See "Browser-Specific Notebook Commands", below, for a description
# of how this all works.

snit::macro export {name {"as" "as"} {username ""}} {
    global browsercommands

    if {$username eq ""} {
        set username $name
    }

    lappend browsercommands $username
    delegate typemethod $username to currentBrowser as $name
}

snit::widget notebookbrowser {
    hulltype toplevel

    #-------------------------------------------------------------------
    # Browser-Specific Notebook Commands
    #
    # There are many Notebook Commands which depend on the identity
    # of the current browser.  The "goto-page" command, for example, 
    # needs to load the named page into the current browser, not some
    # other browser.  This behavior is implemented as follows.
    #
    # * First, all browser-specific Notebook Commands are implemented
    #   as methods of the notebookbrowser object.
    #
    # * The notebookbrowser type has a typecomponent called 
    #   currentBrowser.  Whenever User Code is to be evaluated, 
    #   currentBrowser is set to the command name of the current
    #   browser.
    #
    # * We define a typemethod for each browser-specific Notebook
    #   Command; the typemethod is delegated to the currentBrowser
    #   typecomponent.
    #
    # * Each such typemethod is aliased into the User Code interpreter.
    #   Thus, when User Code is called it, it's delegated to the
    #   specific method of the current browser.
    #
    # * Given a method name, the "export" macro defines the delegated
    #   typemethod (possibly under another name); it also saves the
    #   typemethod name in a variable, to be used in the definition
    #   of the "browsercommands" typemethod.
    #
    # * The dbmanager calls "notebookbrowser browsercommands" to get
    #   the names of the delegated typemethods, and aliases them all
    #   into the User Code interpreter.

    # The current browser, whenever User Code is interpreted.
    typecomponent currentBrowser 

    # Snit macro variable to accumulate command names; see above.
    set browsercommands {}

    # User interface actions.
    export about-notebook
    export back-page
    export cancel-edits
    export close-window
    export copy-page-as
    export copy-string
    export copy-this-page-as
    export cut-string
    export cycle-recent-pages
    export delete-page
    export delete-pages
    export edit-page
    export edit-preferences
    export edit-this-page
    export export-page-as
    export export-this-page-as
    export find-string
    export find-again
    export forward-page
    export goto-home
    export goto-index
    export goto-next-page
    export goto-page
    export goto-previous-page
    export goto-recent-changes
    export goto-user-code
    export help-index
    export help-introduction
    export help-on
    export help-on-actions
    export help-on-commands
    export help-on-markup
    export insert-page
    export load-page
    export load-this-page
    export load-user-code
    export message-log
    export new-notebook
    export new-window
    export notebook-license
    export notebook-release-notes
    export open-notebook
    export paste-string
    export redo-change
    export refresh-this-page
    export rename-page
    export rename-this-page
    export replace-string
    export request-action
    export save-and-continue
    export save-edits
    export show-index
    export show-recent
    export show-version
    export sidebar-byname
    export sidebar-bytime
    export sidebar-close
    export sidebar-open
    export undo-change

    # Other browser-specific notebook commands
    export codeget
    export current
    export exportformat
    export formatas
    export getsavefile
    export html
    export insert
    export msg
    export nextpage
    export newpage
    export pageexpand
    export prevpage
    export usercode_request as request
    export savefile
    export searchtext
    export showsearch
    export sidebar

    # browsercommands
    #
    # Makes the list of exported typemethods available to dbmanager.
    # See above.
    typemethod browsercommands {} [list return $browsercommands]

    #-------------------------------------------------------------------
    # Type Variables

    # The directory in which the application resides
    typevariable appdir ""

    # This variable lists protected page names.  These pages cannot
    # be deleted or renamed.  Note that "Home" isn't included because
    # it has a variable name; it's checked explicitly instead.
    typevariable protectedPages {"index" "user code"}

    # This variable lists nice English equivalents for the supported
    # export format codes.
    typevariable exportFormats -array {
        notebook      "Notebook Page"
        raw           "raw Notebook markup"
        expanded      "expanded Notebook markup"
        plain         "formatted plain text"
        html-text     "HTML text"
        html-page     "an HTML page"
        mediawiki     "MediaWiki markup"
    }

    #-------------------------------------------------------------------
    # Type Methods

    # appdir path
    # 
    # Sets the application directory path.  Do this before creating any
    # browsers.
    typemethod appdir {path} {
        set appdir $path
    }

    # Returns the currently active browser
    typemethod currentbrowser {} {
        return $currentBrowser
    }

    #-------------------------------------------------------------------
    # Creation Options: These options cannot be reset after creation 
    # time, though there's no check for, so don't try it.
    
    option -db {}

    # 1 if this is read-only, and 0 otherwise
    option -readonly 0

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull
    
    # The name of the home page; it defaults to "Home".
    option -home Home

    # The window title; if not set, the file name is used.
    option -title {}

    # Whether macros should get expanded or not.
    option -expand 1

    #-------------------------------------------------------------------
    # Instance variables

    # The mode is "edit' or "view".
    variable mode {}

    # While editing, page to view when done editing.
    variable pageToViewAfterEditing {}

    # While formatting a page, the current format.
    # See the formats typevariable for valid values.
    # The variable should have the value "notebook" at all times 
    # except when we're actually formatting a page for export.
    variable exportFormat notebook

    # Save Directory
    #
    # This is used as the default save directory by method getsavefile.
    # It's updated automatically with the last directory used;
    # it starts as the nbk file directory.
    variable saveDir

    # Expand Stack
    #
    # This variable holds the pageexpand stack.  Each time a page is
    # expanded, its name is appended to this variable; when the page
    # has finished being expanded, its name is removed.  This is to
    # support the [current] Notebook command, which allows you to
    # retrieve the name of the page currently being expanded.
    variable expandStack {}

    # These variables are only used when exporting a notebook.
    variable exportLinks  ;# Array, maps page name to link ID

    #-------------------------------------------------------------------
    # Components

    # The actionmanager component manages all GUI actions.  Delegate the
    # do method to it, thus giving all components of this window
    # the ability to activate actions.

    component am -public am
    delegate method invoke to am

    # The database component handles the notebook pages.
    delegate method pagetime to db
    delegate method pagename to db as name

    # The statusentry component is a status line also used for 
    # argument entry.
    component status

    # Other components
    component sidebar     ;# The index Sidebar
    component sidetoolbar ;# The Sidebar's Toolbar

    component toolbar     ;# The main toolbar.

    component manager     ;# The BWidget PagesManager that contains the 
                           # viewer and the editor.
    component viewer      ;# The pageviewer
    component editor      ;# The pageeditor

    # The HTML export object
    component html -public html

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        #---------------------------------------------------------------
        # Preliminaries

        # FIRST, withdraw the window, so we don't see it building.
        wm withdraw $win

        # NEXT, The window title will be updated as soon
        # as the first page is displayed, which is normally as soon as the
        # pagebrowser is created.  If Notebook is invoked without a 
        # notebook file, though, no page will be displayed, and the
        # default is ugly.  So replace it.
        wm title $win "Notebook"

        # NEXT, Go ahead and configure the remaining widget options;
        # none are delegated.
        $self configurelist $args

        # NEXT, check the -db option.  Save it as the db component.
        if {$options(-db) eq ""} {
            error "Invalid -db value: not a notebookdb object"
        }

        set db $options(-db)
        $db register $selfns [mymethod DatabaseUpdate]

        # NEXT, save the default save directory:
        set saveDir [file dirname [$db cget -dbfile]]

        # NEXT, prepare for window closing
        windowmanager register $win

        #---------------------------------------------------------------
        # Create Components

        # FIRST, create the actionmanager and define the actions.
        install am using nbactionmanager %AUTO% \
            -toplevel $win \
            -windowtype notebookbrowser \
            -errorcommand [mymethod ErrorHandler] \
            -statecommand [mymethod StateHandler]

        # NEXT, create the statusentry.  It provides a GUI for displaying
        # status and entering arguments.
        install status using statusentry $win.status \
            -errorcommand [mymethod ErrorHandler] \
            -messagecommand [list messagelog logmessage]

        # NEXT, create the toolbar
        install toolbar using maintoolbar $win.toolbar \
            -readonly $options(-readonly) \
            -searchcmd [mymethod SearchHandler]

        # NEXT, create the manager, which allows us to swap between the 
        # viewer and the editor.
        frame $win.browser -borderwidth 2 -relief groove
        install manager using PagesManager $win.browser.manager

        # NEXT, create the page viewer.
        $manager add viewer

        install viewer using pageviewer \
            [$manager getframe viewer].viewer \
            -pagecommand [mymethod PageChange] \
            -unknowncommand [mymethod UnknownPage] \
            -messagecommand [mymethod msg] \
            -readonly $options(-readonly) \
            -dbdir [file dirname [$db cget -dbfile]]

        pack $viewer -side top -fill both -expand true

        # NEXT, create the page editor, unless we're read-only.
        if {!$options(-readonly)} {
            $manager add editor

            install editor using pageeditor \
                [$manager getframe editor].editor \
                -db $db \
                -endcmd  [mymethod EndEdit]
       
            pack $editor -side top -fill both -expand true
        } else {
            set editor ""
        }

        # Next, create the sidebar and its toolbar
        install sidebar using sidebar $win.sidebar \
            -db $db

        install sidetoolbar using sidetoolbar $win.sidetoolbar

        # Next, pack the pages manager and compute the sizes.
        pack $manager -side top -fill both -expand true
        $manager raise viewer
        $manager compute_size

        # NEXT, grid the components where they go.
        grid columnconfigure $win 0 -weight 1
        grid columnconfigure $win 1 -weight 0

        grid rowconfigure $win 0 -weight 0
        grid rowconfigure $win 1 -weight 1
        grid rowconfigure $win 2 -weight 0

        grid $toolbar -row 0 -column 0 -sticky nsew

        grid $win.browser -row 1 -column 0 -sticky nsew

        grid $status -row 2 -column 0 -columnspan 2 -sticky nsew

        # Next, show the sidebar if that's what they want.
        if {[prefs get showsidebar]} {
            $self sidebar-open
        }

        # Next, create the HTML export object
        set html [::nb2html::html %AUTO%]

        #---------------------------------------------------------------
        # Final Preparations

        # NEXT, define the browser key bindings
        $self DefineBrowserKeys

        # NEXT, update the action state now that everything's created.
        $am updatestate
        
        # NEXT, The GUI is fully created; display it!
        # 
        # We call "update" to make sure that everything has taken its final 
        # size before we deiconify.  Then, give the pageviewer the keyboard
        # focus.
        update
        wm deiconify $win
        $viewer focus

        # If there's a User Code page, try to include it.
        if {[$db exists "User Code"]} {
            if {[catch {$self load-user-code} result]} {
                $status msg "Could not load User Code: $result"
                bell
            }
        }

        $self SetMode view
        $am invoke goto-home
    }

    # Defines the browser-specific keystrokes.
    method DefineBrowserKeys {} {
        $am bindkey $editor cancel-edits
        $am bindkey $win    cycle-recent-pages
        $am bindkey $win    edit-page
        $am bindkey $win    edit-this-page
        $am bindkey $win    find-string
        $am bindkey $win    find-again
        $am bindkey $win    goto-next-page
        $am bindkey $win    goto-previous-page
        $am bindkey $win    load-page
        $am bindkey $win    load-this-page
        $am bindkey $win    load-user-code
        $am bindkey $win    new-window
        $am bindkey $win    refresh-this-page
        $am bindkey $win    rename-page
        $am bindkey $win    rename-this-page
        $am bindkey $win    replace-string
        $am bindkey $editor save-edits
    }

    #-------------------------------------------------------------------
    # Destructor

    destructor {
        # Detach from the notebook file (if any); it will be destroyed
        # when the last user detaches.
        catch {$db unregister $selfns}
        catch {dbmanager closedb $db}
        catch {$am destroy}
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Sets the mode to "edit" or "view", raising the appropriate component,
    # setting the editing flag, calling the mode command, and updating
    # idletasks.  If we don't update idletasks, the page's scrollbar won't 
    # update properly if we modify its contents before it has completely 
    # been displayed.

    method SetMode {newMode} {
        set mode $newMode

        if {$newMode eq "edit"} {
            $toolbar setmode editor
            $manager raise editor
            update idletasks
        } else {
            $toolbar setmode viewer
            $manager raise viewer
            update idletasks
        }



        # Update state so that all of the correct buttons are valid.
        $am updatestate
    }

    # When the user finishes editing, this command pops down the editor and
    # restores the browser.
    method EndEdit {} {
        # Always raise the viewer before modifying its contents.
        $self SetMode view

        $status msg ""

        if {[$db exists $pageToViewAfterEditing]} {
            $viewer showpage $pageToViewAfterEditing
        } else {
            $viewer showpage [$viewer current]
        }
    }

    # Called when the displayed page changes in the viewer, and when
    # we begin editing a page in the editor.
    method PageChange {pageName} {
        if {$options(-title) ne ""} {
            set prefix "$options(-title):"
        } else {
            set prefix "Notebook: [file tail [$db cget -dbfile]],"
        }
        
        wm title $win "$prefix $pageName"

        if {$mode ne "edit"} {
            $toolbar configure \
                -pagetime "Last Edit: [$db pagetime $pageName {%D %T}]  "
        }
    }

    # Called when the viewer is asked to display an unknown page.  If the
    # notebook isn't readonly, the user will be invited to create a new
    # page
    method UnknownPage {name} {
        require {!$options(-readonly)} "No such page: '$name'"

        if {[prefs get silentcreation] ||
            [$self askyesno "Page '$name' doesn't exist.  Create it?"]} {
            $self edit-page $name
        }
    }

    # Shows the search page if there's any search text.
    method SearchHandler {searchmode state text} {
        # First, update the sidebar.
        $sidebar configure -searchmode $searchmode -searchtext $text
        $sidebar update
        
        # Next, highlight or clear search text in the currently displayed
        # page
        if {$mode eq "view"} {
            $viewer searchfor $text

            if {$state eq "complete"} {
                $viewer focus

                # TBD: Scroll to next occurrence, if any, once we
                # have a concept of position in the viewer.
            }
        } else {
            $editor searchfor $text

            if {$state eq "complete"} {
                $editor focus

                if {$text ne ""} {
                    $editor find $text
                }
            }
        }

        # Next, if we really have search text, make sure the sidebar is
        # visible.
        if {$text ne ""} {
            $self sidebar-open
        }
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

    # Determines action state for this window.  Returns "disabled" if any 
    # condition isn't met, and "normal" otherwise.
    method StateHandler {action requirements} {
        foreach condition $requirements {
            switch -glob -- $condition {
                browser { }
                editing { 
                    if {![$self editing]} {return disabled} 
                }
                !editing { 
                    if {[$self editing]} {return disabled} 
                }
                !readonly {
                    if {$options(-readonly)} {return disabled}
                }
                <*> { 
                    if {![hasbinding [focus] $condition]} {return disabled}
                }
                default {
                    return disabled
                }
            }
        }

        return normal
    }

    # This method is called when the notebookdb is updated.
    #
    # operation: set|delete
    # name:      a page name or a list
    method DatabaseUpdate {operation name} {
        # FIRST, if we're editing, we don't care--the page we're
        # editing is locked, so others can't play with it anyway.
        if {[$self editing]} {
            return
        }

        # NEXT, it depends on the operation
        switch -exact -- $operation {
            set {
                # Always refresh on set; they might have created a page,
                # which might activate a link.
                $self refresh-this-page
            }
            delete {
                # If they deleted the page we're viewing, we have to
                # display something else.
                if {[samename $name [$viewer current]]} {
                    $self back-page
                } else {
                    # The current page might have a link to this page.
                    $self refresh-this-page
                }
            }
            rename {
                set oldName [lindex $name 0]
                set newName [lindex $name 1]

                # If they renamed the page we're viewing, display the
                # new page; otherwise, just refresh the current page.
                if {[samename $oldName [$viewer current]]} {
                    $self goto-page $newName
                } else {
                    # The current page might have a link to the
                    # changed page.
                    $self refresh-this-page
                }
            }
            default {
                error "Unknown database update operation: '$operation'"
            }
        }
    }


    #------------------------------------------------------------------
    # Public methods

    delegate method pageexists   to db      as exists

    delegate method forwardpage  to viewer

    delegate method msg          to status
    delegate method request      to status

    delegate method insert       to editor

    # usercode_request ?option value ...?
    #
    # This method is aliased into the User Code interpreter as
    # "request", and calls the real "request" method.  It wraps
    # the -command option so that the user's command gets called
    # in the User Code interpreter.
    #
    method usercode_request {args} {
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        set arglist {}

        foreach {option value} $args {
            if {$option eq "-command"} {
                lappend arglist -command [mymethod EvalRequest $value]
            } else {
                lappend arglist $option $value
            }
        }

        $self request $arglist
    }

    method EvalRequest {cmd args} {
        foreach arg $args {
            lappend cmd $arg
        }

        $self evaluser $cmd
    }


    # Return the name of the current page.  If we're editing,
    # this is the page we're editing.  If we're browsing, 
    # the page we're browsing.  If we're expanding pages (possibly
    # just before browsing, the toplevel page being expanded--unless
    # there are arguments.
    #
    # current level     The number of items on the expandStack.
    # current 0         The page on the top of the stack.
    # current #0        The page on the bottom of the stack (the toplevel
    #                   page.
    # current 1         The page which is including the page on the
    #                   bottom of the stack (etc.)
    method current {{num ""}} {
        if {[$self editing]} {
            return [$editor current]
        } elseif {[llength $expandStack] > 0} {
            return [$self CurrentExpansion $num]
        } else {
            return [$viewer current]
        }
    }

    method CurrentExpansion {num} {
        if {$num eq ""} {
            set num "#0"
        }

        if {$num eq "level"} {
            return [llength $expandStack]
        }

        if {[string index $num 0] == "#"} {
            set num [string range $num 1 end]
            return [lindex $expandStack $num]
        } else {
            return [lindex $expandStack end-$num]
        }
    }


    # Evaluate script in the context of the page database, handling
    # errors in the canonical way.  Calls EvalUserCode to do the
    # dirty work.
    method evaluser {script} {
        global errorInfo
        global errorCode

        $status msg ""

        if {[catch {$self EvalUserCode $script} msg]} {
            $self ErrorHandler $msg $errorInfo $errorCode
            return
        }

        return $msg
    }
    
    # Evaluate script in the context of the page database, first setting
    # currentBrowser so that Notebook Commands that affect the browser
    # will affect the correct one.
    #
    # This is an internal version that implies no specific error handling
    #
    # Saves the old currentBrowser value, and restores it at the end.
    # Thus, if the script somehow invokes action in some other browser,
    # everything will be OK when control returns to this browser.
    method EvalUserCode {script} {
        set oldBrowser $currentBrowser
        set currentBrowser $win

        try {
            set result [$db eval $script]
        } finally {
            set currentBrowser $oldBrowser
        }

        return $result
    }

    # Expands the text using the notebookdb's slave interpreter's 
    # textutil::expander, and returns the expansion.
    # Sets currentBrowser before the text is expanded, so Notebook Commands
    # that depend on the Browser will do the right thing.
    #
    method expand {text} {
        set oldBrowser $currentBrowser
        set currentBrowser $win

        try {
            set result [$db expand $text]
        } finally {
            set currentBrowser $oldBrowser
        }

        return $result
    }

    # Returns the expanded text of the page, which must exist.
    method pageexpand {name} {
        # Don't use $db pageexpand, as it doesn't set currentBrowser.
        if {$options(-expand)} {
            lappend expandStack $name

            try {
                set result [$self expand [$db get $name]]
            } finally {
                set expandStack [lrange $expandStack 0 end-1]
            }
            return $result
        } else {
            return [$db get $name]
        }
    }

    # Presents the question in the statusentry, and asks "y/n".
    method askyesno {question} {
        set result [$status request \
                        -prompt "$question (y/n)" \
                        -enum {Y y N n} \
                        -strict 1]

        return [string equal -nocase [lindex $result 0] "Y"]
    }

    # Return 1 if we're editing and 0 otherwise
    method editing {} {
        return [expr {$mode eq "edit"}]
    }

    # Display a message.  This is provided to support the 
    # deprecated "message" notebook command.
    method message {messageText {icon "error"}} {
        tk_messageBox -icon $icon -parent $win \
            -title "Notebook Message" \
            -message $messageText \
            -type ok
    }

    # name      A page name; defaults to the current page.
    # pattern   A glob-pattern, or "".  Defaults to ""
    #
    # If no pattern is specified, returns the name of the next
    # page in the list shown in the Sidebar, or "" if there is
    # no next page.  
    #
    # If a pattern is specified, returns the name of the next
    # page in alphabetical order whose title matches the pattern,
    # or "" if there is no next page.
    #
    # Pass a pattern of "*" to always get the next page in
    # alphabetical order, independent of the sidebar.
    method nextpage {{name ""} {pattern ""}} {
        if {$name eq ""} {
            set name [$viewer current]
        }

        if {$pattern ne ""} {
            return [$db nextpage $name $pattern]
        } else {
            return [$sidebar nextpage $name]
        }
    }

    # name              A page name.  Must not exist.
    # template      Optional: A template to add to the page.
    #
    # Requests the browser to create a new page, 
    # initializing it with the specified template.
    #
    # Returns the new page's name.
    method newpage {name {template ""}} {
        require {!$options(-readonly)} "This document is read-only."
        require {![$self editing]}     "Please finish editing first."
        require {![$db exists $name]}  "Page '$name' already exists."

        # Save the page
        $db set $name $template
        $db save

        return $name
    }

    # name      A page name; defaults to the current page.
    # pattern   A glob-pattern, or "".  Defaults to ""
    #
    # If no pattern is specified, returns the name of the previous
    # page in the list shown in the Sidebar, or "" if there is
    # no next page.  
    #
    # If a pattern is specified, returns the name of the previous
    # page in alphabetical order whose title matches the pattern,
    # or "" if there is no next page.
    #
    # Pass a pattern of "*" to always get the next page in
    # alphabetical order, independent of the sidebar.
    method prevpage {{name ""} {pattern ""}} {
        if {$name eq ""} {
            set name [$viewer current]
        }

        if {$pattern ne ""} {
            return [$db prevpage $name $pattern]
        } else {
            return [$sidebar prevpage $name]
        }
    }

    # Returns true if the page is protected (cannot be renamed or deleted)
    # and false otherwise.
    method protected {name} {
        set name [string tolower [::markupparser::normalizeSpace $name]]

        if {[string equal $name [string tolower $options(-home)]] ||
            [lsearch -exact $protectedPages $name] != -1} {
            return 1
        } else {
            return 0
        }
    }

    # Formats a page as text of some sort.
    #
    # format   The output format, from exportFormats.
    # name     The page name.
    # args     Options, which can vary by format.

    method formatas {format name args} {
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        # Check errors
        assert {[$db exists $name]}

        # Get canonical form
        set name [$db name $name]

        # Format the page
        try {
            set oldFormat $exportFormat
            set exportFormat $format

            switch -exact -- $format {
                raw {
                    set text [$db get $name]
                }
                expanded {
                    set text [$self pageexpand $name]
                }
                plain {
                    set lineLength 65
                    set text [string toupper $name]
                    append text "\n"
                    append text [string repeat "-" $lineLength]
                    append text "\n\n"
                    append text [::markupparser::formatplain \
                                     [$self pageexpand $name] \
                                     -length $lineLength]
                }
                html-page {
                    set text [$html htmlpage $name \
                                  [$html htmltext [$self pageexpand $name]]]
                }
                html-text {
                    set text [$html htmltext [$self pageexpand $name]]
                }
                mediawiki {
                    set text [nb2mediawiki::wikitext [$self pageexpand $name] $args]
                }
                default {
                    error "Unknown page format: $format"
                }
            }
        } finally {
            set exportFormat $oldFormat
        }

        return $text
    }

    # Returns the current export format.  This is for use in 
    # embedded macros, mostly.
    method exportformat {} {
        return $exportFormat
    }

    # Saves the text to disk.
    #
    # filename       A file name
    # text           Text to save.
    method savefile {filename text} {
        try {
            set f [open $filename w]
            puts $f $text
            close $f
        } catch -msg msg {
            catch {close $f}
            error "Could not save $filename: $msg" "" USER
        }
    }

    # Prompts the user for a save file name, given the parameter
    #
    # filename       Default file name, or ""
    # filetype       Default file type, e.g., ".html"
    # title          Dialog box title
    method getsavefile {{filename ""} {filetype ".txt"} {title "Save File As..."}} {
        set filename [tk_getSaveFile \
                          -parent $win \
                          -defaultextension $filetype \
                          -initialdir $saveDir \
                          -initialfile $filename \
                          -title $title]

        if {$filename ne ""} {
            set saveDir [file dirname $filename]
        }

        return $filename
    }

    # Retrieves the Tcl code from a page.  If the page doesn't exist,
    # or there's no code, returns "".
    method codeget {name} {
        if {![$db exists $name]} {
            return ""
        }

        set codelist {}
        foreach {tag text} [::markupparser::parse [$self pageexpand $name]] {
            if {$tag eq "TCL"} {
                lappend codelist $text
            }
        }

        return [join $codelist "\n\n\n"]
    }

    # Search for text and show the results in the Search page.
    # If the search text is cleared, reload the page so as to
    # clear the highlights.
    method showsearch {text} {
        $toolbar configure -searchtext $text
    }

    # Return the current searchtext.
    method searchtext {} {
        return [$toolbar cget -searchtext]
    }

    # Return the list of pages shown in the sidebar
    method {sidebar pages} {} {
        return [$sidebar pages]
    }

    # Return the list of pages selected in the sidebar
    method {sidebar selection} {} {
        return [$sidebar selectedpages]
    }

    #-------------------------------------------------------------------
    # Delegate Action Handlers

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

    #-------------------------------------------------------------------
    # Explicit Action Handlers
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

    # Action: back-page
   method back-page {} {
        # Check here; pageviewer knows nothing about editing.
        require {![$self editing]} "Please finish editing first."

        $viewer backpage
        $status msg ""
    }

    # Action: cancel-edits
    delegate method cancel-edits to editor as canceledits

    # Action: close-window
    method close-window {} {
        require {![$self editing]} "Please finish editing first."

        $am close-window
    }

    # Action: copy-page-as
    #
    # Copies a page to the clipboard in the specified format,
    # prompting for the page if necessary.
    method copy-page-as {format {name ""}} {
        # Get default arguments
        if {"" == $name} {
            $status request \
                -command [mymethod Do-copy-page-as $format] \
                -prompt "Page to copy" \
                -enum [$db pages] \
                -strict 1 \
                -default [$viewer current]
        } else {
            $self Do-copy-page-as $format $name
        }
    }

    # Action: copy-this-page-as
    #
    # Copies this page to the clipboard in the given format.
    method copy-this-page-as {format} {
        $self Do-copy-page-as $format [$viewer current]
    }

    # Copies a page to the clipboard using the specified
    # format.
    method Do-copy-page-as {format name} {
        # Check errors
        require {[$db exists $name]} \
            "Can't copy; no such page: '$name'"

        set text [$self formatas $format $name]

        # Copy the text to the clipboard
        clipboard clear
        clipboard append $text

        $status msg "Copied '$name' to clipboard as $exportFormats($format)."
    }

    # Action: cycle-recent-pages
    delegate method cycle-recent-pages to viewer as cyclerecent

    # Action: delete-page
    #
    # Prompts for the page to delete; defaults to the current page.
    method delete-page {{name ""}} {
        require {!$options(-readonly)} "This document is read-only."
        require {![$self editing]} "Please finish editing first."

        # Get default arguments
        if {"" == $name} {
            $status request \
                -command [mymethod Do-delete-page] \
                -prompt "Page to delete" \
                -enum [$db pages] \
                -strict 1 \
                -default [$viewer current]
        } else {
            $self Do-delete-page $name noconfirm
        }
    }

    method Do-delete-page {name {flag confirm}} {
        # Check errors
        require {[$db exists $name]} \
            "Can't delete; no such page: '$name'"

        require {![$self protected $name]} \
            "Can't delete; protected page: '$name'"

        require {![$db locked $name]} \
            "Can't delete; page is locked: '$name'"

        # Get canonical form
        set name [$db name $name]

        # Confirm
        #
        # TBD: This really needs to be made undoable, so that it doesn't need
        # to be confirmed.
        if {$flag eq "confirm" &&
            ![$self askyesno "Delete page '$name'... Are you sure?"]} {
            return
        }

        $db delete $name
        $db save

        $status msg "Deleted '$name'"

        # NOTE: The normal database update will handle the display
        # update.
    }


    # Action: delete-pages
    #
    # Deletes a list of pages; defaults to the sidebar selection.
    method delete-pages {{pages ""}} {
        require {!$options(-readonly)} "This document is read-only."
        require {![$self editing]} "Please finish editing first."

        # FIRST, If they didn't give us a page list, get it from the
        # sidebar.  Either way, query whether they really want us to
        # delete them or not.
        if {[llength $pages] == 0} {
            set pages [$self sidebar selection]
            require {[llength $pages] > 0} \
                "There are no pages selected in the sidebar."
        }

        set num [llength $pages]
        if {![$self askyesno "Delete $num pages (this cannot be undone)?"]} {
            return
        }

        foreach name $pages {
            $self msg "Deleting page '$name'..."
            update idletasks
            $db delete $name
        }

        $db save

        $self msg "Pages deleted."
    }

    # Action: edit-page ?name? ?nextpage? ?template?
    #
    # name:     The page name; defaults to user request.
    # nextpage: The page to display when done editing.  Defaults to name
    # template: Template text to insert into the page.  Defaults to ""
    #
    # Only name is requested from the user.
    #
    # Prompts the user for a page to edit if need be.
    method edit-page {{name ""} {nextpage ""} {template ""}} {
        require {!$options(-readonly)} "This document is read-only."
        require {![$self editing]} "Please finish editing first."

        if {$name eq ""} {
            $status request \
                -command [mymethod Do-edit-page] \
                -prompt "Page to edit" \
                -enum [$db pages] \
                -default [$viewer current]
        } else {
            $self Do-edit-page $name $nextpage $template
        }
    }

    method Do-edit-page {name {nextpage ""} {template ""}} {
        require {![$db locked $name]} \
            "Page '$name' is locked and cannot be edited."

        if {"" == $nextpage} {
            set nextpage $name
        }

        set pageToViewAfterEditing $nextpage

        # Always raise the editor before modifying its contents.
        $self SetMode edit
        $self PageChange $name
        $editor edit $name $template

        # Update state so that all of the correct buttons are valid.
        $am updatestate
    }

    # Action: edit-this-page 
    #
    # Edits the current page.
    # The edit-page action actually handles everything.
    method edit-this-page {} {
        $self edit-page [$viewer current]
    }

    # Action: export-notebook-as-html-file
    #
    # Prompts the user to save the Notebook's content to a single
    # HTML file.  Prompts for the file name.
    method export-notebook-as-html-file {} {
        # Determine the default file name
        set filetype ".html"

        set nbkname [file tail [$db cget -dbfile]]
        set filename "[file rootname $nbkname]$filetype"

        # Get the file name.
        set filename [$self getsavefile \
                          $filename \
                          $filetype\
                          "Export Notebook As An HTML File"]

        if {$filename ne ""} {
            $self saveAsHtmlFile $filename
            $status msg "Exported $nbkname to $filename."
        } else {
            $status msg "Cancelled."
            bell
        }
    }

    # Action: export-notebook-as-html-set
    #
    # Prompts the user to save the Notebook's content to a set of
    # HTML files. Prompts for the directory name.
    method export-notebook-as-html-set {} {
        # Determine the default directory name
        set filetype ".html"

        set nbkname [file tail [$db cget -dbfile]]
        set dirname [file dirname [$db cget -dbfile]]

        # Get the directory name.
        set dirname [tk_chooseDirectory \
                         -parent $win \
                         -title "Export Notebook to Directory" \
                         -initialdir $dirname]

        if {$dirname eq ""} {
            $status msg "Cancelled."
            bell
            return
        }

        if {![file exists $dirname]} {
            try {
                file mkdir $dirname
            } catch -msg msg {
                error "Could not create directory '$dirname': $msg" "" USER
            }
        } else {
            set filelist [glob -nocomplain -- [file join $dirname *]]

            if {[llength $filelist] > 0} {
                set question \
                "'[file tail $dirname]' has files in it. Export to it anyway?"
                if {![$self askyesno $question]} {
                    $status msg "Cancelled."
                    bell
                    return
                }
            }
        }
        
        $self saveAsHtmlSet $dirname
        $status msg "Exported $nbkname to '$dirname/...'"
    }

    # Action: export-page-as
    #
    # Exports a page to a disk file in the specified format,
    # prompting for the page if necessary; always prompts for
    # the file name.
    method export-page-as {format {name ""}} {
        # Get default arguments
        if {"" == $name} {
            $status request \
                -command [mymethod Do-export-page-as $format] \
                -prompt "Page to export" \
                -enum [$db pages] \
                -strict 1 \
                -default [$viewer current]
        } else {
            $self Do-export-page-as $format $name
        }
    }

    # Action: export-this-page-as
    #
    # Prompts the user to save the current page's content to a disk file 
    # in the specified format.  Prompts for the file name.
    method export-this-page-as {format } {
        $self Do-export-page-as $format [$viewer current]
    }

    # Prompts the user for a file name and saves the formatted
    # page to that file.  The format is as defined for method formatas.
    method Do-export-page-as {format name} {
        # Check errors
        require {[$db exists $name]} \
            "Can't export; no such page: '$name'"

        # Determine the default file type
        if {[string match "html-*" $format]} {
            set filetype ".html"
        } else {
            set filetype ".txt"
        }

        # Get the file name.
        set filename [$self getsavefile \
                          "[TextToID $name]$filetype" \
                          $filetype\
                          "Export Page As $format"]

        if {$filename ne ""} {
            # Format the page
            set text [$self formatas $format $name]

            $self savefile $filename $text
            
            $status msg "Exported '$name' as $exportFormats($format) to $filename."
        } else {
            $status msg "Cancelled."
            bell
        }
    }

    # Action: find-string
    #
    # Prompts the user for a string to find while editing.
    method find-string {{string ""}} {
        if {$string ne ""} {
            $self showsearch $string
        } else {
            # Move the cursor to the toolbar's searchentry.
            $toolbar focus
        }
    }

    # Action: find-again
    delegate method find-again to editor as findagain

    # Action: forward-page
    method forward-page {} {
        # Check here; pageviewer knows nothing about editing.
        require {![$self editing]} "Please finish editing first."

        $viewer forwardpage
        $status msg ""
    }

    # Action: goto-home
    method goto-home {} {
        $self goto-page $options(-home)
    }

    # DEPRECATED Action: goto-index
    method goto-index {} {
        $self goto-page Index
    }

    # Action: goto-next-page
    #
    # name:    Optionally, a page name; defaults to current page.
    # pattern: A glob-pattern or ""; defaults to ""
    #
    # Goes to the next page in the set defined by the pattern.
    method goto-next-page {{name ""} {pattern ""}} {
        require {![$self editing]} "Please finish editing first."

        set page [$self nextpage $name $pattern]

        require {$page ne ""} "This is the last page."

        $viewer showpage $page

        $status msg ""
    }

    # Action: goto-page ?name?
    #
    # Prompts the user for a page to view, if need be.
    method goto-page {{name ""}} {
        require {![$self editing]} "Please finish editing first."

        if {$name eq ""} {
            $status request \
                -command [list $viewer showpage] \
                -prompt "Page to view" \
                -enum [$db pages]
        } else {
            $viewer showpage $name
        }
        $status msg ""
    }

    # Action: goto-previous-page
    #
    # name:    Optionally, a page name; defaults to current page.
    # pattern: A glob-pattern or ""; defaults to ""
    #
    # Shows the previous page in the set defined by the pattern.

    method goto-previous-page {{name ""} {pattern ""}} {
        require {![$self editing]} "Please finish editing first."

        set page [$self prevpage $name $pattern]

        require {$page ne ""} "This is the last page."

        $viewer showpage $page

        $status msg ""
    }

    # Action: goto-recent-changes
    # DEPRECATED
    method goto-recent-changes {} {
        $self goto-page "Recent Changes"
    }

    # Action: goto-user-code
    method goto-user-code {} {
        $self goto-page "User Code"
    }

    # Action: insert-page ?name?
    #
    # Prompts the user for a page to insert into the editor.
    method insert-page {{name ""}} {
        require {[$self editing]}    "You aren't editing a page."

        if {$name eq ""} {
            $status request \
                -command [mymethod Do-insert-page] \
                -prompt "Page to insert" \
                -enum [$db pages] \
                -strict 1
        } else {
            $self Do-insert-page $name
        }
    }

    method Do-insert-page {name} {
        require {[$db exists $name]} "There is no page named '$name'."

        $editor insert [$db get $name]
        $status msg "Inserted page '$name'"
    }

    # Action: load-page ?name?
    #
    # Loads the Tcl code from a page; prompts the user for the name if needed.
    method load-page {{name ""}} {
        require {![$self editing]} "Please finish editing first."

        if {$name eq ""} {
            $status request \
                -command [mymethod Do-load-page] \
                -prompt "Page to load" \
                -enum [$db pages] \
                -strict 1 \
                -default [$viewer current]
        } else {
            $self Do-load-page $name
        }
    }

    method Do-load-page {name} {
        # Gets and expands the named page; then searches for a line beginning
        # "#Tcl".  Everything from that point on is evaluated as Tcl code in the
        # global context.  

        require {[$db exists $name]} \
            "Can't load code page '$name'; no such page."

        set code [$self codeget $name]

        require {[string length $code] > 0} \
            "Can't load code page '$name'; page contains no code."

        try {
            # Reload the specified page's code; then show the 
            # current page again.
            $self EvalUserCode $code
        } catch -msg msg -info einfo {
            error "Error loading code page '$name': $msg" $einfo 
        }
        
        # At initial startup there might be no current page yet; so
        # don't show it if it doesn't exist.
        set current [$viewer current]
            
        if {$current ne ""} {
            $viewer showpage $current
        }

        $status msg "Loaded page '$name'"
    }

    # Action: load-this-page
    method load-this-page {} {
        # First, if the named page is being edited then save it; editing
        # can continue.
        if {[$self editing]} {
            $self save-and-continue
        }

        $self Do-load-page [$viewer current]
    }

    # Action: load-user-code
    method load-user-code {} {
        $self load-page "User Code"
    }


    # Action: new-window
    #
    # Creates a new browser window open on the same notebook file.
    
    method new-window {} {
        # TBD: The call to dbmanager openfile is a little clunky.
        notebookbrowser .%AUTO% \
            -db       [dbmanager openfile [$options(-db) cget -dbfile]] \
            -home     $options(-home)     \
            -readonly $options(-readonly) \
            -title    $options(-title)
        return
    }
    
    # Action: refresh-this-page
    method refresh-this-page {} {
        require {![$self editing]} "Please finish editing first."

        $viewer showpage [$viewer current]
        $status msg "Refreshed."
    }

    # Action: rename-page ?oldname? ?newname?
    #
    # Prompts the user for a page to rename, and for the new name.
    method rename-page {{oldname ""} {newname ""}} {
        require {!$options(-readonly)} "This document is read-only."
        require {![$self editing]} "Please finish editing first."

        set argspec {}

        set promptCount 0

        # NOTE: It's an error if oldname isn't given but newname is--
        # it makes no sense to prompt for some random page to rename
        # to a specific name.  So only prompt for oldname if newname
        # is missing as well.  We'll catch the error in Do-rename-page
        # when we check for oldname's existence.
        if {$newname eq ""} {
            if {$oldname eq ""} {
                incr promptCount
                lappend argspec \
                    -prompt "Page to rename" \
                    -enum [$db pages] \
                    -strict 1 \
                    -default [$viewer current]
            }

            incr promptCount
            lappend argspec \
                -prompt "New page name"
        }

        if {$promptCount == 2} {
            lappend argspec -command [mymethod Do-rename-page]
            $status request $argspec
        } elseif {$promptCount == 1} {
            lappend argspec -command [mymethod Do-rename-page $oldname]
            $status request $argspec
        } else {
            $self Do-rename-page $oldname $newname
        }
    }

    method Do-rename-page {oldname newname} {
        # Requests the pagebrowser to rename the old page with the new name.
        # This will be done if the two names are identical except for 
        # capitalization or if the new name doesn't exist.

        require {![$self protected $oldname]} "Page '$oldname' is protected."
        require {[$db exists $oldname]}       "No such page: '$oldname'"
        require {![$db locked $oldname]}      "Page '$oldname' is locked"

        set current [string tolower [$viewer current]]
        set fixedOldname [string tolower [$db name $oldname]]
        set newname [::markupparser::normalizeSpace $newname]

        require {[string length $newname] != 0} \
            "New page name '$newname' is invalid."

        # NOTE: It's OK to rename a page just to change the canonical casing.
        if {$fixedOldname ne [string tolower $newname]} {
            require {![$db exists $newname]} \
                "A page called '$newname' already exists."
        }

        $db rename $oldname $newname
        $db save

        $status msg "'$oldname' is now '$newname'"

        # NOTE: The normal database update should refresh the display.
    }

    # Action: rename-this-page
    #
    # Prompts the user for the new name.
    method rename-this-page {{newname ""}} {
        $self rename-page [$viewer current] $newname
    }

    # Action: replace-string
    #
    # Prompts the user to find and replace a string.
    method replace-string {} {
        require {[$self editing]}    "You aren't editing a page."

        $status request \
            -command [mymethod Do-replace-string] \
            -prompt "Replace string" \
            -default [$editor wordend] \
            -prompt "With string"
    }

    method Do-replace-string {fromString toString} {
        set count [$editor replace $fromString $toString]
        $status msg "Replaced $count occurrences."
    }

    # Action: save-and-continue
    delegate method save-and-continue to editor as saveandcontinue

    # Action: save-edits
    delegate method save-edits to editor as saveedits

    # Action: show-index
    method show-index {} {
        $sidebar configure -sortorder byname
        $self showsearch ""      ;# Calls $sidebar update
        $self sidebar-open
    }

    # Action: show-recent
    method show-recent {} {
        $sidebar configure -sortorder bytime
        $self showsearch ""      ;# Calls $sidebar update
        $self sidebar-open
    }


    # Action: sidebar-byname
    method sidebar-byname {} {
        $sidebar configure -sortorder byname
        $sidebar update
    }

    # Action: sidebar-bytime
    method sidebar-bytime {} {
        $sidebar configure -sortorder bytime
        $sidebar update
    }

    # Action: sidebar-close
    method sidebar-close {} {
        if {[winfo ismapped $sidebar]} {
            grid forget $sidebar
            grid forget $sidetoolbar
        }
    }

    # Action: sidebar-open
    method sidebar-open {} {
        if {![winfo ismapped $sidebar]} {
            grid $sidetoolbar -row 0 -column 1 -sticky nsew
            grid $sidebar     -row 1 -column 1 -sticky nsew
        }
    }


    #-------------------------------------------------------------------
    # Export Entire Notebook as Single HTML File

    # saveAsHtmlFile filename
    #
    # Exports the entire notebook as a single page.
    # It's assumed that the filename has already been validated.
    method saveAsHtmlFile {filename} {
        set f [open $filename w]
        
        # Next, get the notebook title.
        set nbkname [$html cget -nbtitle]

        if {$nbkname eq ""} {
            set nbkname [file tail [$db cget -dbfile]]
        }

        puts $f "<html><head><title>$nbkname</title>"
        if {[$html cget -css] ne ""} {
            puts $f "<style>\n[$html cget -css]</style>"
        }
        puts $f "</head>\n<body>\n\n"
        puts $f "<h1>$nbkname</h1>\n\n"

        # Get the page names; we'll do the "Home" page first.
        set pages [$db pages]

        set ndx [lsearch -exact $pages "Home"]
        set pages [lreplace $pages $ndx $ndx]
        set pages [linsert $pages 0 "Home"]

        # Next, get the export links.
        $self GetExportLinks

        # Next, export each page.
        $html configure -linkcmd [mymethod ExportInternalLink]

        foreach page $pages {
            $self msg "Exporting '$page'..."
            update idletasks

            puts $f "<p>[$self ExportInternalLink Home Home] | "
            puts $f "[$self ExportInternalLink Index Index]</p>\n"
            puts $f "<hr>\n"
            puts $f "<h1><a name=\"$exportLinks($page)\">$page</a></h1>\n"
        
            puts $f [$self formatas html-text $page]
            puts $f "\n<hr>\n"
        }

        $html configure -linkcmd {}

        # Next, get the timestamp
        set timestamp [GetTimeStamp]
        puts $f "<p><i>Notebook exported on $timestamp</i></p>\n"

        # Next, end the entire page.
        puts $f "</body></html>"

        close $f
        array unset exportLinks
    }

    method GetExportLinks {} {
        # Next, I'll need to create an ID for each page; it's possible
        # that there might be clashes.  So keep a list of the IDs that
        # I've used.
        set pageids {}
        set counter 0

        # First, get an ID for each page.
        array unset exportLinks

        foreach page [$db pages] {
            set baseId [TextToID $page]
            set id $baseId
            while {[lsearch -exact $pageids $id] != -1} {
                incr counter
                set id ${baseId}_$counter
            }

            set exportLinks($page) "$id"
            lappend pageids $id
        }
    }

    method ExportInternalLink {linkText pageName} {
        if {[$db exists $pageName]} {
            set href $exportLinks([$db name $pageName])
            return "<a href=\"#$href\">$linkText</a>"
        } else {
            return "<span style=\"color: red;\">\[$linkText\]</span>"
        }
    }

    
    #-------------------------------------------------------------------
    # Export Entire Notebook as a set of HTML Files

    # saveAsHtmlSet filename
    #
    # Exports the entire notebook as a set of HTML pages within a 
    # directory.  It's assumed that the dirname has already been validated.
    method saveAsHtmlSet {dirname} {
        assert {[file exists $dirname]}
        assert {[file isdirectory $dirname]}

        # First, Get the export links.
        $self GetExportLinks

        # Next, get the timestamp
        set timestamp [GetTimeStamp]

        # Next, get the notebook title.
        set nbkname [$html cget -nbtitle]

        if {$nbkname eq ""} {
            set nbkname [file tail [$db cget -dbfile]]
        }

        # Next, save each file to the directory
        $html configure -linkcmd [mymethod ExportExternalLink]

        foreach page [$db pages] {
            $self msg "Exporting '$page'..."
            update idletasks

            set filename "$exportLinks($page).html"
            set fullname [file join $dirname $filename]
            
            set f [open $fullname w]
            require {$f ne ""} "Could not write to '$fullname'"

            set title "$nbkname: $page"
            puts $f "<html><head><title>$title</title>"
            if {[$html cget -css] ne ""} {
                puts $f "<style>\n[$html cget -css]</style>"
            }
            puts $f "</head>\n<body>\n\n"

            puts $f [$self HtmlSetNavBar $nbkname $page]
            puts $f "<hr>\n"

            puts $f "<h1>&nbsp;$page</h1>\n\n"

            puts $f [$self formatas html-text $page]

            puts $f "\n<hr>\n"
            puts $f [$self HtmlSetNavBar $nbkname $page]

            puts $f "<hr>\n"
            puts $f "<p><i>Notebook exported on $timestamp</i></p>\n"

            puts $f "</body></html>"
            close $f
        }

        # Next, all done.
        $html configure -linkcmd {}
        array unset exportLinks
        bell
    }

    method HtmlSetNavBar {nbkname page} {
        set prev [$self prevpage $page]
        set next [$self nextpage $page]

        set result "<p><b>$nbkname:</b> "
        append result [$self ExportExternalLink Home Home] 
        append result " | "
        append result [$self ExportExternalLink Index Index]

        if {$next ne ""} {
            append result " | Next Page: "
            append result [$self ExportExternalLink $next $next]
        }

        if {$prev ne ""} {
            append result " | Previous Page: "
            append result [$self ExportExternalLink $prev $prev]
        }
        append result "</p>\n"

        return $result
    }

    method ExportExternalLink {linkText pageName} {
        if {[$db exists $pageName]} {
            set href $exportLinks([$db name $pageName])
            return "<a href=\"${href}.html\">$linkText</a>"
        } else {
            return "<span style=\"color: red;\">\[$linkText\]</span>"
        }
    }

    
    #-------------------------------------------------------------------
    # Helper Procs

    proc samename {name1 name2} {
        if {[string tolower $name1] eq [string tolower $name2]} {
            return 1
        } else {
            return 0
        }
    }

    proc TextToID {text} {
        # First, trim any white space and convert to lower case
        set text [string trim [string tolower $text]]

        # Next, substitute "_" for internal whitespace, and delete any
        # non-alphanumeric characters (other than "_", of course)
        regsub -all {[ ]+} $text "_" text
        regsub -all {[^a-z0-9_]} $text "" text
        
        return $text
    }

    proc GetTimeStamp {} {
        set now [clock seconds]
        clock format $now -format "%A, %e %B %Y, %T %p %Z"
    }
}

#-----------------------------------------------------------------------
# The main toolbar

snit::widget maintoolbar {
    delegate option * to hull

    #-------------------------------------------------------------------
    # Creation Options

    # 1 if readonly, 0 otherwise
    option -readonly 0

    #-------------------------------------------------------------------
    # Other Options

    # Expose the search entry by exposing its options.
    delegate option -searchcmd  to searchentry
    delegate option -searchtext to searchentry
    delegate option -searchmode to searchentry as -mode

    option -pagetime {}      ;# Text displayed by pagetime label

    #-------------------------------------------------------------------
    # Components

    component top         ;# Toplevel notebookbrowser; gives us access to
                           # browser-wide resources

    component searchentry ;# The searchentry

    component manager     ;# Manages the swap of the editor and viewer
                           # toolbar components
    component editbar     ;# The editor toolbar
    component viewbar     ;# The viewer toolbar

    #-------------------------------------------------------------------
    # Constructor
    
    constructor {args} {
        # FIRST, acquire the name of the toplevel window, so we can
        # access window resources.
        set top [winfo toplevel $win]

        # NEXT, create the searchentry so that we can get our args.
        install searchentry as searchentry $win.searchentry \
            -width 25 \
            -incremental [prefs get incrementalsearch] \
            -modelist {all "Title and Contents" title "Title Only"}

        if {[prefs get contentsearch]} {
            $searchentry configure -mode all
        } else {
            $searchentry configure -mode title
        }

        # NEXT, Save args
        $self configurelist $args

        # NEXT, create the other constant toolbar elements
        frame $win.sep -width 2 -relief sunken -borderwidth 1
        $top am addbutton $win.index   show-index   -relief flat

        # NEXT, create the manager, so we can swap the viewer and
        # editor components.
        install manager using PagesManager $win.manager

        # NEXT, create the viewer toolbar
        $manager add viewer
        install viewbar using frame \
            [$manager getframe viewer].viewbar

        $top am addbutton $viewbar.back    back-page    -relief flat
        $top am addbutton $viewbar.forward forward-page -relief flat
        $top am addbutton $viewbar.home    goto-home    -relief flat

        label $viewbar.pagetime \
            -textvariable [varname options(-pagetime)] \
            -width 25 \
            -justify right \
            -anchor e

        if {!$options(-readonly)} {
            $top am addbutton $viewbar.edit edit-this-page -relief flat
            pack $viewbar.edit -side right -padx 2
        }

        pack $viewbar.back     -side left -padx 2
        pack $viewbar.forward  -side left -padx 2
        pack $viewbar.home     -side left -padx 2

        pack $viewbar.pagetime -side right

        pack $viewbar -side top -fill both

        # NEXT, create the editor toolbar
        $manager add editor
        install editbar using frame \
            [$manager getframe editor].editbar

        $top am addbutton $editbar.save save-and-continue -relief flat
        pack $editbar.save -side left -padx 2

        frame $editbar.sep1 -width 2 -relief sunken -borderwidth 1
        pack $editbar.sep1 -side left -fill y -padx 1 -pady 1

        $top am addbutton $editbar.cut   cut-string   -relief flat
        $top am addbutton $editbar.copy  copy-string  -relief flat
        $top am addbutton $editbar.paste paste-string -relief flat

        pack $editbar.cut   -side left -padx 2
        pack $editbar.copy  -side left -padx 2
        pack $editbar.paste -side left -padx 2

        frame $editbar.sep2 -width 2 -relief sunken -borderwidth 1
        pack $editbar.sep2 -side left -fill y -padx 1 -pady 1

        $top am addbutton $editbar.undo undo-change -relief flat
        $top am addbutton $editbar.redo redo-change -relief flat

        pack $editbar.undo -side left -padx 2
        pack $editbar.redo -side left -padx 2

        $top am addbutton $editbar.cancel cancel-edits -relief flat
        $top am addbutton $editbar.done   save-edits   -relief flat

        pack $editbar.cancel -side right -padx 2
        pack $editbar.done -side right -padx 2

        pack $editbar -side top -fill both

        # NEXT, pack the toplevel components.
        pack $manager -side left -fill both -expand false
        $manager raise viewer
        $manager compute_size

        pack $searchentry -side right -fill x -expand true -padx 3
        pack $win.index   -side right -padx 1
        pack $win.sep     -side right -fill y -padx 2 -pady 1

    }

    #-------------------------------------------------------------------
    # Public methods

    # Set the mode: viewer or editor
    method setmode {mode} {
        $manager raise $mode
        update idletasks
    }

    # Focus on the search entry
    method focus {} {
        focus $searchentry
    }
}

#-----------------------------------------------------------------------
# The Search Sidebar

snit::widget sidebar {
    #-------------------------------------------------------------------
    # Creation Options

    option -db {}       ;# The page database; used for searching only.

    #-------------------------------------------------------------------
    # Other Options

    option -searchmode {}    ;# Search mode from the search entry.
                              # Should be "all" or "title".

    # Text to search for, or ""
    option -searchtext {}

    # byname | bytime
    option -sortorder byname
    
    #-------------------------------------------------------------------
    # Components

    component top       ;# The toplevel window, which gives us access
                         # to window-wide resources.
    component listbox   ;# The listbox.

    #-------------------------------------------------------------------
    # Lookup Tables

    typevariable sortText -array {
        byname "by name"
        bytime "by time"
    }


    #-------------------------------------------------------------------
    # Instance Variables

    variable pagelist {}  ;# The list of pages displayed by the listbox.

    variable indexmode "" ;# Identifies source of pages, and the sort
                           # order.

    variable lastname {}  ;# The last name displayed by MouseMotion

    #-------------------------------------------------------------------
    # Constructor 

    constructor {args} {
        # FIRST, acquire the name of the toplevel window, so we can
        # access window resources.
        set top [winfo toplevel $win]

        # NEXT, create the listbox and its scrollbar.
        frame $win.frame \
            -borderwidth 1 \
            -relief sunken
        label $win.indexmode \
            -textvariable [myvar indexmode]
        frame $win.sep -height 2 -relief sunken -borderwidth 1

        install listbox using listbox $win.listbox \
            -yscrollcommand "$win.scroll set" \
            -width 20 \
            -height 20 \
            -borderwidth 2 \
            -relief flat \
            -selectmode extended \
            -exportselection 0 \
            -listvariable [myvar pagelist]
        
        scrollbar $win.scroll \
            -command "$listbox yview"
       
        pack $win.indexmode -in $win.frame -side top -fill x
        pack $win.sep -in $win.frame -side top -fill x
        pack $win.scroll -in $win.frame -side right -fill y
        pack $listbox -in $win.frame -side left -expand 1 -fill both
        pack $win.frame -side left -expand 1 -fill both

        # NEXT, configure the args.
        $self configurelist $args

        # NEXT, register to get preferences
        prefs register $selfns [mymethod UsePreferences]

        # NEXT, use those preferences right now!
        $self UsePreferences

        # NEXT, bind to receive mouse events
        bind $listbox <Double-Button-1> [mymethod MouseClick1 %x %y]
        bind $listbox <Motion>          [mymethod MouseMotion %x %y]
        bind $listbox <Leave>           [mymethod Leave]

        # NEXT, register to receive database updates.
        $options(-db) register $selfns [mymethod DbUpdate]

        # NEXT, get the initial set of data.
        $self update
    }

    destructor {
        catch {prefs unregister $selfns}
        catch {$options(-db) unregister $selfns}
    }

    #-------------------------------------------------------------------
    # Public Methods

    # pages
    #
    # Returns the current list of items in the sidebar's list.
    
    method pages {} {
        return $pagelist
    }

    # selectedpages
    #
    # Returns a list of the currently selected pages in the sidebar's list.
    
    method selectedpages {} {
        set result {}

        foreach index [$listbox curselection] {
            lappend result [$listbox get $index]
        }

        return $result
    }

    # nextpage name
    #
    # name     A page name
    #
    # Returns the name of the next page in the sidebar's list following
    # this page, or "" if there is no next page.
    #
    # If the named paged isn't included in the sidebar's list, the next
    # page that *is* (according to the current sort order) is returned.
    
    method nextpage {name} {
        # FIRST, does the name exist.
        if {![$options(-db) exists $name]} {
            return ""
        }

        # NEXT, get the canonical form of the name.
        set name [$options(-db) name $name]

        # NEXT, is the name in our list?
        set ndx [lsearch -exact $pagelist $name]

        if {$ndx != -1} {
            # It is!
            incr ndx
            return [lindex $pagelist $ndx]
        }

        # NEXT, the name isn't in our list (ugh!).  The correct answer
        # depends on the sort order.
        if {$options(-sortorder) eq "byname"} {
            set name [string tolower $name]

            foreach page $pagelist {
                if {[string tolower $page] > $name} {
                    return $page
                }
            }
        } else {
            set t [$options(-db) pagetime $name]

            foreach page $pagelist {
                if {[$options(-db) pagetime $page] < $t} {
                    return $page
                }
            }
        }

        # The page is after the last entry on the list.
        return ""
    }

    # prevpage name
    #
    # name     A page name
    #
    # Returns the name of the previous page in the sidebar's list following
    # this page, or "" if there is no previous page.
    #
    # If the named paged isn't included in the sidebar's list, the previous
    # page that *is* (according to the current sort order) is returned.
    
    method prevpage {name} {
        # FIRST, does the name exist.
        if {![$options(-db) exists $name]} {
            return ""
        }

        # NEXT, get the canonical form of the name.
        set name [$options(-db) name $name]

        # NEXT, is the name in our list?
        set ndx [lsearch -exact $pagelist $name]

        if {$ndx != -1} {
            # It is!
            incr ndx -1
            return [lindex $pagelist $ndx]
        }

        # NEXT, the name isn't in our list (ugh!).  The correct answer
        # depends on the sort order.
        set prevpage ""

        if {$options(-sortorder) eq "byname"} {
            set name [string tolower $name]

            foreach page $pagelist {
                if {[string tolower $page] > $name} {
                    break
                } else {
                    set prevpage $page
                }
            }
        } else {
            set t [$options(-db) pagetime $name]

            foreach page $pagelist {
                if {[$options(-db) pagetime $page] < $t} {
                    break
                } else {
                    set prevpage $page
                }
            }
        }

        # The page is after the last entry on the list.
        return $prevpage
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Update the page list when a page is added, renamed, or deleted.
    method DbUpdate {op data} {
        # Could optimize by updating based on the operation.  For
        # now, just recompute the whole list.
        $self update
    }

    # Update the page list based on the search text, if any, and the
    # current sort order.  This method is called automatically when
    # the database pages change; it must be called explicitly after
    # changing options.
    method update {} {
        if {$options(-searchtext) ne ""} {
            set pagelist [$options(-db) searchx \
                              $options(-sortorder) \
                              $options(-searchmode) \
                              $options(-searchtext)]

            set indexmode "Search, "
        } else {
            if {$options(-sortorder) eq "byname"} {
                set pagelist [$options(-db) pages]
            } else {
                set pagelist [$options(-db) pagesbytime]
            }

            set indexmode "Index, "
        }

        append indexmode $sortText($options(-sortorder))
    }

    # Update appearance when preferences change.
    method UsePreferences {} {
        $listbox configure \
            -font [prefs get bodytext] \
            -foreground [prefs get normalfg] \
            -background [prefs get normalbg] \

        $win.frame configure \
            -background [prefs get normalbg]
    }

    # Go to the specified page
    method MouseClick1 {x y} {
        set name [$listbox get @$x,$y]

        if {$name ne ""} {
            $top invoke goto-page $name
        }
    }

    # Display the page name in the message bar.
    method MouseMotion {x y} {
        set name [$listbox get @$x,$y]

        if {$name ne $lastname} {
            set lastname $name
            $top msg "$name (Last Edit: [$options(-db) pagetime $name {%D %T}])"
        }
    }

    # Clear the message bar as the mouse leaves the listbox.
    method Leave {} {
        set lastname ""
        $top msg ""
    }
}

#-----------------------------------------------------------------------
# The sidebar toolbar

snit::widget sidetoolbar {
    delegate option * to hull
    
    #-------------------------------------------------------------------
    # Components

    # The toplevel window; gives us access to window-wide resources.
    variable top

    #-----------------------------------------------------------------------
    # Constructor 

    constructor {args} {
        # FIRST, acquire the name of the toplevel window, so we can
        # access window resources.
        set top [winfo toplevel $win]

        # NEXT, Save args
        $self configurelist $args

        # NEXT, create components
        $top am addbutton $win.byname sidebar-byname -relief flat
        pack $win.byname -side left -padx 2

        $top am addbutton $win.bytime sidebar-bytime -relief flat
        pack $win.bytime -side left -padx 2

        $top am addbutton $win.hide sidebar-close -relief flat
        pack $win.hide -side right -padx 2
    }
}

