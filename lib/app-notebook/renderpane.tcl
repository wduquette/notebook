#-----------------------------------------------------------------------
# TITLE:
#	renderpane.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       A read-only text widget designed to render Notebook markup.
#	From the standpoint of the caller, the "render" method replaces
#	the "insert" and "delete" methods, which are effectively no-ops.
#
#	All necessary text widget commands are delegated down to the text
#	widget.  This widget knows how to render and tag Notebook markup,
#	but it doesn't provide any of the active behavior.
#
# LICENSE:
#       Copyright (C) 2005 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

snit::widgetadaptor renderpane {
    #-------------------------------------------------------------------
    # Text Widget Adaptation

    # Disable the insert and delete methods, to make this readonly.
    method insert {args} {}
    method delete {args} {}

    # Pass all otherwise undefined methods and options to the real 
    # text widget, so that the remaining behavior is as expected.
    delegate method * to hull
    delegate option * to hull

    #-------------------------------------------------------------------
    # Widget options

    # The command to use to query about a link's existence.  Must take
    # a page name as argument and return 1 if it exists, and 0 otherwise.
    option -querycommand {}

    # The command to call when a page title is clicked.  Should take the
    # title as its argument.
    option -titlecommand {}

    # The command to call when a page link is clicked.  Should take the
    # name of the page to link to as its argument.
    option -linkcommand {}

    # The command to call when a magic button is clicked.  The command 
    # should take one argument, the script to execute.
    option -buttoncommand {}

    # The command to call when a macroerror is clicked.  The command 
    # should take one argument, the text of the macro.
    option -macroerrorcommand {}

    # The command to call to write a message to the message line
    option -messagecommand {}

    # The notebook file directory; used as the root for relative paths.
    option -dbdir {}

    #-------------------------------------------------------------------
    # Instance Variables
    
    # The code associated with a magic button, where the index is
    # $button-$index.  $button is the displayed text for the button
    # and $index is the index of the first character of the displayed text.
    variable bcode

    # Counter used to generate names for horizontal line elements in
    # the text pane.
    variable counter 0

    # Escape character substitutions
    # TBD: Some of this should probably be done as part of markup parsing.
    variable escapeMapping \
        "&lt; < &gt; > &lb; \[ &rb; \] &amp; &"

    # Image List -- loaded images, for later destruction
    variable imageList {}

    # Image Data array: the index is the text widget index of the image,
    # and the value is the text to display.
    variable imageData

    #-----------------------------------------------------------------------
    # Constructor and Destructor

    constructor {args} {
        set options(-querycommand) [codename DefaultQueryCmd]
        
        # Next, create the rotext pane.
        installhull using text \
            -insertwidth 0 \
            -borderwidth 5 \
            -relief flat \
            -setgrid true \
            -wrap word \
            -cursor xterm

        # At present, all delegated options are delegated to the 
        # hull component, so now we can configure.
        $self configurelist $args

        # Next, create the bullet icons
        image create bitmap $win.bullet1 -data {
            #define button_width 8
            #define button_height 8
            static unsigned char button_bits[] = {
                0x00, 0x3c, 0x7e, 0x7e, 0x7e, 0x7e, 0x3c, 0x00};
        }

        image create bitmap $win.bullet2 -data {
            #define bullet2_width 8
            #define bullet2_height 8
            static unsigned char bullet2_bits[] = {
                0x00, 0x18, 0x3c, 0x7e, 0x7e, 0x3c, 0x18, 0x00};
        }

        image create bitmap $win.bullet3 -data {
            #define bullet3_width 8
            #define bullet3_height 8
            static unsigned char bullet3_bits[] = {
                0x00, 0x00, 0x00, 0x7e, 0x7e, 0x00, 0x00, 0x00};
        }

        # Next, add the markup tags, using the user preferences.
        $self UsePreferences

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

        # When over an active tag, the cursor should be a hand.
        foreach tag {title link button macroerror} {
            $hull tag bind $tag <Enter> \
                [mymethod EnterHandler $tag %x %y]
                
            $hull tag bind $tag <Leave> \
                [mymethod LeaveHandler $tag %x %y]
        }

        # While over images, display the -text and path.
        $hull tag bind image <Enter> [mymethod EnterImage %x %y]
        $hull tag bind image <Leave> [mymethod LeaveImage %x %y]

        # Prepare to receive preferences events; unregister on 
        # destroy.
        prefs register $selfns [mymethod UsePreferences]

        # Add better navigation keys
        bind $win <Key-Down>  [list $hull yview scroll  1 units]
        bind $win <Key-Up>    [list $hull yview scroll -1 units]
        bind $win <Key-Next>  [list $hull yview scroll  1 pages]
        bind $win <Key-Prior> [list $hull yview scroll -1 pages]
        bind $win <Key-Home>  [list $hull yview moveto 0]
        bind $win <Key-End>   [list $hull yview moveto 1]

        # Add mouse interactions
        $hull tag bind title <1> \
            [mymethod TitleHandler %x %y]

        $hull tag bind link <1> \
            [mymethod LinkHandler %x %y]

        $hull tag bind button <ButtonRelease-1> \
            [mymethod ButtonHandler %x %y]

        $hull tag bind macroerror <ButtonRelease-1> \
            [mymethod MacroErrorHandler %x %y]

    }

    destructor {
        catch {prefs unregister $selfns}
        catch {image delete $win.bullet1 $win.bullet2 $win.bullet3}
        catch {$self FreeImages}
    }

    #-----------------------------------------------------------------------
    # Public methods

    # Render a page into the page.  Uses ::markupparser::parseWithHandler
    # and ParseHandler to do the job.
    method render {title text} {
        variable sty

        # FIRST, delete all text from the text widget.
        $hull del 1.0 end

        # NEXT, forget all images
        $self FreeImages

        # NEXT, forget about any magic buttons; we'll build a new set.
        array unset bcode

        # NEXT, render the title
        $hull insert end " $title\n" title
        $hull insert end "\n"

        # NEXT, enable the default text style and indent
        set sty(para) ""
        set sty(txt) ""
        set indent 0

        # NEXT, render the page's text
        foreach {tag value} [::markupparser::parse $text] {
            switch -exact -- $tag {
                META { }
                HASH {
                    # FIRST, #--- is always displayed specially.
                    if {[string match "#---*" $value]} {
                        $self InsertHLine
                        continue
                    } 

                    # NEXT, if the prefs flag is set then all directives
                    # are displayed.
                    if {[prefs get displaydirectives]} {
                        $hull insert end $value pre
                        continue
                    }

                    # NEXT, display directives based on what they are.
                    if {[string match "#pre*" $value]} {
                        # Skip it.
                    } elseif {[string match "#unpre*" $value]} {
                        # Skip it.
                    } elseif {[string match "#meta*" $value]} {
                        # Skip it. 
                    } elseif {[string match "#rem*" $value]} {
                        # Skip it. 
                    } elseif {[string match "#data*" $value]} {
                        # Skip it
                    } elseif {[string match "#undata*" $value]} {
                        # Skip it
                    } elseif {[string match "#Tcl*" $value]} {
                        # Skip it
                    } elseif {[string match "#unTcl*" $value]} {
                        # Skip it
                    } else {
                        $hull insert end $value pre
                    }
                }
                PRE { 
                    $hull insert end $value pre
                }
                TCL { 
                    $hull insert end $value tcl
                }
                DATA {
                    array set fields $value
                    $hull insert end $fields(data) pre
                }
                H {
                    set lev [lindex $value 0]
                    set htext [lindex $value 1]

                    $hull insert end "$htext\n" header$lev
                }
                P {
                    set ptype  [lindex $value 0]
                    set indent [lindex $value 1]

                    # FIRST, basic paragraph setup.
                    set sty(bold) ""
                    set sty(italic) ""
                    set sty(mono) ""
                    set sty(strike) ""
                    set sty(small) ""
                    set sty(header) ""
                    set sty(para) ""
                    set sty(txt) ""
                    set sty(link) "link"
                    set sty(button) "button"

                    # NEXT, set up for bulleted and indented paragraphs

                    if {$ptype eq "*"} {
                        set sty(para) "indent$indent"
                        set sty(txt) $sty(para)
                        set sty(link) [concat $sty(txt) link]
                        set sty(button) [concat $sty(txt) button]
            
                        set lead [string repeat "\t" [expr {$indent - 1}]]
                
                        switch $indent {
                            1       {set image $win.bullet1}
                            2       {set image $win.bullet2}
                            default {set image $win.bullet3}
                        }
                    
                        $hull insert end "$lead" $sty(para)
                        $hull image create end -image $image -align center
                        $hull insert end "\t" $sty(para)
                    } elseif {$indent > 0} {
                        set sty(para) "indent$indent"
                        set sty(txt) $sty(para)
                        set sty(link) [concat $sty(txt) link]
                        set sty(button) [concat $sty(txt) button]
                    
                        $hull insert end [string repeat "\t" $indent] $sty(para)
                    }
                }
                STY { 
                    switch -exact -- [lindex $value 0] {
                        m1  {
                            set sty(mono) "mono"
                            set sty(header) ""
                            set sty(small) ""}
                        m0 {
                            set sty(mono) ""
                        }
                        b1  {
                            set sty(bold) "bold"
                            set sty(header) ""
                            set sty(small) ""
                        }
                        b0 {
                            set sty(bold) ""
                        }
                        i1  {
                            set sty(italic) "italic"
                            set sty(header) ""
                            set sty(small) ""
                        }
                        i0 {
                            set sty(italic) ""
                        }
                        h1  {
                            set sty(header) "header3"
                            set sty(bold) ""
                            set sty(italic) ""
                            set sty(mono) ""
                            set sty(small) ""
                        }
                        h0 {
                            set sty(header) ""
                        }
                        s1  {
                            set sty(small) "small"
                            set sty(bold) ""
                            set sty(italic) ""
                            set sty(mono) ""
                            set sty(header) ""
                        }
                        s0 {
                            set sty(small) ""
                        }
                        x1  {
                            set sty(strike) "strike"
                        }
                        x0 {
                            set sty(strike) ""
                        }
                        default {error "Unknown style: [lindex $value 1]"}
                    }

                    # Build the style list
                    if {$sty(header) ne ""} {
                        set theFont $sty(header)
                    }
                    
                    set sty(txt) "$sty(para) $sty(mono)$sty(bold)$sty(italic) $sty(strike) $sty(header) $sty(small)"
                    set sty(link) [concat $sty(txt) link]
                    set sty(button) [concat $sty(txt) button]
                }
                LINK {
                    #set value [NormalizeSpace $value]

                    if {![regexp {^([^|]+)\|(.*$)} $value dummy linktext name]} {
                        set linktext $value
                        set name $value
                    }
                    set linktext [NormalizeNewlines $linktext]
                    set name [NormalizeSpace $name]

                    # If it exists, show it normally; if not, show it differently.
                    if {[$self QueryLink $name]} {
                        set index [$hull index insert]
                        $hull insert end $linktext $sty(link)
                    } else {
                        $hull insert end "\[" [concat $sty(txt) warning]
                        set index [$hull index insert]
                        $hull insert end $linktext $sty(link)
                        $hull insert end "\]" [concat $sty(txt) warning]
                    }

                    # Save the page to link to in bcode.
                    set bcode([string tolower $linktext]-$index) $name
                }
                BTN {
                    if {[regexp {^([^|]+)\|(.*$)} $value dummy bname code]} {
                        set bname [NormalizeNewlines $bname]
                        set index [$hull index insert]
                        set bcode([string tolower $bname]-$index) $code
                        $hull insert end $bname $sty(button)
                    } else {
                        $hull insert end "\[%$value%\]" warningmono
                    }
                }
                OBJECT {
                    set obj [getobj $value]

                    switch -exact [lindex $obj 0] {
                        image {
                            $self InsertImage $obj
                        }
                        error {
                            $hull insert end "\[!$value!\]" warningmono
                            $self Msg [lindex $obj 1]
                        }
                        default {
                            $hull insert end "\[!$value!\]" warningmono
                            $self Msg "Unrecognized object type: $value"
                        }
                    }
                }
                MACRO {
                    # We should see this only if macro expansion failed for this
                    # macro
                    $hull insert end "\[@$value@\]" macroerror
                }
                TXT -
                HTML { 
                    # Normalize normal text: replace the whitespace between lines
                    # a single space.
                    regsub -all {\s*\n\s*} $value " " value
                    $hull insert end [string map $escapeMapping $value] $sty(txt)
                }
                BR {
                    $hull insert end "\n" $sty(txt)
                    $hull insert end [string repeat "\t" $indent] $sty(para)
                }
                /P -
                NL {
                    $hull insert end "\n" $sty(txt)
                }
                default {error "Unknown markup tag: $tag"}
            }
        }
    }

    # Tag text that matches the search text.
    method searchfor {searchText} {
        $hull tag remove search 1.0 end

        set pattern [string trim $searchText]

        if {$pattern eq ""} {
            return
        }

        set done 0
        set index 1.0
        set count 0
        while {1} {
            set index [$hull search -nocase -count count -- $pattern $index end]

            if {$index eq ""} {
                return
            }

            set endIndex [$hull index "$index + $count chars"]

            $hull tag add search $index $endIndex

            set index $endIndex
        }
    }


    #-----------------------------------------------------------------------
    # Private Methods and Procs

    # Given the name of a tag that's been clicked on, and the x,y pixel
    # coordinates of the click, return the tagged text.
    method GetTagText {tag x y} {
        set range [$hull tag prevrange $tag "@$x,$y +1 chars"]

        return [$hull get [lindex $range 0] [lindex $range 1]]
    }

    # Given the name of a tag that's been clicked on, and the x,y pixel
    # coordinates of the click, return the range {startIndex endIndex}.
    method GetTagRange {tag x y} {
        return [$hull tag prevrange $tag "@$x,$y +1 chars"]
    }

    # Returns 1 if a link exists and 0 otherwise.  Uses the -querycommand.
    method QueryLink {name} {
        set command $options(-querycommand)
        lappend command $name
        return [uplevel \#0 $command]
    }

    # Default query; always returns true.
    proc DefaultQueryCmd {args} {
        return 1
    }

    # Called when a special tag is entered
    method EnterHandler {tag x y} {
        $hull configure -cursor hand2

        if {$tag eq "link" || $tag eq "button"} {
            set range [$self GetTagRange $tag $x $y]
            set name  [$hull get [lindex $range 0] [lindex $range 1]]
            set index [lindex $range 0]

            set bcodeKey "[string tolower $name]-$index"
            
            # TBD: It would be better if there were a -hovercommand;
            # it could be passed the relevant info, and the caller
            # could decide how to use it.

            $self Msg $bcode($bcodeKey)
        }
    }

    # Called when a special tag is left
    method LeaveHandler {tag x y} {
        $hull configure -cursor xterm

        if {$tag eq "link" || $tag eq "button"} {
            $self Msg ""
        }
    }

    # Called when an image is entered
    method EnterImage {x y} {
        set ndx [$hull index @$x,$y]
        $self Msg $imageData($ndx)
    }

    # Called when an image is left
    method LeaveImage {x y} {
        $self Msg ""
    }

    # Called to write a message to the -messagecommand.
    method Msg {text} {
        if {$options(-messagecommand) eq ""} {
            return
        }

        set cmd $options(-messagecommand)
        lappend cmd $text
        uplevel \#0 $cmd
    }

    # Called when the title is clicked.
    method TitleHandler {x y} {
        set command $options(-titlecommand)

        if {$command eq ""} {
            return
        }

        # As formatted, the title includes leading and trailing
        # whitespace; delete it.
        lappend command [string trim [$self GetTagText title $x $y]]
        uplevel \#0 $command
    }

    # Called when a link is clicked.
    method LinkHandler {x y} {
        set command $options(-linkcommand)

        if {$command eq ""} {
            return
        }

        set range [$self GetTagRange link $x $y]
        set name  [$hull get [lindex $range 0] [lindex $range 1]]
        set index [lindex $range 0]

        lappend command $bcode([string tolower $name]-$index)
        uplevel \#0 $command
    }

    # Finds the button script and calls the button command
    method ButtonHandler {x y} {
        set command $options(-buttoncommand)

        if {$command eq ""} {
            return
        }

        set range [$self GetTagRange button $x $y]
        set name  [$hull get [lindex $range 0] [lindex $range 1]]
        set index [lindex $range 0]

        lappend command $bcode([string tolower $name]-$index)
        uplevel \#0 $command
    }

    # Finds the macroerror macro text and calls the macroerror command
    method MacroErrorHandler {x y} {
        set command $options(-macroerrorcommand)

        if {$command eq ""} {
            return
        }

        # The macro [@ @] brackets are included in the text; remove
        # them.
        set macro [string range [$self GetTagText macroerror $x $y] 2 end-2]

        lappend command $macro
        uplevel \#0 $command
    }

    # defines and updates style tags when preferences change.
    method UsePreferences {} {
        # TBD: Make this a preference setting.
        set tabWidth 0.2

        $win.bullet1 configure \
            -foreground [prefs get normalfg] \
            -background [prefs get normalbg] \

        $win.bullet2 configure \
            -foreground [prefs get normalfg] \
            -background [prefs get normalbg] \

        $win.bullet3 configure \
            -foreground [prefs get normalfg] \
            -background [prefs get normalbg] \

        $hull configure \
            -foreground [prefs get normalfg] \
            -background [prefs get normalbg] \
            -font [prefs get bodytext] \
            -tabs [list ${tabWidth}i [expr $tabWidth*2]i]

        $hull tag configure title \
            -font [prefs get titletext] \
            -foreground [prefs get titlefg] \
            -background [prefs get titlebg]

        $hull tag configure header1 \
            -font [prefs get header1text]

        $hull tag configure header2 \
            -font [prefs get header2text]

        $hull tag configure header3 \
            -font [prefs get header3text]

        $hull tag configure small \
            -font [prefs get smalltext]

        $hull tag configure bold \
            -font [concat [prefs get bodytext] bold]

        $hull tag configure italic \
            -font [concat [prefs get bodytext] italic]

        $hull tag configure bolditalic \
            -font [concat [prefs get bodytext] [list bold italic]]

        $hull tag configure mono \
            -font [prefs get monotext]

        $hull tag configure monobold \
            -font [concat [prefs get monotext] bold]

        $hull tag configure monoitalic \
            -font [concat [prefs get monotext] italic]

        $hull tag configure monobolditalic \
            -font [concat [prefs get monotext] [list bold italic]]

        $hull tag configure strike \
            -overstrike 1

        $hull tag configure link \
            -foreground [prefs get linkfg] \
            -background [prefs get linkbg]

        $hull tag configure warning \
            -foreground [prefs get warningfg] \
            -background [prefs get warningbg]

        $hull tag configure warningmono \
            -font [prefs get monotext] \
            -foreground [prefs get warningfg] \
            -background [prefs get warningbg]

        $hull tag configure button \
            -foreground [prefs get buttonfg] \
            -background [prefs get buttonbg]

        $hull tag configure macroerror \
            -font [prefs get monotext] \
            -foreground [prefs get warningfg] \
            -background [prefs get warningbg]

        $hull tag configure pre \
            -font [prefs get monotext] \
            -foreground [prefs get prefg] \
            -background [prefs get prebg]

        $hull tag configure tcl \
            -font [prefs get monotext] \
            -foreground [prefs get tclfg] \
            -background [prefs get tclbg]

        $hull tag configure search \
            -foreground [prefs get searchfg] \
            -background [prefs get searchbg]

        # Up to 9 levels of indent
        for {set i 1} {$i <= 9} {incr i} {
            $hull tag configure "indent$i" \
                -lmargin2 [expr $i*$tabWidth]i
        }

        # Give highest priority to the selection to make it visible when some
        # text with a non-default background is selected
        $hull tag raise sel
    }

    # Inserts a horizontal line into the pane by creating a frame widget.
    method InsertHLine {} {
        # First, create the frame as a child of the pane.
        incr counter
        set f $win.h$counter

        set width [expr {[winfo reqwidth $win] - 20}]

        frame $f -height 4 -width $width -background white \
            -borderwidth 2 -relief groove

        # Next, insert it into the pane.
        $hull window create end -window $f -align center -pady 3
        $hull insert end "\n" pre
    }

    # Removes leading and trailing whitespace, and reduces internal whitespace
    # sequences to one space.
    proc NormalizeSpace {text} {
        regsub -all {\n} $text " " text
        regsub -all {\s+} $text " " text
 
        return [string trim $text]
    }

    # Reduces internal whitespace sequences which contain a newline
    # to a single space.  Other whitespace is left alone.
    proc NormalizeNewlines {text} {
        regsub -all {\s*\n\s*} $text " " text
 
        return $text
    }

    # Parses an image request, and loads and inserts the image.
    method InsertImage {arglist} {
        set fileName [file join $options(-dbdir) [lindex $arglist 1]]

        array set opts [lindex $arglist 2]

        if {$opts(-text) ne ""} {
            set disptext "$opts(-text): $fileName"
        } else {
            set disptext $fileName
        }

        try {
            set images [LoadImage $fileName $opts(-width) $opts(-height)]
        } catch -msg msg {
            puts "Couldn't load '$fileName': $msg"
            set images [list ::Notebook::missing]
        }

        # NEXT, insert it into the text window.  If there's only one
        # image, just insert it normally; otherwise, insert the strips.
        # If there's a list, insert them in sequence.
        if {[llength $images] == 1} {
            set imageIndex [$hull index insert]
            set imageData($imageIndex) $disptext
            $hull image create end -image [lindex $images 0] \
                -padx $opts(-padwidth) 

            $hull tag add image $imageIndex
        } else {
            foreach img $images {
                if {[$hull compare insert > "insert linestart"]} {
                    $hull insert insert "\n"
                }
                set imageIndex [$hull index insert]
                set imageData($imageIndex) $disptext
                $hull image create end -image $img \
                    -padx $opts(-padwidth)
                $hull tag add image $imageIndex
            }
        }
    }

    # Destroys all loaded images
    method FreeImages {} {
        array unset imageData

        foreach img $imageList {
            image delete $img
        }
        set imageList {}
    }

    # Loads an image, subsampling down to the desired size.
    # Pass 0 width, 0 height for the default size.
    # If the image is "tall", it's broken into strips;
    # this helps everything scroll better.
    proc LoadImage {filename {width 0} {height 0}} {
        # FIRST, load the image
        set img [image create photo -file $filename]

        # NEXT, if the width and height are both 0, scale it..
        if {$width > 0 || $height > 0} {
            # FIRST, figure out how to scale it.
            set iwidth [image width $img]
            set iheight [image height $img]

            if {$width == 0} {
                set width $iwidth
            }

            if {$height == 0} {
                set height $iheight
            }
            
            set scale 1
            
            while {$iheight/$scale > $height ||
                   $iwidth/$scale > $width} {
                incr scale
            }

            # NEXT, scale the image, and delete the original.
            set iheight [expr {$iheight/$scale}]
            set iwidth [expr {$iwidth/$scale}]
            set dest [image create photo]
            $dest copy $img -subsample $scale

            image delete $img

            set img $dest
        }

        # NEXT, if the image is tall, cut it into horizontal strips, 
        # and return a list of the strips.  This allows the text
        # widget to scroll more nicely.
        set iheight [image height $img]
        set iwidth [image width $img]

        set stripHeight 25
        
        if {$iheight <= $stripHeight} {
            lappend imageList $img

            return [list $img]
        }

        set iy 0
        set results {}
        while {$iy < $iheight} {
            if {$iy + $stripHeight > $iheight} {
                set stripHeight [expr {$iheight - $iy}]
            }

            set strip [image create photo]
            $strip copy $img -from 0 $iy $iwidth [incr iy $stripHeight]
            lappend results $strip
            lappend imageList $strip
        }
        
        # NEXT, we no longer need the image from which we took the strips.
        image delete $img

        return $results
    }
}
