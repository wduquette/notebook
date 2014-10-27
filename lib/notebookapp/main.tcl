#-------------------------------------------------------------------------
# TITLE: 
#    main.tcl
#
# PROJECT:
#    notebook: Your project description
#
# DESCRIPTION:
#    notebookapp(n): main procedure
#
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# Exported Commands

namespace eval ::notebookapp {
    namespace export \
        main
}

#-------------------------------------------------------------------------
# Commands

# main argv
#
# Dummy procedure

proc ::notebookapp::main {argv} {
    puts "[quillinfo project] [quillinfo version]"
    puts ""
    puts "Args: <$argv>"
}
