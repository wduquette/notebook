#-----------------------------------------------------------------------
# TITLE:
#	nb2mediawiki.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       MediaWiki markup exportation code for Notebook files.  This module
#	knows very little about the Notebook application as a whole;
#	such intelligence will be provided by hooks.
#
# LICENSE:
#       Copyright (C) 2005 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required Packages

package require markupparser

#-----------------------------------------------------------------------
# namespace declaration

namespace eval ::nb2mediawiki:: {
    variable wikiStyles

    # This table indicates the MediaWiki equivalents for each
    # Notebook style code.
    array set wikiStyles {
        m1     <tt>
        m0     </tt>
        i1     ''
        i0     ''
        b1     '''
        b0     '''
        h1     {=== }
        h0     { ===}
        s1     <small>
        s0     </small>
        x1     <strike>
        x0     </strike>
    }
}



#-----------------------------------------------------------------------
# Public functions


# wikitext markup args
#
# markup    Notebook markup to translate
# args      Option/value pairs, as follows:
#           
#           -embeddedhtml 0|1
#               If 1, it's assumed that TXT can contain embedded HTML.
#               Otherwise, &, <, and > are quoted.
#
#           -showhashes unknown|none|all
#               Indicates whether hash directives should be included
#               in the output.  If "unknown", only unknown directives
#               are included. If "none", no directives are included;
#               if "all", all directives are included.  Included
#               directives are rendered as preformatted text.

proc nb2mediawiki::wikitext {markup args} {
    variable wikiStyles

    # Allow the options to be passed as a single argument.
    if {[llength $args] == 1} {
        set args [lindex $args 0]
    }

    # Get default option values
    array set opts {
        -embeddedhtml 0
        -showhashes unknown
    }

    # Get the caller's values.
    # TBD: check errors better.
    array set opts $args

    # Set up for processing.
    set result ""
    set gotNL 1

    foreach {tag value} [::markupparser::parse $markup] {
        switch -exact $tag {
            META { }
            BR   {
                append result <br>
            }
            PRE {
                # PRE is used to mark blank lines in the input;
                # these should be handled separately.
                # TBD: See if this statement can be removed.
                if {[regexp {^\s*\n\s*$} $value]} {
                    append result "\n"
                    continue
                }
 
                # Otherwise, just display the preformatted text.
                append result "<pre>[AddEscapes $value]</pre>\n" 
            }
            TCL { 
                # Tcl code is always displayed as preformatted text...
                # for now.  It would be fun to do code coloring, etc.
                append result "<pre>[AddEscapes $value]</pre>\n" 
            }
            DATA {
                array set fields $value

                # data is shown as PRE.
                append result "<pre>[AddEscapes $fields(data)]</pre>\n"
            }
            HASH {
                if {[string match \#pre*    $value] ||
                    [string match \#unpre*  $value] ||
                    [string match \#Tcl*    $value] ||
                    [string match \#unTcl*  $value] ||
                    [string match \#data*   $value] ||
                    [string match \#undata* $value] ||
                    [string match \#meta*   $value] ||
                    [string match \#rem*    $value]
                } {
                    if {$opts(-showhashes) eq "all"} {
                        append result "<pre>[AddEscapes $value]</pre>\n"
                    }
                    continue
                }

                if {[string match \#---* $value]} {
                    append result "----\n"
                    continue
                }

                # Otherwise, it's an unknown hash; display as PRE.
                if {$opts(-showhashes) eq "unknown"} {
                    append result "<pre>[AddEscapes $value]</pre>\n"
                }
            }
            H {
                set lev [lindex $value 0]
                set htext [lindex $value 1]

                set tag [string repeat "=" $lev]
                append result "$tag $htext $tag\n"
            }
            /P {
                foreach letter [array names sty] {
                    if {$sty($letter)} {
                        append result $wikiStyles($letter$sty($letter))
                    }
                }
            }
            P {
                # FIRST, reset all text styles.
                array set sty {
                    m 0   i 0   b 0
                    h 0   s 0   x 0
                }

                # Next, get the paragraph style.
                set para   [lindex $value 0]
                set indent [lindex $value 1]

                if {$para eq ":" && !$gotNL} {
                    append result "<br>\n"
                } elseif {$para eq "*"} {
                    append result "\n[string repeat * $indent] "
                }

                set gotNL 0
            }
            TXT {
                if {!$opts(-embeddedhtml)} {
                    set value [AddEscapes $value]
                }
                
                set value [string map [list "\n" " " "&lb;" \[ "&rb;" \]] $value]

                append result $value
            }
            HTML {
                append result $value
            }
            NL {
                set gotNL 1
                append result "\n\n"
            }
            STY {
                set code [lindex $value 0]
                set letter [string index $code 0]
                set flag   [string index $code 1]
                
                set sty($letter) $flag
                append result $wikiStyles($code)
            }
            LINK {
                set value [::markupparser::normalizeSpace $value]

                # Note: with "|" notation, MediaWiki's format
                # puts the page name first and the displayed
                # text second, so we need to swap them.
                set list [split $value "|"]

                if {[llength $list] == 2} {
                    set value "[lindex $list 1]|[lindex $list 2]"
                }

                append result "\[\[$value\]\]"
            }
            BTN {
                # Extract just the button text.
                set value [lindex [split $value |] 0]

                append result $value
            }
            OBJECT {
                set obj [getobj $value]

                switch -exact [lindex $obj 0] {
                    image {
                        set fname [lindex $obj 1]
                        array set opts [lindex $obj 2]

                        append result "\[\[Image:$fname\]\]"
                    }
                    error -
                    default {
                        append result "<nowiki>\[!$value!\]</nowiki>"
                    }
                }
            }
            MACRO {
                # There shouldn't be any macros.
                append result "<nowiki>\[@$value@\]</nowiki>"
            }
        }
    }

    return $result
}


#-----------------------------------------------------------------------
# Utility Procs

# AddEscapes text
#
# text		plain text to be included in HTML output.
#
# Converts &, <, and > to &amp;, &lt;, and &gt;.

proc nb2mediawiki::AddEscapes {text} {
    regsub -all "&" $text {\&amp;} text
    regsub -all "<" $text {\&lt;}  text
    regsub -all ">" $text {\&gt;}  text

    return $text
}



