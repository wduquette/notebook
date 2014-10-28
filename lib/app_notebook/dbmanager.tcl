#-----------------------------------------------------------------------
# TITLE:
#	dbmanager.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       A manager for accessing notebookdb objects.
#
#	dbmanager has the following responsibilities:
#
#	* Returning a notebookdb object for a specific notebook file.
#	* Creating no more than one notebookdb object for each notebook file.
#	* Initializing the notebookdb's slave interpreter with the full set
#	  of Notebook Commands defined by the application.
#
#       dbmanager is a singleton object implemented as the sole instance
#	of the dbmanagerType.
#
#	Public operations:
#
#       dbmanager openfile <filename>
#       dbmanager closedb <notebookdb>
#
#	dbmanager open <overWin>
#       dbmanager new <overWin>
#
# LICENSE:
#       Copyright (C) 2005 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

snit::type dbmanagerType {
    #-------------------------------------------------------------------
    # Type Variables

    # File types for the open and save dialogs.
    typevariable fileTypes {
        {{Notebook Files}   {.nbk}        }
        {{All Files}        *             }
    }

    # Constants
    typevariable NORMAL_SUFFIX ".nbk"
    typevariable BACKUP_SUFFIX ".bak"

    # Default page names and their content
    typevariable DefaultPages {
        "Home"             "Hi! Welcome to your new Notebook!"
        "Index"            {[@pageIndex@]}
        "User Code"        "#Tcl\n\# Enter new commands here\n\#unTcl\n"
    }

    # The application directory
    typevariable appdir

    typeconstructor {
        set appdir [file dirname [info script]]
    }

    #-------------------------------------------------------------------
    # Instance Variables

    # This is an array, indexed by normalized notebook filename.
    # The elements are lists: db <notebookdb> ref <refcount>
    variable registry

    #-------------------------------------------------------------------
    # Public Methods

    # Open a notebookdb on a filename.
    # TBD: Should possibly have a read-only option.
    method openfile {filename} {
        # FIRST, put the file name into canonical form as an index key.
        set canonicalName [file normalize $filename]

        # NEXT, do we have a notebookdb for this filename?
        if {[info exists registry($canonicalName)]} {

            # We do.  Increment its reference count.
            array set data $registry($canonicalName)
            incr data(ref)
            set registry($canonicalName) [array get data]

            # Return the object.
            return $data(db)
        }

        # NEXT, if there's no file with this name (yet), copy the default
        # pages if preferences so indicate.
        if {[prefs get includetour] && ![file exists $canonicalName]} {
            try {
                file copy -force \
                    [file join $appdir default.nbk] \
                    $canonicalName
            } on error errmsg {
                error "Could not copy default pages: $errmsg"
            }
        }

        # NEXT, try to open a file with this name.  It might fail with
        # an error, which we won't bother catching; we'd just need to
        # rethrow it.
        set data(db) [::notebookdb::notebookdb create %AUTO% -dbfile $filename]

        # NEXT, it succeeded.  Add it to the registry with a reference
	# count of 1.
        set data(ref) 1
        set registry($canonicalName) [array get data]

        # NEXT, define the Notebook Commands and the required pages
        $self InitializeCommands $data(db)
        $self InitializeContents $data(db)

        # FINALLY, return the new notebookdb.
        return $data(db)
    }

    # Close a notebookdb, and destroy it if it has no more users.
    method closedb {db} {
        # FIRST, put the file name into canonical form as an index key.
        set canonicalName [file normalize [$db cget -dbfile]]

        # NEXT, is this notebookdb registered?
        if {![info exists registry($canonicalName)]} {
            error "cannot close notebookdb '$db': not registered"
        }

        # NEXT, Decrement its reference count.
        array set data $registry($canonicalName)
        incr data(ref) -1

        # NEXT, if users remain, just return.
        if {$data(ref) > 0} {
            set registry($canonicalName) [array get data]
            return
        }

        # NEXT, no users remain; destroy it.
        unset registry($canonicalName)
        $db destroy
    }

    # Allow the user to select an existing notebook file and open it.
    # Returns "" if the user cancels the request, the name of notebookdb 
    # object on success, and throws an error on failures.
    method open {overWin} {
        # First, prompt for the file name.
        set filename [tk_getOpenFile \
                          -title "Open a Notebook" \
                          -parent $overWin \
                          -defaultextension $NORMAL_SUFFIX \
                          -filetypes $fileTypes]
            
        if {[string length $filename] == 0} {
            # They cancelled
            return ""
        }

        # Open a new database with a unique name.  This might fail;
        # don't catch the error, as we'd just have to rethrow it.
        return [$self openfile $filename]
    }

    # Allow the user to select a name for a new notebook file.
    # Returns "" if the user cancels the request, the name of notebookdb 
    # object on success, and throws an error on failures.
    method new {overWin} {
        set filename [tk_getSaveFile \
                          -title "Create a new Notebook" \
                          -parent $overWin \
                          -defaultextension $NORMAL_SUFFIX \
                          -filetypes $fileTypes]

        if {[string length $filename] == 0} {
            # They cancelled
            return ""
        }

        # NEXT, append the suffix if there isn't one. There should be,
        # but Aqua doesn't always put it in.
        if {[file extension $filename] eq ""} {
            append filename $NORMAL_SUFFIX
        }

        # NEXT, this is to be a new file; copy any existing file with
        # the requested name to backup.
        # NOTE: This is somewhat futile, as the new contents will be
        # saved almost immediately, and a new .bak will be created
        # at that time.  We might just as well just delete the darned
        # thing.
        if {[file exists $filename]} {
            set backupName [file rootname $filename]$BACKUP_SUFFIX
            file rename -force -- $filename $backupName
        }

        # Next, just open it.  If they didn't copy the default notebook
        # as a starting point, they'll get a minimum set of pages.
        return [$self openfile $filename]
    }
    

    #-------------------------------------------------------------------
    # Private Methods

    # Initialize a new notebookdb with the full set of Notebook Commands
    method InitializeCommands {db} {
        # FIRST, define a private namespace for Notebook's use
        $db eval "namespace eval ::__notebook:: { }"

        # FIRST, alias "kernel" commands defined elsewhere in the
        # application.
        $db alias clipboard         clipboard
        $db alias super             uplevel \#0
        $db alias version           version
        $db alias parse             ::markupparser::parse
        
        # NEXT, clone certain commands into the User Code interpreter
        $self Clone $db assert
        $self Clone $db require

        # NEXT, alias in the Notebook Browser subcommands.
        foreach name [notebookbrowser browsercommands] {
            $db alias $name   notebookbrowser $name
        }
        
        # NEXT, define "User Code" Notebook Commands.
        $db eval $userCodeCommands
    }

    # Clone a command into the interpreter
    method Clone {db name} {
        set def "proc $name [list [info args $name]] {[info body $name]}"
        $db eval $def
    }

    # Initialize a new notebookdb with the required minimum set of
    # pages, if they aren't there already.
    method InitializeContents {db} {
        set count 0

        foreach {page contents} $DefaultPages {
            if {![$db exists $page]} {
                $db set $page $contents
                incr count
            }
        }

        # If we added any, save the notebook.
        if {$count > 0} {
            $db save
        }
    }

    #-------------------------------------------------------------------
    # User Code Commands
    #
    # This variable contains Notebook Commands defined directly into
    # the slave interpreter.

    variable userCodeCommands {
        # Synchronously asks for a single text string, which it returns.
        proc askfor {prompt} {
            lindex [request -prompt $prompt] 0
        }

        # edittodayslog
        #
        # Edits the current day's log page, initializing it if necessary.
        # The name of the page will be "[current]: yyyy-mm-dd".
        proc edittodayslog {} {
            set logname [current]
            set date [clock format [clock seconds] -format "%Y-%m-%d"]
            set name "$logname: $date"
            
            set macro [list logentry $logname $date]

            if {![pageexists $name]} {
                edit-page $name $logname "\[@$macro@\]\n\n* "
            } else {
                edit-page $name $logname
            }
        }

        # helpbtn helppage
        #
        # Embedded Macro: creates a magic button to jump to a help page.
        proc helpbtn {helppage} {
            return "\[%$helppage|help-on [list $helppage]%\]"
        }

        # logentry
        #
        # logname:  The name of the main log page, e.g., "Log"
        # date:     The date as yyyy-mm-dd.
        #
        # Formats the header for the log entry of that day.  For use in individual
        # log entries, only.
        proc logentry {logname date} {
            # First, convert date to nice form
            set nice [clock format [clock scan $date] -format "%A, %B %d, %Y"]
            
            set pagename "$logname: $date"

            set out "<h>$nice</h> "

            # TBD: Make this prettier.
            if {[string equal $pagename [current]]} {
                append out "\[%Main|goto-page [list $logname]%\]" 
                append out " | "
                append out "\[%Previous|[list goto-previous-page [current] $logname*]%\]" 
                append out " | "
                append out "\[%Next|[list goto-next-page [current] $logname*]%\]" 
            } else {
                append out "("
                append out "\[%edit|edit-page [list $pagename] \[current\] %\] "
                append out "| "
                append out "\[%view|goto-page [list $pagename] %\]"
                append out ")"
            }

            return $out
        }

        # logpage
        #
        # Makes the current page a log page.  The macro expands into a magic
        # button to edit today's log entry, and a concatenation of the data for
        # all log entries:  all of the pages whose names
        # match "[current]: yyyy-mm-dd", in reverse chronological order.
        proc logpage {} {
            # First, get a list of the page names that match.
            set pattern {[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]}
            set plist [lsort -decreasing \
                           [pages "[current]: $pattern"]]
            set output "\[%Edit Today's Entry|edittodayslog%\]\n\n"
            
            # Include seven day's worth; the rest, give an index.
            set lastWeek [lrange $plist 0 6]
            set archive [lrange $plist 7 end]
        
            foreach name $lastWeek {
                append output [string trimright [pageexpand $name]]
                append output "\n\n"
            }
        
            if {[llength $archive] > 0} {
                append output "<h>Older Entries</h>\n\n"
                append output [indexlist $archive]
            }
        
            return $output
        }

        # DEPRECATED; this is here only because the default notebook
        # file used it up through 2.1.2.
        proc showhelp {} { help-introduction }

        #---------------------------------------------------------------
        # TBD: The preceding commands need to be alphabetized with the
        # following commands.


        proc dbfile {} {
            ::db::db cget -dbfile
        }

        proc dbsave {} {
            ::db::db save
        }

        # editmenu ?menuitems?
        #
        # Defines the editmenu contents.  menuitems is a list of 
        # label/notebook command pairs
        proc editmenu {{menuitems ""}} {
            if {![info exists ::__notebook::EditMenuItems]} {
                set ::__notebook::EditMenuItems {
                    "What's This?" {help-on editmenu}
                }
            }
            
            if {$menuitems ne ""} {
                set ::__notebook::EditMenuItems $menuitems
            }

            return $::__notebook::EditMenuItems
        }


        # indexlist pagelist
        #
        # Given a list of pages, formats them into an index listing.
        proc indexlist {pagelist} {
            set text {}
            foreach name $pagelist {
                append text "* \[$name\] <s>([pagetime $name {%D %T}])</s>\n"
            }

            return $text
        }

        # Create a list of magic links to pages, separated by " | ", from the
        # linklist, which should look like "label pagename label pagename..."
        proc linkbar {linklist} {
            set bar {}
            foreach {label name} $linklist {
                append bar "\[%$label|goto-page [list $name]%\] | "
            }
            return [string trim $bar " |"]
        }


        # lshift listvar
        #
        # Extracts the leftmost element from the list stored in $listvar,
        # and returns it; $listvar is updated with the shorted list.
        proc lshift {listvar} {
            upvar $listvar args
            
            if {[llength $args] == 0} {
                set arg ""
            } elseif {[llength $args] == 1} {
                set arg [lindex $args 0]
                set args ""
            } else {
                set arg [lindex $args 0]
                set args [lrange $args 1 end]
            }
            
            return $arg
        }

        proc pagedelete {name} {
            ::db::db delete $name
        }

        proc pageexists {name} {
            ::db::db exists $name
        }

        proc pageget {name} {
            ::db::db get $name
        }

        # pageIndex ?pattern?
        #
        # pattern:  Optional; a string match pattern.  Defaults to "*".
        #
        # Returns a markup index of all pages matching the pattern.
        proc pageIndex {{pattern "*"}} {
            set plist [pages $pattern]
            
            return "[indexlist $plist]\n<b>[llength $plist] Pages</b>\n"
        }

        proc pagerename {oldName newName} {
            ::db::db rename $oldName $newName
        }

        proc pages {{pattern *}} {
            ::db::db pages $pattern
        }

        proc pagesbytime {{pattern *}} {
            ::db::db pagesbytime $pattern
        }

        proc pagesearch {searchText} {
            ::db::db search $searchText
        }

        proc pagename {name} {
            ::db::db name $name
        }

        proc pageset {name value} {
            ::db::db set $name $value
        }

        proc pagetime {name {fmt ""}} {
            ::db::db pagetime $name $fmt
        }

        # recentChanges ?pattern?
        #
        # pattern:     Optional; a string match pattern.  Defaults to "*".
        #
        # Returns a markup index of all pages matching the pattern in reverse
        # chronological order.
        proc recentChanges {{pattern "*"}} {
            set plist [pagesbytime $pattern]
            
            return "[indexlist $plist]\n<b>[llength $plist] Pages\n"
        }
    
        # searchIndex 
        #
        # Search page macro.
        proc searchIndex {} {
            set plist [pagesearch [searchtext]]
            return "[indexlist $plist]\n<b>[llength $plist] Pages\n"
        }

        # Defines a text template
        proc template {name arglist initbody {template ""}} {
            # FIRST, have we an initbody?
            if {"" == $template} {
                set template $initbody
                set initbody ""
            }

            # NEXT, define the body of the new proc so that the initbody, 
            # if any, is executed and then the substitution is 
            set body "$initbody\n    tsubst [list $template]\n"

            # NEXT, define
            uplevel 1 [list proc $name $arglist $body]
        }

        # Like subst, but allows "|<--" on the first line to set the
        # left margin.
        proc tsubst {template} {
            # If the string begins with the indent mark, process it.
            if {[regexp {^(\s*)\|<--[^\n]*\n(.*)$} \
                     $template dummy leader body]} {

                # Determine the indent from the position of the indent mark.
                if {![regexp {\n([^\n]*)$} $leader dummy indent]} {
                    set indent $leader
                }

                # Remove the ident spaces from the beginning of each indented
                # line, and update the template string.
                regsub -all -line "^$indent" $body "" template
            }

            # Process and return the template string.
            return [uplevel 1 [list subst $template]]
        }

        
        # tforeach vars items ?initbody? template
        #
        # vars		A list of index variable names
        # items		A list of items to iterate over
        # initbody	Optional.  Initialization Tcl code.
        # template	A template string.
        #
        # Iterates vars over items in the manner of "foreach".  On each
        # iteration, does a tsubst on the template, accumulating the
        # result.  The tsubst is done in the caller's context; the index
        # variables are available as well.  If specified, the initbody 
        # contains Tcl code to execute at the beginning of each iteration.

        proc tforeach {vars items initbody {template ""}} {
            # FIRST, have we an initbody?
            if {"" == $template} {
                set template $initbody
                set initbody ""
            }

            # NEXT, define the variables.
            foreach var $vars {
                upvar $var $var
            }

            set results ""

            foreach $vars $items {
                if {"" != $initbody} {
                    uplevel $initbody
                }
                set result [uplevel [list tsubst $template]]
                append results $result
            } 
            
            return $results
        }


        # tif condition thenbody ?elsebody?
        #
        # condition	A boolean expression
        # ttemplate	Template to tsubst if condition is true
        # etemplate	Template to tsubst if condition is false;
        #		defaults to ""
        #
        # Calls tsubst in the caller's context on either ttemplate or
        # etemplate, depending on whether condition is true or not.
        
        proc tif {condition ttemplate {"else" "else"} {etemplate ""}} {
            # FIRST, evaluate the condition
            set flag [uplevel 1 [list expr $condition]]
            
            # NEXT, expand one or the other
            if {$flag} {
                uplevel 1 [list tsubst $ttemplate]
            } else {
                uplevel 1 [list tsubst $etemplate]
            }
        }


        # usermenu ?menuitems?
        #
        # Defines the usermenu contents.  menuitems is a list of 
        # label/notebook command pairs
        proc usermenu {{menuitems ""}} {
            if {![info exists ::__notebook::UserMenuItems]} {
                set ::__notebook::UserMenuItems {
                    "What's This?" {help-on usermenu}
                }
            }
            
            if {"" != $menuitems} {
                set ::__notebook::UserMenuItems $menuitems
            }

            return $::__notebook::UserMenuItems
        }
    }
}

dbmanagerType dbmanager