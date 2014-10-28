#-------------------------------------------------------------------------
# TITLE:
#	notebook.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#	Wiki-like personal notebook
#
# LICENSE:
#       Copyright (C) 2005 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.

#-----------------------------------------------------------------------
# Catch Mac OS X open events at startup.
#
# We aren't really ready for open events until the end of this file;
# however, we call "update" when we popup the splash screen, so we
# might well receive some.  The following definition of 
# ::tk::mac::OpenDocument just saves any file names we receive so
# that they can be opened later.  We will redefine OpenDocument
# at the end of the file to open notebooks properly.
#
# If we aren't running under Aqua, then this is irrelevant.

set osxDocsToOpen {}

if {[tk windowingsystem] eq "aqua"} {
    proc ::tk::mac::OpenDocument {args} {
        set ::osxDocsToOpen $args
    }
}

#-----------------------------------------------------------------------
# Copy Encodings

set appdir [file dirname [info script]]

set encodingGlob [file join $appdir .. encoding *]
set encodings [encoding names]

foreach encodingFile [glob -nocomplain $encodingGlob] {
    set encoding [file rootname [file tail $encodingFile]]
    if {[lsearch -exact $encodings $encoding] == -1} {
        file copy -force $encodingFile [file join $tcl_library encoding]
    }
}

#-----------------------------------------------------------------------
# Version

# FIXME
set notebookVersion "V2.2.0"

#-----------------------------------------------------------------------
# Allow notebook to execute scripts.

if {"-script" == [lindex $argv 0]} {
    set script [lindex $argv 1]
    set argv [lreplace $argv 0 1]
    source [lindex $script]
    exit
}

#-------------------------------------------------------------------------
# Do the splash screen

# Withdraw the main window; we might not need it at all.  We'll pop it
# back up if we do.
wm withdraw .

toplevel .splash -background white
wm title .splash "Notebook $notebookVersion"

image create photo splash.gif \
    -file [file join [file dirname [info script]] splash.gif]

pack [label .splash.image \
          -foreground black \
          -background white \
          -justify center \
          -image splash.gif]
    
set sw [winfo screenwidth .splash]
set sh [winfo screenheight .splash]
set rw [winfo reqwidth .splash]
set rh [winfo reqheight .splash]

set x [expr ($sw - $rw)/2]
set y [expr ($sh - $rh)/2]

wm geometry .splash +$x+$y

update

#-----------------------------------------------------------------------
# Utility functions

# Display a message.  This should only be used for debugging.
proc msg {messageText {icon "error"}} {
    tk_messageBox -icon $icon -parent . \
        -title "Notebook Message" \
        -message $messageText \
        -type ok
}

# Return the current version
proc version {} {
    global notebookVersion

    return $notebookVersion
}

#-----------------------------------------------------------------------
# Other required packages

set appdir [file dirname [info script]]

package require gui 1.0
namespace import ::gui::*

package require markupparser
package require notebookdb

# Source in the application files

source [file join $appdir nb2html.tcl]
source [file join $appdir nb2mediawiki.tcl]
source [file join $appdir userprefs.tcl]
source [file join $appdir renderpane.tcl]
source [file join $appdir nbobjects.tcl]
source [file join $appdir pageeditor.tcl]
source [file join $appdir prefs_dialog.tcl]

namespace import ::Notebook::prefs

source [file join $appdir nbactionmanager.tcl]
source [file join $appdir dbmanager.tcl]
source [file join $appdir messagelog.tcl]
source [file join $appdir welcomer.tcl]
source [file join $appdir pageviewer.tcl]
source [file join $appdir helpbrowser.tcl]
namespace import ::Notebook::HelpBrowser::*

source [file join $appdir notebookbrowser.tcl]

# Create images
image create photo ::Notebook::missing \
    -file [file join $appdir missing.gif]

#-----------------------------------------------------------------------
# Mainline code

# Check the arguments
if {[llength $argv] == 0} {
    set notebooks {}
} else {
    foreach name $argv {
        set name [file normalize $name]
        lappend notebooks [file join [pwd] $name]
    }
}

# Read the preferences
prefs load

# Initialize the help browser
helpbrowser [file join $appdir help.nbk]

# Initialize the message log
messagelog init

# Copy the extensions path to the auto_path, and
# try to load the extension packages.
set extpath [string trim [prefs get extpath]]
if {$extpath ne ""} {
    lappend auto_path $extpath
}

if {[catch {package require Img 1.3} result]} {
    messagelog logmessage "Img Extension: not loaded"
} else {
    messagelog logmessage "Img Extension: loaded"
}

# Add the initial OS X file names, if any
set notebooks [concat $notebooks $osxDocsToOpen]

# Create the initial Notebook browsers
notebookbrowser appdir $appdir

if {[llength $notebooks] == 0} {
    welcomer .%AUTO%
    destroy .splash
} else {
    destroy .splash
    foreach notebook $notebooks {
        try {
            if {[file extension $notebook] eq ""} {
                append notebook ".nbk"
            }
            
            set db [dbmanager openfile $notebook]
            notebookbrowser .%AUTO% -db $db
        } catch -msg msg -code code -info info {
            onerr notebookdb::loaderror {
                welcomer .%AUTO% -errormsg $msg
            } * {
                puts stderr $info
                exit 1
            }
        }
    }
}

#-----------------------------------------------------------------------
# Redefine ::tk::mac::OpenDocument
#
# See the discussion at the top of this file.  
#
# This proc will receive OS X open events after the application has
# gotten initialized, and will open new windows for the specified
# notebook files.

if {[tk windowingsystem] eq "aqua"} {
    proc ::tk::mac::OpenDocument {args} {
        foreach name $args {
            try {
                set newdb [dbmanager openfile $name]
            } catch -msg msg -info einfo -code code {
                onerr notebookdb::loaderror {
                    error $msg {} USER
                } * {
                    error $msg $einfo $code
                }
            } 
            
            if {$newdb eq ""} {
                error "Cancelled." {} USER
            }
            
            notebookbrowser .%AUTO% -db $newdb
        }
    }
}
