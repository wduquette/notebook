#-----------------------------------------------------------------------
# TITLE:
#	prefs_dialog.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Notebook.tcl's Preferences dialog.  This is a modeless dialog.
#
# LICENSE:
#       Copyright (C) 2005 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required packages

package require BWidget
package require combobox

#-----------------------------------------------------------------------
# Public Commands

# prefsdialog
#
# Creates a Preferences Window.

snit::widget ::Notebook::prefsdialog {
    hulltype toplevel
    delegate method * to hull
    delegate option * to hull

    # Main components
    component am     ;# The action manager
    component status ;# The statusentry
    component bbar   ;# The button bar
    component wf     ;# The main frame

    # other components
    variable fonts
    variable colors
    variable editor
    variable misc
    variable tcltk
    variable scaling

    # Constructor and destructor

    constructor {args} {
        #---------------------------------------------------------------
        # Preliminaries

        # FIRST, withdraw the window; we'll bring it back when the
        # want to see it.
        wm withdraw $win

        # NEXT, set the window title
        wm title $win "Notebook: Preferences"

        # NEXT, Go ahead and configure the widget options, if any; none are
        # delegated to anything but the hull.
        $self configurelist $args

        # NEXT, prepare for window closing
        wm protocol $win WM_DELETE_WINDOW [list wm withdraw $win]

        # NEXT, this window shouldn't be resizeable.
        wm resizable $win 0 0
        
        #---------------------------------------------------------------
        # Create Components

        # If this is Tcl/Tk Aqua, then we need to define the menu
        # for this window.  That means we need an action manager and
        # a statusentry.

        if {[tk windowingsystem] eq "aqua"} {
            # FIRST, create the actionmanager and define the actions.
            install am using nbactionmanager %AUTO% \
                -toplevel $win \
                -windowtype $type \
                -errorcommand [mymethod ErrorHandler]

            # NEXT, create the statusentry.  It provides a GUI for displaying
            # status and entering arguments.
            install status using statusentry $win.status \
                -errorcommand [mymethod logerror] \
                -messagecommand [mymethod logmessage]
            pack $status -side bottom -fill x -expand 0
        }

        # Create a button bar and the main frame.
        install bbar using frame $win.bbar
        pack $bbar -side bottom -fill x -expand 0 -pady 4

        install wf using frame $win.wf
        pack $wf -side top -fill both -expand 1

        # Next, add the buttons to the button bar
        $self AddButton apply "Apply"
        $self AddButton reset "Reset"
        $self AddButton help  "Help"

        # Next, add the tabbed notebook. 
        if {[tk windowingsystem] eq "aqua"} {
            NoteBook $wf.notebook \
                -borderwidth 2 \
                -activeforeground blue \
                -activebackground white
        } else {
            NoteBook $wf.notebook
        }

        # Next, create the tabs
        set fonts \
            [FontsTab [$wf.notebook insert end fonts -text Fonts].tab]
        pack $fonts -fill both -expand 1

        set colors \
            [ColorsTab [$wf.notebook insert end colors -text Colors].tab]
        pack $colors -fill both -expand 1

        set editor \
            [EditorTab [$wf.notebook insert end editor -text Editor].tab]
        pack $editor -fill both -expand 1

        set misc \
            [MiscTab [$wf.notebook insert end misc -text Misc].tab]
        pack $misc -fill both -expand 1

        set tcltk \
            [TclTkTab [$wf.notebook insert end tcltk -text "Tcl/Tk"].tab]
        pack $tcltk -fill both -expand 1

        set scaling \
            [ScalingTab [$wf.notebook insert end scaling -text "Scaling"].tab]
        pack $scaling -fill both -expand 1

        # Pack the notebook into the dialog, and make the fonts tab visible.
        pack $wf.notebook -side top -fill both -expand true
        $wf.notebook raise fonts
        $wf.notebook compute_size

        if {$am ne ""} {
            # NEXT, update the action state now that everything's created.
            $am updatestate
        }
    }

    # Adds a button to the button bar.
    method AddButton {id text} {
        set b [button $bbar.$id -text $text -command [mymethod $id]]
        pack $b -side left
    }

    # Handles errors from the statusentry and actionmanager components.
    method ErrorHandler {msg einfo ecode} {
        if {$ecode eq "USER"} {
            $status msg $msg
            bell
        } else {
            messagelog logerror $msg $einfo $ecode

            $status msg "$msg -- go to Message Log for more."
        }
    }

    # Apply the changes, and save them.
    method apply {} {
        $fonts   apply
        $colors  apply
        $editor  apply
        $misc    apply
        $tcltk   apply
        $scaling apply
        prefs save
    }

    # Reload the current preferences.
    method reset {} {
        $fonts   reset
        $colors  reset
        $editor  reset
        $misc    reset
        $tcltk   reset
        $scaling reset
    }

    method help {} {
        showhelp "User Preferences"
    }

    method show {} {
        wm deiconify $win
        raise $win
    }

    #-------------------------------------------------------------------
    # Status entry logging
    # Log an error.
    method logerror {msg einfo ecode} {
        $log ins 1.0 "\n$einfo\n\n" errortext
        $log see 1.0
        $log mark set insert 1.0
        
        $self Truncate
        bell
    }

    # Log a normal message
    method logmessage {msg} {
        if {$msg ne ""} {
            $log ins 1.0 "$msg\n"
            $log see 1.0
            $log mark set insert 1.0

            $self Truncate
        }
    }

    #-------------------------------------------------------------------
    # Non-Delegated Action Handlers

    # Action: close-window
    method close-window {} {
        wm withdraw $win
    }

    #-------------------------------------------------------------------
    # Delegated Action Handlers

    delegate method about-notebook         to am
    delegate method copy-string            to am
    delegate method cut-string             to am
    delegate method edit-preferences       to am
    delegate method help-on                to am
    delegate method help-introduction      to am
    delegate method help-index             to am
    delegate method help-on-actions        to am
    delegate method help-on-commands       to am
    delegate method help-on-markup         to am
    delegate method new-notebook           to am
    delegate method notebook-license       to am
    delegate method notebook-release-notes to am
    delegate method open-notebook          to am
    delegate method paste-string           to am
    delegate method redo-change            to am
    delegate method request-action         to am
    delegate method undo-change            to am
    delegate method show-version           to am
}

#-----------------------------------------------------------------------
# FontsTab

snit::widget ::Notebook::prefsdialog::FontsTab {
    delegate method * to hull
    delegate option * to hull

    # Font kinds -- initialized by FontSelector.
    variable kinds {}

    # Array mirroring widget values
    variable styles

    constructor {args} {
        # Create the font selectors
        $self FontSelector 0 "Title Text:"   title   [prefs fonts]
        $self FontSelector 1 "Header1 Text:" header1 [prefs fonts]
        $self FontSelector 2 "Header2 Text:" header2 [prefs fonts]
        $self FontSelector 3 "Header3 Text:" header3 [prefs fonts]
        $self FontSelector 4 "Body Text:"    body    [prefs fonts]
        $self FontSelector 5 "Mono Text:"    mono    [prefs monofonts]
        $self FontSelector 6 "Small Text:"   small   [prefs fonts]

        # Get the current user prefs.
        $self reset
    }

    # FontSelector row lab kind fonts
    #
    # row:      The row in the grid
    # lab:      The text label for the row
    # kind:     title body mono header small
    # fonts:    Valid fonts for this kind

    method FontSelector {row lab kind fonts} {
        lappend kinds $kind

        set sizes {8 9 10 11 12 14 16 18 20 24 28 32}

        set ffont $win.${kind}font
        set fsize $win.${kind}size
        set fbold $win.${kind}bold
        set fital $win.${kind}ital

        label $win.${kind}lab     -text $lab

        combobox::combobox $ffont \
            -width 30 \
            -editable false \
            -borderwidth 1
        foreach font $fonts {
            $ffont list insert end $font 
        }

        combobox::combobox $fsize \
            -width 3 \
            -editable false \
            -borderwidth 1
        foreach size $sizes {
            $fsize list insert end $size
        }

        grid $win.${kind}lab $ffont $fsize -row $row -sticky w -pady 2 -padx 2

        if {"body" != $kind && "mono" != $kind} {
            checkbutton $fbold -text "Bold" \
                -variable [varname styles($kind-bold)]
            checkbutton $fital -text "Italic" \
                -variable [varname styles($kind-italic)]
            grid $fbold -row $row -column 3 -sticky w -pady 2 -padx 2
            grid $fital -row $row -column 4 -sticky w -pady 2 -padx 2
        }

        $ffont configure -value [lindex $fonts 0]
        $fsize configure -value [lindex $sizes 0]
    }

    method reset {} {
        foreach kind $kinds {
            # First, get the font data
            set font [prefs get ${kind}text]
            set family [lindex $font 0]
            set size [lindex $font 1]

            # Next, get the choices and index.
            set ffont $win.${kind}font
            set fsize $win.${kind}size
            set fbold $win.${kind}bold
            set fital $win.${kind}ital

            set fi [lsearch [$ffont list get 0 end] $family]
            set si [lsearch [$fsize list get 0 end] $size]

            if {$fi == -1} {
                set fi [lsearch [$ffont list get 0 end] Courier]
            }

            if {$si == -1} {
                set si [lsearch [$ffont list get 0 end] 12]
            }

            $ffont configure -value [$ffont list get $fi]
            $fsize configure -value [$fsize list get $si]

            if {"body" != $kind && "mono" != $kind} {
                if {[lsearch $font bold] == -1} {
                    $fbold deselect
                } else {
                    $fbold select
                }

                if {[lsearch $font italic] == -1} {
                    $fital deselect
                } else {
                    $fital select
                }
            }
        }
    }

    method apply {} {
        foreach kind $kinds {
            # First, get the choices.
            set ffont $win.${kind}font
            set fsize $win.${kind}size
            set fbold $win.${kind}bold
            set fital $win.${kind}ital

            set family [$ffont get]
            set size [$fsize get]

            set font [list $family $size]

            if {"body" != $kind && "mono" != $kind} {
                if {$styles($kind-bold)} {
                    lappend font bold
                }

                if {$styles($kind-italic)} {
                    lappend font italic
                }
            }

            # NEXT, save the font data
            prefs set ${kind}text $font
        }
    }
}

#-----------------------------------------------------------------------
# ColorsTab

snit::widget ::Notebook::prefsdialog::ColorsTab {

    delegate method * to hull
    delegate option * to hull

    variable kinds {
        normal
        title
        pre
        tcl
        link
        button
        warning
        search
        editor
    }

    constructor {args} {
        # Create the color selectors
        $self MakeSelector 1 "Normal Text:"       normal
        $self MakeSelector 2 "Title Text:"        title
        $self MakeSelector 3 "Preformatted Text:" pre
        $self MakeSelector 4 "Tcl Code:"          tcl
        $self MakeSelector 5 "Link Text:"         link
        $self MakeSelector 6 "Button Text:"       button
        $self MakeSelector 7 "Warning Text:"      warning
        $self MakeSelector 8 "Search Text:"       search
        $self MakeSelector 9 "Editor Text:"       editor

        # Get the current user prefs.
        $self reset
    }

    method MakeSelector {row label kind} {
        set lab ${kind}lab
        set fg ${kind}fg
        set bg ${kind}bg
        set samp ${kind}samp

        label  $win.$lab -text $label
        label  $win.$samp -text "Sample Text" \
            -borderwidth 2 -relief ridge
        button $win.$fg -text "Fg" \
            -command [mymethod FgColorMenu $kind]
        button $win.$bg -text "Bg" \
            -command [mymethod BgColorMenu $kind]
        
        grid $win.$lab -row $row -column 0 -sticky w -pady 2 -padx 2
        grid $win.$samp -row $row -column 1 -sticky nsew \
            -pady 2 -padx 2 -ipady 2 -ipadx 2
        grid $win.$fg -row $row -column 2 -sticky nsew -pady 2 -padx 2
        grid $win.$bg -row $row -column 3 -sticky nsew -pady 2 -padx 2
    }

    method FgColorMenu {kind} {
        set btn ${kind}fg
        set samp ${kind}samp

        if {[tk windowingsystem] ne "aqua"} { 
            set color [SelectColor::menu $win.$btn.color \
                           [list below $win.$btn] \
                           -color [$win.$samp cget -foreground]]
        } else {
            set color [tk_chooseColor \
                           -parent $win \
                           -initialcolor [$win.$samp cget -foreground] \
                           -title "Choose Foreground Color"]
        }
        
        if {[string length $color]} {
            $win.$samp configure -foreground $color
        }
    }

    method BgColorMenu {kind} {
        set btn ${kind}bg
        set samp ${kind}samp

        if {[tk windowingsystem] ne "aqua"} { 
            set color [SelectColor::menu $win.$btn.color \
                           [list below $win.$btn] \
                           -color [$win.$samp cget -background]]
        } else {
            set color [tk_chooseColor \
                           -parent $win \
                           -initialcolor [$win.$samp cget -background] \
                           -title "Choose Background Color"]
        }
        
        if {[string length $color]} {
            $win.$samp configure -background $color
        }
    }

    method reset {} {
        foreach kind $kinds {
            set fg ${kind}fg
            set bg ${kind}bg
            set samp ${kind}samp

            $win.$samp configure \
                -foreground [prefs get $fg] \
                -background [prefs get $bg]
        }
    }

    method apply {} {
        foreach kind $kinds {
            set fg ${kind}fg
            set bg ${kind}bg
            set samp ${kind}samp
            
            prefs set $fg [$win.$samp cget -foreground]
            prefs set $bg [$win.$samp cget -background]
        }
    }
}

#-----------------------------------------------------------------------
# Editor Tab

snit::widget ::Notebook::prefsdialog::EditorTab {
    # Make sure that the Notebook BWidget can manage this component.
    delegate option * to hull
    delegate method * to hull

    # Editor options.  Don't worry about default values; they get set
    # from the User Prefs object.
    option -tabwidth
    option -wrapcolumn
    option -autowrap
    option -autoindex

    # Fill in the hull; it's already been created.  Don't worry about
    # command line options; we don't need any.
    constructor {args} {
        # Tab Width Control
        label $win.tabwidthlabel -text "Tab Width"
        grid $win.tabwidthlabel -row 0 -column 0 -sticky w -pady 2 -padx 2

        SpinBox $win.tabwidth \
            -range {1 8 1} \
            -editable 0 \
            -textvariable [varname options(-tabwidth)]
        grid $win.tabwidth -row 0 -column 1 -sticky w -pady 2 -padx 2

        # Wrap Column
        label $win.wrapcolumnlabel -text "Wrap Column"
        grid $win.wrapcolumnlabel -row 1 -column 0 -sticky w -pady 2 -padx 2

        SpinBox $win.wrapcolumn \
            -range {1 255 1} \
            -editable 0 \
            -textvariable [varname options(-wrapcolumn)]
        grid $win.wrapcolumn -row 1 -column 1 -sticky w -pady 2 -padx 2

        # AutoWrap
        label $win.autowraplabel -text "AutoWrap"
        grid $win.autowraplabel -row 2 -column 0 -sticky w -pady 2 -padx 2

        set text {Automatically wrap to the wrap column while entering text.}

        checkbutton $win.autowrap \
            -text $text \
            -justify left \
            -variable [varname options(-autowrap)]
        grid $win.autowrap -row 2 -column 1 -sticky w -pady 2 -padx 2

        # AutoIndent
        label $win.autoindentlabel -text "AutoIndent"
        grid $win.autoindentlabel -row 3 -column 0 -sticky w -pady 2 -padx 2

        set text {Automatically indent to match the previous line on
autowrap or when Tab is pressed at the beginning of the line.}

        checkbutton $win.autoindent \
            -text $text \
            -justify left \
            -variable [varname options(-autoindent)]
        grid $win.autoindent -row 3 -column 1 -sticky w -pady 2 -padx 2

        # Get the current data.
        $self reset
    }

    # Reset value to user prefs.
    method reset {} {
        set options(-tabwidth)   [prefs get tabwidth]
        set options(-wrapcolumn) [prefs get wrapcolumn]
        set options(-autowrap)   [prefs get autowrap]
        set options(-autoindent) [prefs get autoindent]
    }

    # Apply value to user prefs.
    method apply {} {
        prefs set tabwidth   $options(-tabwidth)
        prefs set wrapcolumn $options(-wrapcolumn)
        prefs set autowrap   $options(-autowrap)
        prefs set autoindent $options(-autoindent)
    }
}



#-----------------------------------------------------------------------
# Misc Tab

snit::widget ::Notebook::prefsdialog::MiscTab {
    delegate option * to hull
    delegate method * to hull

    # These are the preferences we control in this tab, with descriptions
    variable strings {
        includetour       {Include "Tour" and other introductory material in new notebook files.}
        editbottom        {Begin editing with the cursor at the bottom of the page.}
        displaydirectives {Display "#" directives in the Page Browser.} 
        silentcreation    {Create new pages on link click without prompting.}
        showsidebar       {Open the Index Sidebar at startup.}
        incrementalsearch {Use Incremental Search by default.}
        contentsearch     {Search both page titles and content by default.}
    }

    variable flags   ;# Array of flag values

    # Variables
    variable nrows 0  ;# Number of rows of options

    # Fill in the hull; it's already been created.
    constructor {args} {
        foreach {name string} $strings {
            set flags($name) 0
            $self add $name $string
        }

        # Get the current data.
        $self reset
    }

    # Add an option
    method add {optname text} {
        checkbutton $win.$optname -text $text \
            -variable [varname flags($optname)] \
            -justify left
        grid $win.$optname -row $nrows -column 1 -sticky w -pady 2 -padx 2

        incr nrows
    }

    # Reset value to user prefs.
    method reset {} {
        foreach name [array names flags] {
            set flags($name) [prefs get $name]
        }
    }

    # Apply value to user prefs.
    method apply {} {
        foreach name [array names flags] {
            prefs set $name $flags($name)
        }
    }
}

#-----------------------------------------------------------------------
# Tcl/Tk Tab

snit::widget ::Notebook::prefsdialog::TclTkTab {
    # Make sure that the Notebook BWidget can manage this component.
    delegate option * to hull
    delegate method * to hull

    # Editor options.  Don't worry about default values; they get set
    # from the User Prefs object.
    option -extpath

    # Fill in the hull; it's already been created.  Don't worry about
    # command line options; we don't need any.
    constructor {args} {
        # Extensions directory
        label $win.extpathlabel -text "Extensions Directory:"
        grid $win.extpathlabel -row 0 -column 0 -sticky w -pady 2 -padx 2

        entry $win.extpath \
            -textvariable [myvar options(-extpath)] \
            -width 60
        grid $win.extpath -row 1 -column 0 -sticky w -pady 2 -padx 2


        label $win.extpathdesc -text \
            "Enter the absolute path to the directory containing your Tcl 
extensions.  This option takes effect on restart." \
            -justify left
        grid $win.extpathdesc -row 2 -column 0 -sticky w -pady 2 -padx 2

        # Get the current data.
        $self reset
    }

    # Reset value to user prefs.
    method reset {} {
        set options(-extpath)   [prefs get extpath]
    }

    # Apply value to user prefs.
    method apply {} {
        prefs set extpath   $options(-extpath)
    }
}


#-----------------------------------------------------------------------
# Scaling Tab

snit::widget ::Notebook::prefsdialog::ScalingTab {
    # Make sure that the Notebook BWidget can manage this component.
    delegate option * to hull
    delegate method * to hull

    # Description of how to set tk scaling
    variable description {
        |Setting the Tk Scaling Factor:
        |
        |Adjust Tk Scaling only if your fonts are an
        |unexpected size.  Nominally, the Tk scaling is
        |the number of points per pixel, or pixels-per-inch
        |divided by 72.0; however, your mileage may vary.
        |
        |Changes to the Tk Scaling factor will take effect
        |when you restart Notebook.
        |
        |See "Scaling Preferences" in the on-line Help
        |for full instructions.
    }

    # Editor options.  Don't worry about default values; they get set
    # from the User Prefs object.
    option -scaling

    # Fill in the hull; it's already been created.  Don't worry about
    # command line options; we don't need any.
    constructor {args} {
        label $win.label1 -text "Tk Scaling:"
        grid $win.label1 -row 0 -column 0 -sticky w -pady 2 -padx 2

        entry $win.data \
            -textvariable [myvar options(-scaling)] \
            -width 20
        grid $win.data -row 1 -column 0 -sticky w -pady 2 -padx 2

        label $win.l2 -text ""
        grid $win.l2 -row 2 -column 0 -pady 2 -padx 2

        label $win.l3 -text "Screen Size:"
        grid $win.l3 -row 3 -column 0 -pady 2 -padx 2
        
        label $win.l4 -text "Width: [winfo screenwidth $win] pixels"
        grid $win.l4 -row 4 -column 0 -pady 2 -padx 2

        label $win.l5 -text "Height: [winfo screenheight $win] pixels"
        grid $win.l5 -row 5 -column 0 -pady 2 -padx 2


        regsub -all -line {^\s*\|} [string trim $description] {} description
        label $win.message \
            -text $description \
            -justify left \
            -anchor nw

        grid $win.message -row 0 -column 1 -rowspan 7 -sticky nw \
            -pady 2 -padx 2

        button $win.default \
            -text "Restore Default Scaling" \
            -command [mymethod RestoreDefault]
        grid $win.default -row 7 -column 0 -columnspan 2 -pady 2 -padx 2

        grid rowconfigure $win 0 -weight 0
        grid rowconfigure $win 1 -weight 0
        grid rowconfigure $win 2 -weight 0
        grid rowconfigure $win 3 -weight 0
        grid rowconfigure $win 4 -weight 0
        grid rowconfigure $win 5 -weight 0
        grid rowconfigure $win 6 -weight 1
        grid rowconfigure $win 7 -weight 0

        # Get the current data.
        $self reset
    }

    # Reset value to user prefs.
    method reset {} {
        set options(-scaling)   [prefs get scaling]
    }

    # Apply value to user prefs.
    method apply {} {
        prefs set scaling   $options(-scaling)
    }

    # Restore default scaling
    method RestoreDefault {} {
        set options(-scaling) [prefs get defaultscaling]
        prefs set scaling $options(-scaling)
        prefs save
    }
}
