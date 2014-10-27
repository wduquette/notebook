#-----------------------------------------------------------------------
# TITLE:
#	notebookdb.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Notebook application's notebook page database.  Create a new
#	page database by calling notebookdb::notebookdb.  Any number
#	may be created; a single database may be shared by multiple
#	clients.  Note: no file locking is done.
#
# ERROR CODES:
#	notebookdb defines the following error codes:
#
#	::notebook::loaderror
#           The requested -dbfile could not be loaded or created.
#
#       ::notebook::saveerror
#           The -dbfile could not be saved.
#
#       These are environmental errors, which the caller can't 
#	reasonably check before requesting the failed action, so
#	the codes are defined to ease error recovery.
#
#       All other errors are avoidable, and so the error code is not set.
#
# LICENSE:
#       Copyright (C) 2002,2003,2004,2005 by William H. Duquette.  
#       This file may be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Provided package

package provide notebookdb 1.0

package require trycatch
package require snit 0.97
package require markupparser

namespace eval ::notebookdb::notebookdb:: {
    namespace import -force ::trycatch::*
}

#-----------------------------------------------------------------------
# Public Functions

namespace eval ::notebookdb:: {
    namespace export notebookdb
}

snit::type ::notebookdb::notebookdb {
    #-------------------------------------------------------------------
    # Creation Options

    # The database file name.  It must be specified when the database
    # is created.
    option -dbfile ""

    onconfigure -dbfile {value} {
        if {"" != $options(-dbfile)} {
            error "-dbfile cannot be changed after the notebookdb is created"
        }
        set options(-dbfile) $value
    }

    #------------------------------------------------------------------
    # Instance Variables

    # Array of database contents, indexed on page ID.  The page ID is
    # the page name in lower case.
    #
    # id-$id    The ID itself.
    # name-$id  The canonical casing for the page name.
    # lock-$id  1 if the page is locked, 0 (or nonexistent) otherwise.
    # page-$id  The page's text.
    # time-$id  The page's modification time.
    variable db
    variable dbfields {id name lock page time}

    # Observers array.  index is observer name, value is command to execute.
    variable observers

    # Flag: notify observers only if true.
    variable notifyObservers 1

    #
    # CONSTRUCTOR
    #

    constructor {args} {
        global auto_path

        # Save the options
        $self configurelist $args

        set filename $options(-dbfile)

        if {"" == $filename} {
            error "required option -dbfile is missing."
        }

        # Next, try to load the file from disk, if it exists.
        if {[file exists $filename]} {
            interp create $self.loader
            $self.loader alias page $self Loader.Page

            try {
                try {
                    $self.loader eval [list source $filename]
                } catch -msg result {
                    throw notebookdb::loaderror \
                        "Could not load notebook file '$filename': $result"
                }
            } finally {
                interp delete $self.loader
            }
        }

        # NEXT, create the database's slave interpreter and populate it.
        interp create $self.interp
        $self.interp eval [list set auto_path $auto_path]

        $self.interp eval {
            # Create an expander in the slave, but put it in the ::db::
            # namespace so that it's somewhat hidden.
            package require textutil::expander

            namespace eval ::db:: {
                ::textutil::expander PageExpander
                PageExpander setbrackets {[@} {@]}
                PageExpander errmode macro
            }

            # Alias its expand function back into the global namespace of
            # the slave.
            interp alias {} expand {} ::db::PageExpander expand
        }

        # Alias the database object itself into the slave.
        $self.interp alias ::db::db $self
    }
    
    # Destroys the interpreter; all other cleanup is done by snit.
    destructor {
        if {[info commands $self.interp] != ""} {
            interp delete $self.interp
        }
    }

    #
    # Methods
    #

    # Evaluates its args in the database's slave interpreter
    method eval {args} {
        return [uplevel $self.interp eval $args]
    }

    # Aliases a command into the database's slave interpreter.
    #
    # newcmd    The new command to alias into the slave interpreter.
    # targetcmd The command being aliased in.
    # args      Any additional args to targetcmd.

    method alias {newcmd targetcmd args} {
        eval $self.interp alias $newcmd $targetcmd $args
    }

    # Tries to save the database to disk
    method save {} {
        set fname $options(-dbfile)

        try {
            $self SaveDatabase $fname
        } catch -msg errmsg {
            throw notebookdb::saveerror \
                "Could not save notebook file:\n\n'$fname'\n\n$errmsg"
        }
    }

    method backupname {} {
        set fname $options(-dbfile)

        return [file rootname $fname].bak
    }

    # Checks whether there's a page with a given name or not, and returns
    # 1 if so and 0 otherwise
    method exists {name} {
        set id [string tolower $name]
        return [info exists db(id-$id)]
    }

    # Retrieves the text of the named page.  The text is returned as is,
    # with no expansion.
    method get {name} {
        set id [string tolower $name]
        return $db(page-$id)
    }

    # Retrieves the text of the named page, with macros expanded.
    method pageexpand {name} {
        $self expand [$self get $name]
    }

    # Expands macros in the text in the context of the database.
    method expand {text} {
        $self.interp eval [list expand $text]
    }

    # Retrieves the canonical casing of the page name.
    method name {name} {
        set id [string tolower $name]
        return $db(name-$id)
    }

    # If no format string is given, retrieves the timestamp (in seconds) 
    # of the named page.  Otherwise formats the time according to the format.
    #
    # name	The page name
    # fmt	A [clock format] format string.
    method pagetime {name {fmt ""}} {
        set id [string tolower $name]

        if {"" == $fmt} {
            return $db(time-$id)
        } else {
            return [clock format $db(time-$id) -format $fmt]
        }
    }

    # Returns a sorted list of pages, or "" if none match the pattern.
    #
    # pattern  Optional; the pattern to match.  Defaults to *
    method pages {{pattern *}} {
        set plist {}

        foreach ndx [array names db "name-*"] {
            if {[string match -nocase $pattern $db($ndx)]} {
                lappend plist $db($ndx)
            }
        }

        return [lsort -dictionary $plist]
    }

    # Returns a sorted list of page IDs, or "" if none match the pattern.
    #
    # pattern   Optional; the pattern to match.  Defaults to *
    method pageids {{pattern *}} {
        set plist {}

        foreach ndx [array names db "id-*"] {
            if {[string match -nocase $pattern $db($ndx)]} {
                lappend plist $db($ndx)
            }
        }

        return [lsort -dictionary $plist]
    }

    # Returns a list of pages, sorted by time starting with the most
    # recent, or "" if none match the pattern.
    #
    # pattern	Optional; the pattern to match.  Defaults to *
    #
    # TBD: Consider keeping a list of recent edits in the database.
    method pagesbytime {{pattern *}} {
        set plist {}

        foreach ndx [array names db "name-*"] {
            if {[string match -nocase $pattern $db($ndx)]} {
                lappend plist $db($ndx)
            }
        }
        
        return [lsort -decreasing \
                    -command [list [myproc TimeCmp] $self] $plist]
    }

    # lsort comparison function for pagesbytime.
    proc TimeCmp {self p1 p2} {
        set t1 [$self pagetime $p1]
        set t2 [$self pagetime $p2]

        if {$t1 < $t2} {
            return -1
        } elseif {$t2 > $t1} {
            return 1
        } else {
            return 0
        }
    }

    # Returns a list of pages whose names or bodies contain the searchText.
    method search {searchText} {
        $self searchx byname all $searchText
    }

    # Returns a list of pages whose names or bodies contain the searchText.
    # in time order.
    method searchbytime {searchText} {
        $self searchx bytime all $searchText
    }

    # Returns an unsorted list of matches
    method searchx {sort mode searchText} {
        set plist {}

        set contentFlag [string equal $mode all]

        foreach ndx [array names db "name-*"] {
            set name $db($ndx)

            # TBD: search strings containing special characters are 
            # problematic.  I need to fix that.
            if {[string match -nocase "*$searchText*" $name]} {
                lappend plist $name
                continue
            }
            
            if {$contentFlag &&
                [string match -nocase "*$searchText*" [$self get $name]]} {
                lappend plist $name
                continue
            }
        }


        return [$self $sort $plist]
    }

    method byname {pagelist} {
        lsort -dictionary $pagelist
    }

    method bytime {pagelist} {
        lsort -decreasing \
            -command [list [myproc TimeCmp] $self] $pagelist
    }

    # Tries to lock the page.  A locked page cannot be edited (at least,
    # not by another user of this notebookdb).  Returns 1 on 
    # success and 0 if it's already locked.
    method lock {name} {
        set id [string tolower $name]
        
        if {[info exists db(lock-$id)]} {
            return 0
        }

        set db(lock-$id) 1
    }

    # Unlocks the page, whether it was locked or not.
    method unlock {name} {
        set id [string tolower $name]

        if {[info exists db(lock-$id)]} {
            unset db(lock-$id)
        }
    }

    # Returns 1 if the page is locked, and 0 otherwise.
    method locked {name} {
        set id [string tolower $name]
        return [info exists db(lock-$id)]
    }

    # Saves the text for the page.  The page must not be locked.  Does not
    # write the database to disk.  Any trailing whitespace
    # is trimmed, and a final newline is always added.  Also, sets the
    # page's timestamp.
    #
    # name	The page name
    # text	The new page text.
    method set {name text} {
        set id [string tolower $name]

        if {[$self locked $name]} {
            error "Error, '$name' is locked."
        }

        set db(id-$id)   $id
        set db(name-$id) $name
        set db(page-$id) "[string trimright $text]\n"
        set db(time-$id) [clock seconds]

        $self Notify set $name
    }

    # Deletes the page, which must not be locked.  Does not
    # write the database to disk.
    method delete {name} {
        set id [string tolower $name]

        if {[$self locked $name]} {
            error "Error, '$name' is locked."
        }
        
        # NOTE: Originally, this did a loop on 
        # [array names db(*-$id)].  Unfortunately, this means that
        # if you delete Fred you also delete *-Fred.
        foreach field $dbfields {
            if {[info exists db($field-$id)]} {
                unset db($field-$id)
            }
        }

        $self Notify delete $name
    }

    # Renames a page, if possible.  If the newName maps to the same ID as
    # the oldName, it's simply saved for later use.  If it already names some
    # other existing page, an error is thrown.  Otherwise, finds all pages that
    # might include a link to the old name, and renames the link in each one.
    # finally, a new page is created with the old name, and the old page is
    # deleted.
    #
    # It's an error if the page is locked.

    method rename {oldName newName} {
        set oldId [string tolower $oldName]
        set newId [string tolower $newName]

        # First, if the page doesn't exist, throw an error.
        if {![$self exists $oldName]} {
            error "Cannot rename '$oldName'; no such page."
        }

        # Next, if the page is locked, throw an error.
        if {[$self locked $oldName]} {
            error "Error, '$oldName' is locked."
        }

        # Next, if it's just changing the capitalization, change it and
        # return.
        if {[string equal $oldId $newId]} {
            set db(name-$oldId) $newName
            $self Notify set $newName
            return
        }

        # Next, is the new name already in use?
        if {[$self exists $newName]} {
            error "The name '$newName' is already in use."
        }

        set notifyObservers 0

        # Next, create the new page and delete the old one.
        $self set $newName [$self get $oldName]
        $self delete $oldName

        # Next, update links.  Do this after creating the new page, as it
        # guarantees that the new page exists when the other pages are
        # updated.
        foreach pname [$self search "$oldName"] {
            set text [$self get $pname]
            set text [::markupparser::renameLink $text $oldName $newName]
            $self set $pname $text
        }

        set notifyObservers 1
        $self Notify rename [list $oldName $newName]
    }

    # Calls pages to get a list of page names that match the pattern.  If the
    # specified name is in the list, and has a predecessor, the name of the
    # predecessor is returned; otherwise "".
    #
    # name	   The page name
    # pattern  A pattern for retrieving page names.
    method prevpage {name {pattern "*"}} {
        set id [string tolower $name]
        set ids [$self pageids $pattern]

        set ndx [lsearch $ids $id]

        set pred [expr {$ndx - 1}]

        if {$pred < 0} {
            return ""
        }

        return [$self name [lindex $ids $pred]]
    }

    # Calls pages to get a list of page names that match the pattern.  If the
    # specified name is in the list, and has a successor, the name of the
    # successor is returned; otherwise "".
    #
    # name	   The page name
    # pattern  A pattern for retrieving page names.

    method nextpage {name {pattern "*"}} {
        set id [string tolower $name]
        set ids [$self pageids $pattern]

        set ndx [lsearch $ids $id]

        if {$ndx == -1} {
            return ""
        }

        set succ [expr {$ndx + 1}]

        if {$succ == [llength $ids]} {
            return ""
        }

        return [$self name [lindex $ids $succ]]
    }


    # Register observer.  obj is the observing object; command is the
    # command to execute.
    #
    # Registered observers are notified when the notebookdb's contents is
    # modified.  Two arguments will be appended to their command.  
    # The first indicates the nature of the change; the second contains 
    # the relevant data, as shown:
    #
    #     Operation  Data
    #     ---------  -----------------------
    #     set        string: Page name
    #     delete     string: Page name
    #     rename     list: oldname newname
    #
    # Note that renames look like several sets followed by a delete.
   
    method register {obj command} {
        set observers($obj) $command
    }

    # Unregister observer.  obj is the observing object.
    method unregister {obj} {
        unset observers($obj)
    }


    #
    # Private Methods
    #

    # Notify
    #
    # Notifies observers, if any.
    method Notify {operation page} {
        if {!$notifyObservers} {
            return
        }

        foreach name [array names observers] {
            set cmd $observers($name)
            lappend cmd $operation $page
            uplevel \#0 $cmd
        }

        return
    }

    # SaveDatabase fname
    #
    # Save the database to the file.

    method SaveDatabase {fname} {
        if {[file exists $fname]} {
            file rename -force -- $fname [$self backupname]
        }

        set f [open $fname w]

        puts $f "# Notebook Database File"

        foreach name [$self pages] {
            puts $f "\n#--------------------------------------------------"
            puts $f "# $name\n"
        
            puts $f [list page $name [$self get $name] [$self pagetime $name]]
            puts $f ""
        }

        puts $f "\n# End of Notebook Database File"
        close $f
    }

    #
    # Database Loading Commands
    #
    # These commands are aliased into a temporary slave interpreter that's
    # used to load the notebook file.
    #

    # Creates a page in the database.  Aliased to "page".
    # TBD: combine this with method set in some way.
    method Loader.Page {name text {time 0}} {
        set id [string tolower $name]

        set db(id-$id)   $id
        set db(name-$id) $name
        set db(page-$id) [string trimright $text]

        if {$time == 0} {
            set time [clock seconds]
        }
        set db(time-$id) $time
    }
}
