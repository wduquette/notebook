#-----------------------------------------------------------------------
# TITLE:
#	nb2html.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       HTML exportation code for Notebook files.  This module
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
# HTML Type
#
# Creates objects which can translate Notebook markup into HTML.

namespace eval ::nb2html:: {}

snit::type ::nb2html::html {
    #-------------------------------------------------------------------
    # Tables

    # This table indicates the HTML tag(s) for each Notebook
    # style code.
    typevariable htmlStyles -array {
        m1     <tt>
        m0     </tt>
        i1     <i>
        i0     </i>
        b1     <b>
        b0     </b>
        h1     {<font face="serif" size="+2"><b>}
        h0     </b></font>
        s1     {<font face="sans-serif" size="-2">}
        s0     </font>
        x1     <s>
        x0     </s>
    }

    #-------------------------------------------------------------------
    # Options
    #
    # These options control how Notebook markup is translated into HTML.

    # CSS styles for inclusion in pages or a .css file.  By default,
    # no styles.
    option -css {}

    # Indicates whether hash directives should be included
    # in the output.  If "unknown", only unknown directives
    # are included. If "none", no directives are included;
    # if "all", all directives are included.  Included
    # directives are rendered as preformatted text.
    option -showhashes unknown  ;# unknown | none | all

    # If "" (the default), link text will be displayed
    # verbatim.  Otherwise, the link text will be lappended
    # to the cmdprefix, which will be evaluated.  The
    # return value will be included in the output verbatim.
    option -linkcmd {}

    # If "", the filename will be used as the Notebook title
    # when exporting an entire notebook.
    option -nbtitle {}
    
    #-------------------------------------------------------------------
    # Constructor

    # So far, we don't need one.

    #-------------------------------------------------------------------
    # Public Methods


    # htmlpage pagename htmltext args
    #
    # pagename      The page's name
    # text          HTML text to wrap
    # args          Options/values (NIY)
    #
    # Wraps HTML body text in a simple boilerplate HTML page.
    method htmlpage {pagename text args} {
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        set out "<html><head><title>$pagename</title>"
        
        if {$options(-css) ne ""} {
            append out "\n<style>$options(-css)</style>\n"
        }

        append out "</head>\n<body>\n\n"
        append out "<h1>$pagename</h1>\n\n"
        append out $text
        append out "\n</body>\n</html>"
        
        return $out
    }

    # htmltext markup
    #
    # markup    Notebook markup to translate

    method htmltext {markup} {
        # Set up for processing.
        set result ""
        set this(indent) 0
        set this(para) :
        set this(inpara) 0
        set last(indent) 0
        set last(para) :

        foreach {tag value} [::markupparser::parse $markup] {
            switch -exact $tag {
                META { }
                BR   { 
                    append result </br>
                }
                PRE {
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

                    # "html" data is passed through unchanged; other data is
                    # shown as PRE.
                    if {$fields(type) eq "html"} {
                        append result $fields(data)
                    } else {
                        append result "<pre>[AddEscapes $fields(data)]</pre>\n"
                    }
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
                        if {$options(-showhashes) eq "all"} {
                            append result "<pre>[AddEscapes $value]</pre>\n"
                        }
                        continue
                    }

                    if {[string match \#---* $value]} {
                        # If last indent was > 0, close the indentation.
                        set this(indent) 0
                        for {set i 0} {$i < $last(indent)} {incr i} {
                            append result "</ul>\n\n"
                        }
                        array set last [array get this]

                        if {$options(-showhashes) eq "all"} {
                            append result "<pre>[AddEscapes $value]</pre>\n"
                        }
                        append result "<hr>\n"
                        continue
                    }

                    # Otherwise, it's an unknown hash; display as PRE.
                    if {$options(-showhashes) eq "unknown"} {
                        append result "<pre>[AddEscapes $value]</pre>\n"
                    }
                }
                H {
                    # Next, if we're indented, close the indentation.
                    set this(indent) 0
                    for {set i 0} {$i < $last(indent)} {incr i} {
                        append result "</ul>\n\n"
                    }
                    array set last [array get this]

                    set lev [lindex $value 0]
                    set htext [lindex $value 1]

                    # Increment level: we want <h2>, <h3> and <h4>
                    # tags.
                    incr lev

                    append result "<h$lev>[AddEscapes $htext]</h$lev>\n"
                }
                /P {
                    set this(inpara) 0
                    foreach letter [array names sty] {
                        if {$sty($letter)} {
                            append result $htmlStyles(${letter}0)
                        }
                    }
                    array set last [array get this]
                    
                    if {$this(indent) == 0} {
                        # Then this is the end of a normal paragraph, which
                        # needs to be closed.
                        append result "</p>"
                    }
                }
                P {
                    set this(inpara) 1

                    # FIRST, reset all text styles.
                    array set sty {
                        m 0   i 0   b 0
                        h 0   s 0   x 0
                    }

                    # Next, get the paragraph style.
                    set this(para)   [lindex $value 0]
                    set this(indent) [lindex $value 1]

                    # Next, if we're indented less than before, close
                    # the indentation.
                    for {set i $this(indent)} {$i < $last(indent)} {incr i} {
                        append result "</ul>\n\n"
                    }

                    # Next, if we're indented more than before, open
                    # the indentation.
                    for {set i $last(indent)} {$i < $this(indent)} {incr i} {
                        append result "\n<ul>\n"
                    }

                    # Next, if the indentation is 0, start a new 
                    # paragraph; otherwise start a list item.
                    if {$this(indent) == 0} {
                        append result "<p>"
                    } elseif {$this(para) eq "*"} {
                        append result "<li> "
                    } elseif {$last(para) eq "*" &&
                              $this(para) eq ":"} {
                        append result "</li>\n"
                    }
                }
                TXT {
                    # Handle Notebook markup pseudo-escapes.
                    set value [string map [list "&lb;" \[ "&rb;" \]] $value]

                    append result $value
                }
                HTML {
                    append result $value
                }
                NL {
                    append result "\n"
                }
                STY {
                    set code [lindex $value 0]
                    set letter [string index $code 0]
                    set flag   [string index $code 1]
                    
                    set sty($letter) $flag
                    append result $htmlStyles($code)
                }
                LINK {
                    set value [::markupparser::normalizeSpace $value]

                    if {![regexp {^([^|]+)\|(.*$)} $value dummy linktext name]} {
                        set linktext $value
                        set name $value
                    }

                    if {$options(-linkcmd) eq ""} {
                        append result [AddEscapes $linktext]
                        continue
                    }

                    set cmd $options(-linkcmd)
                    lappend cmd $linktext $name

                    append result [uplevel \#0 $cmd]
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

                            append result "<img src=\"$fname\""

                            if {$opts(-text) != ""} {
                                append result " alt=\"$opts(-text)\""
                            }
                            if {$opts(-width) ne "0"} {
                                append result " width=\"$opts(-width)\""
                            }
                            if {$opts(-height) ne "0"} {
                                append result " height=\"$opts(-height)\""
                            }
                            append result ">"
                        }
                        error -
                        default {
                            append result [ErrText "<pre>\[!$value!\]</pre>"]
                        }
                    }
                }
                MACRO {
                    # There shouldn't be any macros.  Format the macro
                    # in red.
                    append result [ErrText "\[@$value@\]"]
                }
            }
        }

        # If last indent was > 0, close the indentation.
        for {set i 0} {$i < $last(indent)} {incr i} {
            append result "</ul>\n\n"
        }

        if {$this(inpara)} {
            foreach letter [array names sty] {
                if {$sty($letter)} {
                    append result $htmlStyles(${letter}0)
                }
            }
            
            if {$this(indent) == 0} {
                # Then this is the end of a normal paragraph, which
                # needs to be closed.
                append result "</p>"
            }
        }

        return $result
    }

    #-------------------------------------------------------------------
    # Utility Procs

    # ErrText text
    #
    # Wraps the text in a red font.
    
    proc ErrText {text} {
        return "<font color=\"\#ff0000\">$text</font>"
    }

    # AddEscapes text
    #
    # text		plain text to be included in HTML output.
    #
    # Converts &, <, and > to &amp;, &lt;, and &gt;.

    proc AddEscapes {text} {
        regsub -all "&" $text {\&amp;} text
        regsub -all "<" $text {\&lt;}  text
        regsub -all ">" $text {\&gt;}  text
        
        return $text
    }
}




