#-----------------------------------------------------------------------
# TITLE:
#	nbactionmanager.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#	The nbactionmanager object encapsulates an actionmanager, and
#       module defines the user-interface actions and menus used by
#       Notebook windows.
#
# LICENSE:
#       Copyright (C) 2004 by William H. Duquette.  This file may
#       be used subject to the terms in license.txt.
#
#-----------------------------------------------------------------------


snit::type nbactionmanager {
    #-------------------------------------------------------------------
    # Inheritance

    # An nbactionmanager is an extended actionmanager
    delegate method * to am
    delegate option * to am

    #-------------------------------------------------------------------
    # Creation Options:  These shouldn't be changed after the object
    # is created.  There's no check, though, so just don't do it.

    # Every actionmanager is associated with a toplevel window.
    option -toplevel {}

    # Every toplevel window in the application has a type.
    option -windowtype {}

    #-------------------------------------------------------------------
    # Other components

    variable status    ;# The toplevel's statusentry, which is assumed
                        # to $options(-toplevel).status


    #-------------------------------------------------------------------
    # Other Variables

    # Variable for the Magic Menu's "Expand Macros" flag.
    variable expandMacrosFlag 1

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the actionmanager.
        install am using actionmanager %AUTO% \
            -statecommand [mymethod DefaultStateHandler]

        # NEXT, process the arguments.
        $self configurelist $args

        assert {$options(-toplevel) ne ""}
        assert {$options(-windowtype) ne ""}

        # NEXT, save the components
        set status $options(-toplevel).status

        # NEXT, define the full set of user interface actions
        $self DefineActions

        # NEXT, define the menubar.
        $self DefineMenus

        # NEXT, define window-type-specific behavior
        if {$options(-windowtype) eq "notebookbrowser"} {
            set expandMacrosFlag [$options(-toplevel) cget -expand]
        }
    }

    #------------------------------------------------------------------
    # User Interface Definition

    method DefineActions {} {
        # Defines user interface actions.
        #
        # Actions should be used to define all menu items, keystrokes, 
        # buttons, etc.
        
        # User Interface Actions, in alphabetical order.
        
        $am add about-notebook \
            -command [list $options(-toplevel) about-notebook] \
            -label  "&About Notebook"
        
        $am add back-page \
            -requires {browser !editing} \
            -command [list $options(-toplevel) back-page] \
            -keycodes {any {<BackSpace> BackSpace}} \
            -label "&Back Up One Page" \
            -image ::gui::navback16 \
            -tooltip "Back to the previously viewed page"
        
        $am add cancel-edits \
            -requires {browser editing} \
            -command [list $options(-toplevel) cancel-edits] \
            -keycodes {any {<Escape> Escape}} \
            -image ::gui::actcross16 \
            -tooltip "Cancel your changes and return to browsing."

        $am add close-window \
            -command [list $options(-toplevel) close-window] \
            -keycodes {aqua {<Command-w> Cmd-W}} \
            -keytag $options(-toplevel) \
            -label "&Close Window"

        $am add copy-page-as-expanded-markup \
            -requires {browser} \
            -command [list $options(-toplevel) copy-page-as expanded] \
            -label "As &Expanded Markup..."

        $am add copy-page-as-html-text \
            -requires {browser} \
            -command [list $options(-toplevel) copy-page-as html-text] \
            -label "As &HTML Text..."

        $am add copy-page-as-html-page \
            -requires {browser} \
            -command [list $options(-toplevel) copy-page-as html-page] \
            -label "As an HTML &Page..."

        $am add copy-page-as-mediawiki \
            -requires {browser} \
            -command [list $options(-toplevel) copy-page-as mediawiki] \
            -label "As &MediaWiki Markup..."

        $am add copy-page-as-plain-text \
            -requires {browser} \
            -command [list $options(-toplevel) copy-page-as plain] \
            -label "As Plain &Text..."

        $am add copy-page-as-raw-markup \
            -requires {browser} \
            -command [list $options(-toplevel) copy-page-as raw] \
            -label "As Raw &Markup..."

        # Has -keycodes only for menu display; keystroke generates 
        # <<Copy>> event.
        $am add copy-string \
            -requires <<Copy>> \
            -command [list $options(-toplevel) copy-string] \
            -keycodes {any {<Control-c> Ctrl+C} aqua {<Command-c> Cmd-C}} \
            -label "&Copy" \
            -image ::gui::editcopy16 \
            -tooltip "Copy text to clipboard"

        $am add copy-this-page-as-expanded-markup \
            -requires {browser} \
            -command [list $options(-toplevel) \
                          copy-this-page-as expanded] \
            -label "As &Expanded Markup"

        $am add copy-this-page-as-html-text \
            -requires {browser} \
            -command [list $options(-toplevel) copy-this-page-as html-text] \
            -label "As &HTML Text"

        $am add copy-this-page-as-html-page \
            -requires {browser} \
            -command [list $options(-toplevel) copy-this-page-as html-page] \
            -label "As an HTML &Page"

        $am add copy-this-page-as-mediawiki \
            -requires {browser} \
            -command [list $options(-toplevel) copy-this-page-as mediawiki] \
            -label "As &MediaWiki Markup"

        $am add copy-this-page-as-plain-text \
            -requires {browser} \
            -command [list $options(-toplevel) copy-this-page-as plain] \
            -label "As Plain &Text"

        $am add copy-this-page-as-raw-markup \
            -requires {browser} \
            -command [list $options(-toplevel) copy-this-page-as raw] \
            -label "As Raw &Markup"

        # Has -keycodes only for menu display; keystroke generates 
        # <<Cut>> event.
        $am add cut-string \
            -requires <<Cut>> \
            -command [list $options(-toplevel) cut-string] \
            -keycodes {any {<Control-x> Ctrl+X} aqua {<Command-x> Cmd-X}} \
            -label "Cu&t" \
            -image ::gui::editcut16 \
            -tooltip "Cut text to clipboard"
        
        $am add cycle-recent-pages \
            -requires {browser !editing} \
            -command [list $options(-toplevel) cycle-recent-pages] \
            -keycodes {any {<Control-b> Ctrl+B}} \
            -label  "C&ycle Through Recent Pages"
        
        $am add delete-page \
            -requires {browser !readonly !editing} \
            -command [list $options(-toplevel) delete-page] \
            -label "&Delete Page..."
        
        $am add delete-pages \
            -requires {browser !readonly !editing} \
            -command [list $options(-toplevel) delete-pages] \
            -label "&Delete Pages..."

        $am add edit-page \
            -requires {browser !readonly !editing} \
            -command [list $options(-toplevel) edit-page] \
            -keycodes {aqua {<Shift-Command-e> Shift-Cmd-E}} \
            -label "Edi&t Page..."
        
        $am add edit-preferences \
            -command [list $options(-toplevel) edit-preferences] \
            -keycodes {aqua {<Command-comma> Cmd-,}} \
            -keytag $options(-toplevel) \
            -label "&Preferences..."
        
        $am add edit-this-page \
            -requires {browser !readonly !editing} \
            -command [list $options(-toplevel) edit-this-page] \
            -keycodes {aqua {<Command-e> Cmd-E} any {<Control-e> Ctrl+E}} \
            -label "&Edit This Page" \
            -image ::gui::edit16 \
            -tooltip "Edit this page"
        
        # TBD: Should have a handler method for this one.
        $am add exit \
            -command exit \
            -keycodes {aqua {<Command-q> Cmd-Q}} \
            -keytag $options(-toplevel) \
            -label "E&xit"

        $am add export-notebook-as-html-file \
            -requires {browser} \
            -command [list $options(-toplevel) export-notebook-as-html-file] \
            -label "As Single HTML &File..."
        
        $am add export-notebook-as-html-set \
            -requires {browser} \
            -command [list $options(-toplevel) export-notebook-as-html-set] \
            -label "As &Set of HTML Files..."

        $am add export-page-as-expanded-markup \
            -requires {browser} \
            -command [list $options(-toplevel) export-page-as expanded] \
            -label "As &Expanded Markup..."

        $am add export-page-as-html-text \
            -requires {browser} \
            -command [list $options(-toplevel) export-page-as html-text] \
            -label "As &HTML Text..."

        $am add export-page-as-html-page \
            -requires {browser} \
            -command [list $options(-toplevel) export-page-as html-page] \
            -label "As an HTML &Page..."

        $am add export-page-as-mediawiki \
            -requires {browser} \
            -command [list $options(-toplevel) export-page-as mediawiki] \
            -label "As &MediaWiki Markup..."

        $am add export-page-as-plain-text \
            -requires {browser} \
            -command [list $options(-toplevel) export-page-as plain] \
            -label "As Plain &Text..."

        $am add export-page-as-raw-markup \
            -requires {browser} \
            -command [list $options(-toplevel) export-page-as raw] \
            -label "As Raw &Markup..."

        $am add export-this-page-as-expanded-markup \
            -requires {browser} \
            -command [list $options(-toplevel) export-this-page-as expanded] \
            -label "As &Expanded Markup"

        $am add export-this-page-as-html-text \
            -requires {browser} \
            -command [list $options(-toplevel) export-this-page-as html-text] \
            -label "As &HTML Text"

        $am add export-this-page-as-html-page \
            -requires {browser} \
            -command [list $options(-toplevel) export-this-page-as html-page] \
            -label "As an HTML &Page"

        $am add export-this-page-as-mediawiki \
            -requires {browser} \
            -command [list $options(-toplevel) export-this-page-as mediawiki] \
            -label "As &MediaWiki Markup"

        $am add export-this-page-as-plain-text \
            -requires {browser} \
            -command [list $options(-toplevel) \
                          export-this-page-as plain] \
            -label "As Plain &Text"

        $am add export-this-page-as-raw-markup \
            -requires {browser} \
            -command [list $options(-toplevel) \
                          export-this-page-as raw] \
            -label "As Raw &Markup"

        $am add find-string \
            -requires {browser} \
            -command [list $options(-toplevel) find-string] \
            -keycodes {aqua {<Command-f> Cmd-F} any {<Control-f> Ctrl+F}} \
            -label "&Find"
        
        $am add find-again \
            -requires {browser editing} \
            -command [list $options(-toplevel) find-again] \
            -keycodes {aqua {<Command-g> Cmd-G} any {<Control-g> Ctrl+G}} \
            -label "Find &Again"
        
        $am add forward-page \
            -requires {browser !editing} \
            -command [list $options(-toplevel) forward-page] \
            -label  "&Forward One Page" \
            -image ::gui::navforward16 \
            -tooltip "Forward to a previously browsed page."
        
        $am add goto-home \
            -requires {browser !editing} \
            -command [list $options(-toplevel) goto-home] \
            -label "Go To &Home" \
            -image ::gui::navhome16 \
            -tooltip "Go to your home page"

        # DEPRECATED
        $am add goto-index \
            -requires {browser !editing} \
            -command [list $options(-toplevel) goto-index] \
            -label "Go To &Index" \
            -image ::gui::appbook16 \
            -tooltip "Go to the Index page"

        $am add goto-next-page \
            -requires {browser !editing} \
            -command [list $options(-toplevel) goto-next-page] \
            -keycodes {any {<Control-n> Ctrl+N}} \
            -label "&Next Page In Sidebar"
        
        $am add goto-page \
            -requires {browser !editing} \
            -command [list $options(-toplevel) goto-page] \
            -label "&Go To Page..."

        $am add goto-previous-page \
            -requires {browser !editing} \
            -command [list $options(-toplevel) goto-previous-page] \
            -keycodes {any {<Control-p> Ctrl+P}} \
            -label "&Previous Page In Sidebar"

        #DEPRECATED
        $am add goto-recent-changes \
            -requires {browser !editing} \
            -command [list $options(-toplevel) goto-recent-changes] \
            -label "Go To Recent &Changes"

        $am add goto-user-code \
            -requires {browser !editing} \
            -command [list $options(-toplevel) goto-user-code] \
            -label "Go To &User Code"

        $am add help-on \
            -command [list $options(-toplevel) help-on] \
            -label "&Topic..."

        $am add help-introduction \
            -command [list $options(-toplevel) help-introduction] \
            -keycodes {aqua {<Command-?> Cmd-?} any {<F1> F1}} \
            -keytag $options(-toplevel) \
            -label "Notebook &Help"

        $am add help-index \
            -command [list $options(-toplevel) help-index] \
            -label  "&Index"
        
        $am add help-on-actions \
            -command [list $options(-toplevel) help-on-actions] \
            -label  "&User Interface Actions"
        
        $am add help-on-commands \
            -command [list $options(-toplevel) help-on-commands] \
            -label  "Notebook &Commands"
        
        $am add help-on-markup \
            -command [list $options(-toplevel) help-on-markup] \
            -label  "Notebook Markup"
        
        $am add insert-page \
            -requires {browser editing} \
            -command [list $options(-toplevel) insert-page] \
            -label "Insert Pa&ge"

        $am add load-page \
            -requires {browser} \
            -command [list $options(-toplevel) load-page] \
            -keycodes {aqua {<Shift-Command-l> Shift-Cmd-L} 
                any {<Shift-Control-l> Shift+Ctrl+L}} \
            -label "Load &Page..."

        $am add load-this-page \
            -requires {browser} \
            -command [list $options(-toplevel) load-this-page] \
            -keycodes {aqua {<Command-l> Cmd-L} any {<Control-l> Ctrl+L}} \
            -label "&Load This Page"

        $am add load-user-code \
            -requires {browser} \
            -command [list $options(-toplevel) load-user-code] \
            -keycodes {aqua {<Command-u> Cmd-U} any {<Control-u> Ctrl+U}} \
            -label "Load &User Code"

        # TBD: Fix the command when we're ready for that.
        $am add message-log \
            -command [list messagelog show] \
            -keycodes {aqua {<Command-m> Cmd-M}} \
            -keytag $options(-toplevel) \
            -label "Message Log"

        $am add new-notebook \
            -command [list $options(-toplevel) new-notebook] \
            -keycodes {aqua {<Shift-Command-n> Shift-Cmd-N}} \
            -keytag $options(-toplevel) \
            -label "New Note&book..."

        $am add new-window \
            -requires {browser} \
            -command [list $options(-toplevel) new-window] \
            -keycodes {aqua {<Command-n> Cmd-N}} \
            -label "&New Window"

        $am add notebook-license \
            -command [list $options(-toplevel) notebook-license] \
            -label "&License"

        $am add notebook-release-notes \
            -command [list $options(-toplevel) notebook-release-notes] \
            -label "&Release Notes For [version]"
        
        $am add open-notebook \
            -command [list $options(-toplevel) open-notebook] \
            -keycodes {aqua {<Command-o> Cmd-O}} \
            -keytag $options(-toplevel) \
            -label "&Open Notebook..."

        # Has -keycodes only for menu display; keystroke generates 
        # <<Paste>> event.
        $am add paste-string \
            -requires <<Paste>> \
            -command [list $options(-toplevel) paste-string] \
            -keycodes {any {<Control-v> Ctrl+V} aqua {<Command-v> Cmd-V}} \
            -label "&Paste" \
            -image ::gui::editpaste16 \
            -tooltip "Paste text from clipboard"

        # Has -keycodes only for menu display; keystroke generates 
        # <<Redo>> event.
        $am add redo-change \
            -requires <<Redo>> \
            -command [list $options(-toplevel) redo-change] \
            -keycodes {win32 {<Control-y> Ctrl+Y} 
                x11   {<Shift-Control-z> Shift+Ctrl+Z} \
                           aqua  {<Shift-Command-z> Shift-Cmd-Z}} \
            -label "&Redo" \
            -image ::gui::actredo16 \
            -tooltip "Redo last set of undone changes"

        $am add refresh-this-page \
            -requires {browser !editing} \
            -command [list $options(-toplevel) refresh-this-page] \
            -keycodes {any {<Control-r> Ctrl+R}} \
            -label "Re&fresh Page"

        $am add rename-page \
            -requires {browser !readonly !editing} \
            -command [list $options(-toplevel) rename-page] \
            -keycodes {aqua {<Shift-Command-r> Shift-Cmd-R}} \
            -label "Ren&ame Page..."
        
        $am add rename-this-page \
            -requires {browser !readonly !editing} \
            -command [list $options(-toplevel) rename-this-page] \
            -keycodes {aqua {<Command-r> Cmd-R}} \
            -label "&Rename This Page..."
        
        $am add replace-string \
            -requires {browser editing} \
            -command [list $options(-toplevel) replace-string] \
            -keycodes {aqua {<Shift-Command-f> Shift-Cmd-F} 
                any {<Shift-Control-f> Shift+Ctrl+F}} \
            -label "&Replace"

        $am add request-action \
            -command [list $options(-toplevel) request-action] \
            -keycodes {any {<Control-quoteleft> Ctrl+`}} \
            -keytag $options(-toplevel) \
            -label "Invoke Action..."

        $am add save-and-continue \
            -requires {browser editing} \
            -command [list $options(-toplevel) save-and-continue] \
            -keycodes {any {<Shift-Control-s> Shift+Ctrl+S}} \
            -image ::gui::filesave16 \
            -tooltip "Save your changes and continue editing."

        $am add save-edits \
            -requires {browser editing} \
            -command [list $options(-toplevel) save-edits] \
            -keycodes {any {<Control-s> Ctrl+S}} \
            -image ::gui::actcheck16 \
            -tooltip "Save your changes and return to browsing."

        $am add show-index \
            -requires {browser} \
            -command [list $options(-toplevel) show-index] \
            -label "Show &Index" \
            -image ::gui::appbook16 \
            -tooltip "Show the Page Index"

        $am add show-recent \
            -requires {browser} \
            -command [list $options(-toplevel) show-recent] \
            -label "Show Recent &Changes" \
            -image ::gui::closex \
            -tooltip "Show Recent Changes"

        $am add show-version \
            -command [list $options(-toplevel) show-version]

        $am add sidebar-byname \
            -requires {browser} \
            -command [list $options(-toplevel) sidebar-byname] \
            -image ::gui::textsortinc16 \
            -label "Sort by &Name" \
            -tooltip "Sort Sidebar by Page Name"

        $am add sidebar-bytime \
            -requires {browser} \
            -command [list $options(-toplevel) sidebar-bytime] \
            -image ::gui::timesort16 \
            -label "Sort by &Time" \
            -tooltip "Sort Sidebar by Page Time"

        $am add sidebar-close \
            -requires {browser} \
            -command [list $options(-toplevel) sidebar-close] \
            -image ::gui::leftarrow \
            -label "&Close Sidebar" \
            -tooltip "Close the Sidebar"


        $am add sidebar-open \
            -requires {browser} \
            -command [list $options(-toplevel) sidebar-open]

        # Has -keycodes only for menu display; keystroke generates 
        # <<Undo>> event.
        $am add undo-change \
            -requires <<Undo>> \
            -command [list $options(-toplevel) undo-change] \
            -keycodes {any {<Control-z> Ctrl+Z} aqua {<Command-z> Cmd-Z}} \
            -label "&Undo" \
            -image ::gui::actundo16 \
            -tooltip "Undo the last set of changes."

    }

    # Creates the standard menu bar for this application.
    method DefineMenus {} {
        menu $options(-toplevel).menubar
        $options(-toplevel) configure -menu $options(-toplevel).menubar

        $self DefineFileMenu
        $self DefineEditMenu
        $self DefinePageMenu
        $self DefineSidebarMenu
        $self DefineMagicMenu
        $self DefineWindowMenu
        $self DefineHelpMenu
    }

    # Creates the standard File Menu.
    method DefineFileMenu {} {
        menu $options(-toplevel).menubar.file
        $options(-toplevel).menubar add cascade \
            -label "File" \
            -underline 0 \
            -menu $options(-toplevel).menubar.file

        $am addmenuitem $options(-toplevel).menubar.file new-window
        $am addmenuitem $options(-toplevel).menubar.file new-notebook
        $am addmenuitem $options(-toplevel).menubar.file open-notebook 
        $am addmenuitem $options(-toplevel).menubar.file edit-preferences 

        $options(-toplevel).menubar.file add separator

        menu $options(-toplevel).menubar.file.export
        $options(-toplevel).menubar.file add cascade \
            -label "Export" \
            -underline 0 \
            -menu $options(-toplevel).menubar.file.export

        $am addmenuitem $options(-toplevel).menubar.file.export \
            export-notebook-as-html-file
        $am addmenuitem $options(-toplevel).menubar.file.export \
            export-notebook-as-html-set

        $options(-toplevel).menubar.file add separator

        $am addmenuitem $options(-toplevel).menubar.file close-window 
        $am addmenuitem $options(-toplevel).menubar.file request-action
        
        # File/Console  (but not on X Windows)
        if {[tk windowingsystem] eq "win32"} {
            $options(-toplevel).menubar.file add command \
                -label "Console" \
                -underline 0 \
                -command {console show}
        }

        # On aqua, the menu item is provided automatically
        if {[tk windowingsystem] ne "aqua"} {
            $options(-toplevel).menubar.file add separator
            $am addmenuitem $options(-toplevel).menubar.file exit
        }
    }


    # Creates the standard Edit menu.
    method DefineEditMenu {} {
        menu $options(-toplevel).menubar.edit
        $options(-toplevel).menubar add cascade \
            -label "Edit" \
            -underline 0 \
            -menu $options(-toplevel).menubar.edit

        $am addmenuitem $options(-toplevel).menubar.edit undo-change
        $am addmenuitem $options(-toplevel).menubar.edit redo-change

        $options(-toplevel).menubar.edit add separator

        $am addmenuitem $options(-toplevel).menubar.edit cut-string
        $am addmenuitem $options(-toplevel).menubar.edit copy-string

        menu $options(-toplevel).menubar.edit.copypage
        $options(-toplevel).menubar.edit add cascade \
            -label "Copy Page" \
            -underline 5 \
            -menu $options(-toplevel).menubar.edit.copypage

        $am addmenuitem $options(-toplevel).menubar.edit.copypage \
            copy-this-page-as-html-text
        $am addmenuitem $options(-toplevel).menubar.edit.copypage \
            copy-this-page-as-html-page
        $am addmenuitem $options(-toplevel).menubar.edit.copypage \
            copy-this-page-as-plain-text
        $am addmenuitem $options(-toplevel).menubar.edit.copypage \
            copy-this-page-as-mediawiki
        $am addmenuitem $options(-toplevel).menubar.edit.copypage \
            copy-this-page-as-expanded-markup
        $am addmenuitem $options(-toplevel).menubar.edit.copypage \
            copy-this-page-as-raw-markup

        $am addmenuitem $options(-toplevel).menubar.edit paste-string

        $options(-toplevel).menubar.edit add separator

        $am addmenuitem $options(-toplevel).menubar.edit insert-page

        $options(-toplevel).menubar.edit add separator

        $am addmenuitem $options(-toplevel).menubar.edit find-string
        $am addmenuitem $options(-toplevel).menubar.edit find-again
        $am addmenuitem $options(-toplevel).menubar.edit replace-string
    }

    # Creates the standard Page menu.
    method DefinePageMenu {} {
        menu $options(-toplevel).menubar.page
        $options(-toplevel).menubar add cascade \
            -label "Page" \
            -underline 0 \
            -menu $options(-toplevel).menubar.page

        menu $options(-toplevel).menubar.page.export
        $options(-toplevel).menubar.page add cascade \
            -label "Export" \
            -underline 3 \
            -menu $options(-toplevel).menubar.page.export

        $am addmenuitem $options(-toplevel).menubar.page.export \
            export-this-page-as-html-text
        $am addmenuitem $options(-toplevel).menubar.page.export \
            export-this-page-as-html-page
        $am addmenuitem $options(-toplevel).menubar.page.export \
            export-this-page-as-plain-text
        $am addmenuitem $options(-toplevel).menubar.page.export \
            export-this-page-as-mediawiki
        $am addmenuitem $options(-toplevel).menubar.page.export \
            export-this-page-as-expanded-markup
        $am addmenuitem $options(-toplevel).menubar.page.export \
            export-this-page-as-raw-markup

        $options(-toplevel).menubar.page add separator

        $am addmenuitem $options(-toplevel).menubar.page edit-this-page
        $am addmenuitem $options(-toplevel).menubar.page rename-this-page
        $am addmenuitem $options(-toplevel).menubar.page refresh-this-page
        $am addmenuitem $options(-toplevel).menubar.page edit-page
        $am addmenuitem $options(-toplevel).menubar.page rename-page
        $am addmenuitem $options(-toplevel).menubar.page delete-page
        $am addmenuitem $options(-toplevel).menubar.page delete-pages

        $options(-toplevel).menubar.page add separator

        $am addmenuitem $options(-toplevel).menubar.page back-page
        $am addmenuitem $options(-toplevel).menubar.page forward-page
        $am addmenuitem $options(-toplevel).menubar.page cycle-recent-pages
        $am addmenuitem $options(-toplevel).menubar.page goto-previous-page
        $am addmenuitem $options(-toplevel).menubar.page goto-next-page
        
        $options(-toplevel).menubar.page add separator

        $am addmenuitem $options(-toplevel).menubar.page goto-page
        $am addmenuitem $options(-toplevel).menubar.page goto-home
    }

    # Creates the standard Sidebar menu.
    method DefineSidebarMenu {} {
        menu $options(-toplevel).menubar.sidebar
        $options(-toplevel).menubar add cascade \
            -label "Sidebar" \
            -underline 0 \
            -menu $options(-toplevel).menubar.sidebar

        $am addmenuitem $options(-toplevel).menubar.sidebar show-index
        $am addmenuitem $options(-toplevel).menubar.sidebar show-recent
        $am addmenuitem $options(-toplevel).menubar.sidebar sidebar-close

        $options(-toplevel).menubar.sidebar add separator

        $am addmenuitem $options(-toplevel).menubar.sidebar sidebar-byname
        $am addmenuitem $options(-toplevel).menubar.sidebar sidebar-bytime
    }

    # Creates the standard Magic menu.
    method DefineMagicMenu {} {
        menu $options(-toplevel).menubar.magic
        $options(-toplevel).menubar add cascade \
            -label "Magic" \
            -underline 0 \
            -menu $options(-toplevel).menubar.magic

        $am addmenuitem $options(-toplevel).menubar.magic goto-user-code

        $options(-toplevel).menubar.magic add separator

        $am addmenuitem $options(-toplevel).menubar.magic load-this-page
        $am addmenuitem $options(-toplevel).menubar.magic load-page
        $am addmenuitem $options(-toplevel).menubar.magic load-user-code

        $options(-toplevel).menubar.magic add separator

        if {$options(-windowtype) eq "notebookbrowser"} {
            $options(-toplevel).menubar.magic add checkbutton \
                -label "Expand Macros?" \
                -underline 0 \
                -variable [varname expandMacrosFlag] \
                -onvalue 1 \
                -offvalue 0 \
                -command [mymethod SetExpandFlag]
        } else {
            $options(-toplevel).menubar.magic add checkbutton \
                -label "Expand Macros?" \
                -underline 0 \
                -state disabled
        }
    }

    method SetExpandFlag {} {
        $options(-toplevel) configure -expand $expandMacrosFlag
    }

    # Creates the standard Window menu.
    method DefineWindowMenu {} {
        menu $options(-toplevel).menubar.window

        $options(-toplevel).menubar add cascade \
            -label "Window" \
            -underline 0 \
            -menu $options(-toplevel).menubar.window

        $am addmenuitem $options(-toplevel).menubar.window message-log

        $options(-toplevel).menubar.window add separator

        $options(-toplevel).menubar.window add command -label Dummy

        # Add the post command now, to replace the one added by
        # the action manager.
        $options(-toplevel).menubar.window configure \
            -postcommand [mymethod WindowMenuPostCommand \
                              $options(-toplevel).menubar.window]
    }

    method WindowMenuPostCommand {menu} {
        $menu delete 2 end

        foreach window [windowmanager windows] {
            $menu add command \
                -label [wm title $window] \
                -command [list windowmanager raise $window]
        }
        
        update idletasks
    }

    # Creates the standard Help menu
    method DefineHelpMenu {} {
        menu $options(-toplevel).menubar.help

        $options(-toplevel).menubar add cascade \
            -label "Help" \
            -underline 0 \
            -menu $options(-toplevel).menubar.help

        $am addmenuitem $options(-toplevel).menubar.help help-introduction
        $am addmenuitem $options(-toplevel).menubar.help help-index
        $am addmenuitem $options(-toplevel).menubar.help help-on
        $am addmenuitem $options(-toplevel).menubar.help help-on-commands
        $am addmenuitem $options(-toplevel).menubar.help help-on-actions
        $am addmenuitem $options(-toplevel).menubar.help help-on-markup
        
        $options(-toplevel).menubar.help add separator

        $am addmenuitem $options(-toplevel).menubar.help notebook-license
        $am addmenuitem $options(-toplevel).menubar.help notebook-release-notes
        $am addmenuitem $options(-toplevel).menubar.help about-notebook
    }


    #-------------------------------------------------------------------
    # Private Behavior

    # Determines action state for this window.  Returns "disabled" if any 
    # condition isn't met, and "normal" otherwise.
    method DefaultStateHandler {action requirements} {
        foreach condition $requirements {
            switch -glob -- $condition {
                <*> { 
                    if {![hasbinding [focus] $condition]} {return disabled}
                }
                default {
                    return disabled
                }
            }
        }

        return normal
    }

    #-------------------------------------------------------------------
    # Shared Action Handlers
    #
    # These action handlers are the same for all window types, so they
    # are defined here.

    # Action: about-notebook
    method about-notebook {} {
        $options(-toplevel) help-on "About Notebook"
    }

    # Action: close-window
    method close-window {} {
        after idle [list windowmanager destroy $options(-toplevel)]
    }

    # Action: copy-string
    method copy-string {} {
        event generate [focus] <<Copy>>
    }

    # Action: cut-string
    method cut-string {} {
        event generate [focus] <<Cut>>
    }

    # Action: edit-preferences
    method edit-preferences {} {
        prefs dialog
    }

    # Action: help-on ?topic?
    #
    # Prompts the user for a help topic if need be.
    method help-on {{topic ""}} {
        if {$topic eq ""} {
            $status request \
                -command showhelp \
                -prompt "Help topic" \
                -default $topic
        } else {
            showhelp $topic
            $status msg ""
        }
    }

    # Action: help-introduction
    method help-introduction {} {
        $options(-toplevel) help-on Help
    }

    # Action: help-index
    method help-index {} {
        $options(-toplevel) help-on Index
    }

    # Action: help-on-actions
    method help-on-actions {} {
        $options(-toplevel) help-on "User Interface Actions"
    }

    # Action: help-on-commands
    method help-on-commands {} {
        $options(-toplevel) help-on "Notebook Commands"
    }

    # Action: help-on-markup
    method help-on-markup {} {
        $options(-toplevel) help-on "Markup Quick Reference"
    }

    # Action: new-notebook
    #
    # Creates a new notebook file and opens it, prompting for the file
    # name
    method new-notebook {} {
        try {
            set newdb [dbmanager new $options(-toplevel)]
        } trap notebookdb::loaderror {msg} {
            throw USER $smg
        }

        if {$newdb eq ""} {
            error "Cancelled." {} USER
        }

        notebookbrowser .%AUTO% -db $newdb
    }

    # Action: notebook-license
    method notebook-license {} {
        $options(-toplevel) help-on License
    }

    # Action: notebook-release-notes
    method notebook-release-notes {} {
        $options(-toplevel) help-on "Release Notes"
    }

    # Action: open-notebook
    #
    # Opens a notebook file in the page browser, replacing the
    # existing notebook. 

    method open-notebook {} {
        try {
            set newdb [dbmanager open $options(-toplevel)]
        } trap notebookdb::loaderror {msg} {
            throw $msg USER
        }

        if {$newdb eq ""} {
            error "Cancelled." {} USER
        }

        notebookbrowser .%AUTO% -db $newdb
    }

    # Action: paste-string
    method paste-string {} {
        event generate [focus] <<Paste>>
    }

    # Action: redo-change
    method redo-change {} {
        event generate [focus] <<Redo>>
    }

    # Action: request-action ?action?
    #
    # Prompts the user for an action to invoke
    method request-action {{action ""}} {
        if {$action eq ""} {
            # Update the action states, so that only valid actions
            # can be entered.
            $am updatestate

            $status request \
                -command [list $am invoke] \
                -prompt "Action" \
                -enum [$am list normal] \
                -strict 1
        } else {
            $am invoke $action
        }
    }

    # Action: undo-change
    method undo-change {} {
        event generate [focus] <<Undo>>
    }

    # Action: show-version
    #
    # Display the notebook version in the statusentry.
    method show-version {} {
        $status msg "Notebook $::notebookVersion"
    }
}