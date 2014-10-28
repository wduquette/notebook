#-----------------------------------------------------------------------
# TITLE:
#	nbobjects.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       This module contains the parser for Notebook "objects", e.g.,
#       things found in [!...!] markup.
#
#       At some point, this might allow some kind of plug-in 
#       architecture.
#
#-----------------------------------------------------------------------

# getobj objstring
#
# Parses objstring and returns a list.  The first element is the valid
# object type, or "error".  The subsequent elements depend on the
# object type.

proc getobj {objstring} {
    # FIRST, it must be a valid list.
    if {[catch {lindex $objstring 0} objectType]} {
        return [list error "Invalid object: $objstring"]
    }

    # NEXT, we only have one kind of object at the moment.
    if {$objectType != "image"} {
        return [list error "Unrecognized object type: $objstring"]
    }

    return [ParseImageObject $objstring]
}

# ParseImageObject obj
#
# The first token of obj is "image".  The second is the path to the
# image file.  The remaining elements are options and values.
#
# Returns a list {image path optlist}.  The list contains all
# options allowed for images, with values.

proc ParseImageObject {obj} {
    set result [lrange $obj 0 1]

    array set opts {
        -width 0
        -height 0
        -padwidth 0
        -text ""
    }
    
    foreach {opt val} [lrange $obj 2 end] {
        if {[info exists opts($opt)]} {
            if {$opt eq "-text" ||
                [regexp {^[0-9]+[cimp]?$} $val]} {
                set opts($opt) $val
                continue
            }
        }

        return [list error "Invalid image option: $opt $val"]
    } 

    lappend result [array get opts]
    
    return $result
}
