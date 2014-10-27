#-----------------------------------------------------------------------
# TITLE:
#	rotext.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       A read-only text widget.  A rotext behaves in all ways identical
# 	to a normal text widget, except that text cannot be inserted or
#	deleted by the user.
#
#	The widget was made read-only by overriding the "insert" and 
#	"delete" widget subcommands.  They have been replaced by
#	"ins" and "del" which do the same thing, but which aren't 
#	available to the standard mouse and keyboard bindings.
#
#	This sneaky trick is due to Donal K. Fellows at the 
#	Tcler's Wiki; the widget is implemented using snit.
#
# LICENSE:
#       Copyright (C) 2003 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Public methods

snit::widgetadaptor ::gui::rotext {
    constructor {args} {
        # First, create the real text widget.
        installhull [text $self -insertwidth 0]
        $self configurelist $args

        # Next, copy the default Text bindings to the renderpane,
        # and adjust the bindtags so that the Text bindings no longer
        # matter.  This will allow us to override them.

        foreach sym [bind Text] {
            bind $win $sym [bind Text $sym]
        }

        set bt [bindtags $win]
        set ndx [lsearch -exact $bt Text]
        bindtags $win [lreplace $bt $ndx $ndx]

        # Next, remove the <<Cut>> and <<Paste>> tags, etc., since renderpanes
        # aren't editable.
        bind $win <<Cut>> ""
        bind $win <<Paste>> ""
        bind $win <<Undo>> ""
        bind $win <<Redo>> ""
    }

    # Disable the insert and delete methods, to make this readonly.
    method insert {args} {}
    method delete {args} {}

    # Enable ins and del as synonyms, so the program can insert and
    # delete.
    delegate method ins to hull as insert
    delegate method del to hull as delete
    
    # Pass all other methods and options to the real text widget, so
    # that the remaining behavior is as expected.
    delegate method * to hull
    delegate option * to hull
}



