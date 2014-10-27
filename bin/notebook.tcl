#!/bin/sh
# -*-tcl-*-
# the next line restarts using tclsh\
exec tclsh "$0" "$@"

#-------------------------------------------------------------------------
# NAME: notebook.tcl
#
# PROJECT:
#  notebook: Your project description
#
# DESCRIPTION:
#  Loader script for the notebook(1) tool.
#
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# Prepare to load application

set bindir [file dirname [info script]]
set libdir [file normalize [file join $bindir .. lib]]

set auto_path [linsert $auto_path 0 $libdir]

# -quill-tcl-begin
package require Tcl 8.6.1
# -quill-tcl-end

# quillinfo(n) is a generated package containing this project's 
# metadata.
package require quillinfo

# If it's a gui, load Tk.
if {[quillinfo isgui notebook]} {
# -quill-tk-begin
package require Tk 8.6.1
# -quill-tk-end
}

# notebookapp(n) is the package containing the bulk of the 
# notebook code.  In particular, this package defines the
# "main" procedure.
package require notebookapp
namespace import notebookapp::*

#-------------------------------------------------------------------------
# Invoke the application

if {!$tcl_interactive} {
    if {[catch {
        main $argv
    } result eopts]} {
        if {[dict get $eopts -errorcode] eq "FATAL"} {
            # The application has flagged a FATAL error; display it 
            # and halt.
            puts $result
            exit 1
        } else {
            puts "Unexpected error: $result"
            puts "Error Code: ([dict get $eopts -errorcode])\n"
            puts [dict get $eopts -errorinfo]
        }
    }
}
