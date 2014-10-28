#-------------------------------------------------------------------------
# TITLE: 
#    main.tcl
#
# PROJECT:
#    notebook: Your project description
#
# DESCRIPTION:
#    app_notebook(n): main procedure
#
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# Exported Commands

namespace eval ::app_notebook {
    namespace export \
        main
}

#-------------------------------------------------------------------------
# Commands

# main argv
#
# Dummy procedure

proc ::app_notebook::main {argv} {
    namespace eval :: {
        source [file join $::app_notebook::library notebook.tcl]
    }
}
