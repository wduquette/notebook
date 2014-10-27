#-----------------------------------------------------------------------
# TITLE:
#	helpbrowser.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       A browser for on-line help in Notebook format.
#
# LICENSE:
#       Copyright (C) 2002,2003,2004,2005 by William H. Duquette.  
#       This file may be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Package Definition
#
# Not a separate package, at the moment.

#-----------------------------------------------------------------------
# Namespace

namespace eval ::Notebook::HelpBrowser:: {
    namespace export {[a-z]*}

    # The "" array contains information about the helpbrowser.  There
    # is only ever one.
    #
    # (-initialized) True if it's been initialized, false otherwise.
    # (-helpfile)    The help database file name
    variable ""
    set (-initialized) 0
    set (-helpfile) ""
    
}

#-----------------------------------------------------------------------
# Public Methods

# helpbrowser helpfile
#
# helpfile:   Name of the help database file.
#
# Saves sufficient information to create the help browser when it is
# wanted.

proc ::Notebook::HelpBrowser::helpbrowser {helpfile} {
    variable ""

    # First, calling this twice is an error.
    if {$(-initialized)} {
        error "helpbrowser already initialized"
    }

    # Next, initialize the object's data structures with defaults
    set (-initialized) 1
    set (-helpfile) $helpfile
}

# showhelp ?helppage?
#
# helppage:    The name of the page to show; defaults to "Help".
#
# Displays the named page in the help browser, first creating it if
# necessary.

proc ::Notebook::HelpBrowser::showhelp {{helppage "Help"}} {
    variable ""

    # First, create the browser if need be.
    if {[info commands .helpbrowser] eq ""} {
        MakeBrowser
    }

    # Pop it up
    wm deiconify .helpbrowser
    raise .helpbrowser

    # Show the help topic.
    if {[string tolower $helppage] eq "index"} {
        .helpbrowser goto-page "Help"
        .helpbrowser show-index
    } elseif {[.helpbrowser pageexists $helppage]} {
        .helpbrowser goto-page $helppage
    } else {
        .helpbrowser showsearch $helppage
    }
}

#-----------------------------------------------------------------------
# Private Methods

# MakeBrowser
#
# Creates the help browser window.

proc ::Notebook::HelpBrowser::MakeBrowser {} {
    variable ""

    # TBD: Consider passing the help file name and letting the
    # notebookbrowser open the file.
    try {
        set db [dbmanager openfile $(-helpfile)]
    } catch -msg errmsg {
        error "Notebook Help could not open help file $(-helpfile): $errmsg"
    }

    # Create the browser
    notebookbrowser .helpbrowser \
        -db $db \
        -title "Notebook Help" \
        -readonly 1 \
        -home Help

}