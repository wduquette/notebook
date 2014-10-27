#-----------------------------------------------------------------------
# TITLE:
#	markupparser.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Notebook application's markup language parser.
#
# 	Speed-up ideas:
#	- Search for next boundary using normal string search.
#	- Use a hidden text widget to search for each boundary using
#         regexps.
#
# LICENSE:
#       Copyright (C) 2005 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required Packages

package require textutil

#-----------------------------------------------------------------------
# Provided package

package provide markupparser 2.0

namespace eval ::markupparser:: {
    namespace export {[a-z]*}
}


#-----------------------------------------------------------------------
# Public Functions

# Parses text, generating a list directly
proc ::markupparser::parse {text} {
    set result {}

    # Q: Would scanning the string without modification be quicker?
    while {[string length $text] > 0} {
        # First, blank lines go as "NL".
        if {[regexp {^(\s*\n)(.*)$} $text dummy para text]} {
            lappend result NL $para
            continue
        }

        # NEXT, handle headers.  Header lines begin and end with
        # 1, 2, or 3 "=" signs, separated from the header text by
        # at least one space.  Headers are passed as H tags.
        if {[string index $text 0] eq "="} {
            # Header level 1
            if {[regexp {^= (\S[^\n]*\S*) =\n(.*)$} $text dum val text]} {
                lappend result H [list 1 $val]
                continue
            } 

            # Header level 2
            if {[regexp {^== (\S[^\n]*\S*) ==\n(.*)$} $text dum val text]} {
                lappend result H [list 2 $val]
                continue
            } 

            # Header level 3
            if {[regexp {^=== (\S[^\n]*\S*) ===\n(.*)$} $text dum val text]} {
                lappend result H [list 3 $val]
                continue
            } 
        }

        # NEXT, handle directives.  All directives are passed along
        # as HASH.  #pre and #Tcl are handled specially.
        if {[string index $text 0] eq "#"} {
            if {![regexp {^(\#[^\n]*\n)(.*)$} $text dummy para text]} {
                set para $text
                set text ""
            }
            lappend result HASH $para

            # If the directive is #pre, then we have preformatted text
            # until \n#unpre or the end of the text.
            if {[string match "#pre*" $para]} {
                # First, find the end.
                set ndx [string first "\n\#unpre" $text]

                if {$ndx == -1} {
                    lappend result PRE $text
                    set text ""
                } else {
                    lappend result PRE [string range $text 0 $ndx]
                    incr ndx
                    set text [string range $text $ndx end]
                }
                continue
            }
                
            # If the directive is #Tcl, then we have preformatted text
            # until \n#unTcl or the end of the text.
            if {[string match "#Tcl*" $para]} {
                # First, find the end.
                set ndx [string first "\n\#unTcl" $text]

                if {$ndx == -1} {
                    lappend result TCL $text
                    set text ""
                } else {
                    lappend result TCL [string range $text 0 $ndx]
                    incr ndx
                    set text [string range $text $ndx end]
                }
                continue
            }

            # If the directive is #data then we have to retrieve the
            # data name from the line, and then the text up to 
            # \n#undata or the end of the text.
            if {[string match "#data*" $para]} {
                # FIRST, prepare the fields
                array set fields {
                    type {}
                    name {}
                    options {}
                    data {}
                }
                # FIRST, get the data arguments, if any.
                set parms ""
                if {[regexp {^\#data\s+(.*)$} $para dummy parms]} {
                    if {[catch {lindex $parms 0} dummy]} {
                        set parms [split [normalizeSpace $parms] " "]
                    }

                    set fields(type) [lindex $parms 0]
                    set fields(name) [lindex $parms 1]
                    set fields(options) [lrange $parms 2 end]
                }

                # NEXT, find the end.
                set ndx [string first "\n\#undata" $text]

                if {$ndx == -1} {
                    set fields(data) $text
                    set text ""
                } else {
                    set fields(data) [string range $text 0 $ndx]
                    incr ndx
                    set text [string range $text $ndx end]
                }

                lappend result DATA [array get fields]
                continue
            }

            # If the directive is #meta then we have to retrieve the value.
            if {[regexp {^\#meta\s+(\S+)(\s+.*)?$} $para dummy name value]} {
                set meta($name) [string trim $value]
                continue
            }

            continue
        }

        # At this point, we know the following things:
        # The next line is not blank, with or without extra whitespace.
        # The next line doesn't begin with a #.
        #
        # Given that, find the end of the paragraph.
        
        set eop [FindEndOfPara $text]

        if {$eop == -1} {
            set para $text
            set text ""
        } else {
            set para [string range $text 0 $eop]
            set text [string range $text [expr {$eop + 1}] end]
        }

        # Next, if it begins with whitespace it's preformatted.
        set firstChar [string index $para 0]

        if {" " == $firstChar || "\t" == $firstChar} {
            lappend result PRE $para
            continue
        }

        # NEXT, if it begins with "*" or ":" it's bulleted or indented;
        # if it begins with "-" it's normal but the "-" + leading is
        # not displayed.  Otherwise it's just normal.
        
        if {"*" == $firstChar} {
            regexp {^(\*+)(\s*)(.*$)} $para dummy stars leading para
            lappend result P [list * [string length $stars] $leading]
        } elseif {":" == $firstChar} {
            regexp {^(:+)(\s*)(.*$)} $para dummy colons leading para
            lappend result P [list : [string length $colons] $leading]
        } elseif {"-" == $firstChar} {
            regexp {^-(\s*)(.*$)} $para dummy leading para
            lappend result P [list : 0 "-$leading"]
        } else {
            lappend result P [list : 0 ""]
        }

        # NEXT, keep track of the text style flags.  All are off
        # at the beginning of each paragraph.
        foreach letter [list b i m h s x] {
            set styflag($letter) 0
        }

        # Next, parse out the elements of the paragraph:
        while {[string length $para] > 0} {

            # FIRST, handle wiki-like style markup.
            if {[string index $para 0] == "'"} {
                # Toggle Bold face
                if {[regexp {^(''')(.*$)} $para dummy tag para]} {
                    set styflag(b) [expr {!$styflag(b)}]
                    lappend result STY [list b$styflag(b) $tag]
                    continue
                }
              
                # Toggle Italics
                if {[regexp {^('')(.*$)} $para dummy tag para]} {
                    set styflag(i) [expr {!$styflag(i)}]
                    lappend result STY [list i$styflag(i) $tag]
                    continue
                }
            }

            # NEXT, handle HTML-like style markup.
            if {[string index $para 0] == "<"} {
                if {[regexp {^(</?([bimhsx])>)(.*$)} \
                         $para dummy tag letter para]} {

                    if {[string index $tag 1] eq "/"} {
                        set flag 0
                    } else {
                        set flag 1
                    }
                    set styflag($letter) $flag
                    lappend result STY [list $letter$flag $tag]
                    continue
                }

                if {[regexp {^(<br>\s*)(.*$)} $para dummy tag para]} {
                    lappend result BR $tag
                    continue
                }

                if {[regexp {^<html>(.*$)} $para dummy para]} {
                    # find the end.
                    set ndx [string first "</html>" $para]

                    if {$ndx == -1} {
                        lappend result HTML $para
                        set para ""
                    } else {
                        incr ndx -1
                        lappend result HTML [string range $para 0 $ndx]
                        incr ndx 8; # Skip the </html>
                        set para [string range $para $ndx end]
                    }
                    continue
                }
            } 


            # NEXT, handle buttons, leftover macros, objects, and links.
            if {[string index $para 0] == "\["} {
                if {[string index $para 1] == "%"} {
                    # Magic Button
                    set ndx [string first "%\]" $para 2]
                    if {$ndx != -1} {
                        set button [string range $para 2 [expr $ndx -1]]
                        set para [string range $para [expr $ndx + 2] end]
                        lappend result BTN $button
                        continue
                    }
                } elseif {[string index $para 1] == "@"} {
                    # Left-over embedded macro
                    set ndx [string first "@\]" $para 2]
                    if {$ndx != -1} {
                        set macro [string range $para 2 [expr $ndx -1]]
                        set para [string range $para [expr $ndx + 2] end]
                        lappend result MACRO $macro
                        continue
                    }
                } elseif {[string index $para 1] == "!"} {
                    # Object
                    set ndx [string first "!\]" $para 2]
                    if {$ndx != -1} {
                        set object [string range $para 2 [expr $ndx -1]]
                        set para [string range $para [expr $ndx + 2] end]
                        lappend result OBJECT $object
                        continue
                    }
                } else {
                    # Link
                    set ndx [string first "\]" $para 1]
                    if {$ndx != -1} {
                        set link [string range $para 1 [expr $ndx -1]]
                        set para [string range $para [expr $ndx + 1] end]
                        lappend result LINK $link
                        continue
                    }
                }
            }
            
            if {![regexp {^(.[^'<\[]*)(['<\[].*)$} $para dummy elem para]} {
                set elem $para
                set para ""
            }
            
            lappend result TXT $elem
        }

        lappend result /P ""
    }

    
    return [linsert $result 0 META [array get meta]]
}


# parseWithHandler text handler
#
# text:     The text to parser
# handler:  A command to handle parsed elements.
#
# Parses the input text into tagged values.  The tagname indicates 
# what sort of value it is.  Each tag and value are lappended to the
# command, which is then called in the global context.
#
# debugHandler is a sample handler command; it simply prints each tag
# and its value to stdout for debugging.

proc ::markupparser::parseWithHandler {text handler} {
    foreach {tag value} [parse $text] {
        uplevel \#0 $handler [list $tag $value]
    }
}

# At this point, we know the following things:
# The next line is not blank, with or without extra whitespace.
# The next line doesn't begin with a #.
# The end of the paragraph occurs at one of the following boundaries:
#
# - A line that begins with "*"
# - A line that begins with ":"
# - A line that begins with "#"
# - A line that looks like "[ \t]*\n"
# - The end of the text.
#
# Returns the index of the end of the current paragraph, or -1 if there
# is no subsequent paragraph.
proc ::markupparser::FindEndOfPara {text} {
    if {![regexp -indices {(\n[ \t]*\n)|(\n\*)|(\n\#)|(\n:)|(\n-)} $text match]} {
        return -1
    }

    return [lindex $match 0]
}

# debugHandler tag value
#
# tag:     A parsed markup tag
# value:   A parsed markup value
#
# A simple tag handler; it just outputs its input to stdout for debugging.

proc ::markupparser::debugHandler {tag value} {
    puts "$tag: <$value>"
}

# Removes leading and trailing whitespace, and reduces internal whitespace
# sequences to one space.
proc ::markupparser::normalizeSpace {text} {
    regsub -all {\n} $text " " text
    regsub -all {\s+} $text " " text

    return [string trim $text]
}

# renameLink text oldName newName
#
# Edits text, renaming all links to oldName so that the link to newName
# instead.

proc ::markupparser::renameLink {text oldName newName} {
    variable renameResult
    variable renameOld
    variable renameNew

    # FIRST, normalize both names.
    set renameOld [string tolower [normalizeSpace $oldName]]
    set renameNew [normalizeSpace $newName]

    # Next, do the edit.
    set renameResult ""
    foreach {tag value} [parse $text] {
        switch -exact $tag {
            META    {}
            HASH    -
            PRE     -
            TCL     -
            TXT     -
            BR      -
            NL   {
                append renameResult $value
            }
            DATA {
                array set fields $value
                append renameResult $fields(data)
            }
            STY {
                append renameResult [lindex $value 1]
            }
            HTML {
                append renameResult "<html>$value</html>"
            }
            H {
                set lev [lindex $value 0]
                set htext [lindex $value 1]

                set tag [string repeat "=" $lev]
                append renameResult "$tag $htext $tag\n"
            }
            P {
                set ptype [lindex $value 0]
                set indent [lindex $value 1]
                set leading [lindex $value 2]

                append renameResult [string repeat $ptype $indent]
                append renameResult $leading
            }
            LINK {
                if {[regexp {^([^|]+)\|(.*$)} $value dummy linktext name]} {
                    set page [string tolower [normalizeSpace $name]]

                    if {$page eq $renameOld} {
                        set value "$linktext|$renameNew"
                    }
                } else {
                    set page [string tolower [normalizeSpace $value]]
                    if {$page eq $renameOld} {
                        set value $renameNew
                    }
                }

                append renameResult "\[$value\]"
            }
            BTN {
                append renameResult "\[%$value%\]"
            }
            MACRO {
                append renameResult "\[@$value@]"
            }
            OBJECT {
                append renameResult "\[!$value!]"
            }
        }
    }
    return $renameResult
}

# formatplain text options
#
# Formats the markup into plain text.
# Styles are ignored, except for <h>...</h>; header text is put in ALL
# CAPS.  Links are displayed without brackets; magic buttons are displayed
# by their labels.
#
# Options: 
#
# -pretty flag    If true, macros and errant magic buttons 
#                 are left out.  Defaults to 0
# -length cols    Line length; defaults to 74.

proc ::markupparser::formatplain {text args} {
    set option(-pretty) 0
    set option(-length) 74

    foreach {opt value} $args {
        if {[info exists option($opt)]} {
            set option($opt) $value
        } else {
            error "Unknown option $opt"
        }
    }

    set output ""
    set bullet 0
    set indent 0
    set header 0

    foreach {tag value} [parse $text] {
        switch $tag {
            META {}
            HASH {
                if {[string match "#---*" $value]} {
                    append output [string repeat "-" $option(-length)]
                    append output "\n"
                }
            }
            TCL  -
            PRE  {
                append output $value
            }
            DATA {
                array set fields $value
                append output $fields(data)
            }
            P {
                set header 0
                set para ""
                set bullet [expr {[lindex $value 0] eq "*"}]
                set indent [lindex $value 1]
            }
            /P {
                append output \
                    [WrapParagraph $para $option(-length) $indent $bullet]
                append output "\n"
            }
            NL {
                append output "\n"
            }
            TXT -
            HTML {
                if {$header} {
                    set value [string toupper $value]
                }
                append para $value
            }
            BR {
                append output \
                    [WrapParagraph $para $option(-length) $indent $bullet]
                append output "\n"
                set para ""
                set bullet 0
            }
            H {
                set lev [lindex $value 0]
                set htext [lindex $value 1]

                if {$lev == 1} {
                    set htext [string toupper $htext]
                }
                append output "$htext\n"
            }
            LINK {
                if {![regexp {^([^|]+)\|(.*$)} $value dummy linktext name]} {
                    set linktext $value
                }

                if {$header} {
                    set linktext [string toupper $linktext]
                }
                append para [normalizeSpace $linktext]
            }
            BTN {
                if {[regexp {^([^|]+)\|(.*$)} $value dummy bname bcode]} {
                    if {$header} {
                        set bname [string toupper $bname]
                    }
                    append para [normalizeSpace $bname]
                } elseif {!$option(-pretty)} {
                    append para "\[%$value%\]" 
                }
            }
            MACRO {
                if {!$option(-pretty)} {
                    append para "\[@$value@]"
                }
            }
            OBJECT {
                if {!$option(-pretty)} {
                    append para "\[!$value!]"
                }
            }
            STY {
                # Handle header; other styles are ignored.
                switch -exact [lindex $value 0] {
                    h1 { set header 1}
                    h0 { set header 0}
                }
            }
            default {error "Unknown markup tag: $tag"}
        }
    }

    return $output
}

# Wraps the paragraph given the inputs.
#
# text      Paragraph to wrap
# length    Max line length
# indent    How many tab stops it should be indented.
# bullet    Whether it's a bulleted paragraph or not.

proc ::markupparser::WrapParagraph {text length indent bullet} {
    # Wrap it as though it's not indented, but leave space for the indent.
    set wrapcol [expr {$length - 4*$indent}]

    set wrappedText [::textutil::adjust $text -length $wrapcol]

    if {$indent} {
        set lines [split $wrappedText "\n"]

        set lead [string repeat "    " $indent]

        if {$bullet} {
            set first "[string repeat {    } [expr {$indent - 1}]]  * "
        } else {
            set first $lead
        }

        set body [join $lines "\n$lead"]

        set wrappedText $first
        append wrappedText $body
    }

    return $wrappedText
}

