source markupparser.tcl
namespace import ::markupparser::*




proc lshift {listvar} {
    upvar $listvar args
      
    if {[llength $args] == 0} {
        set arg ""
    } elseif {[llength $args] == 1} {
        set arg [lindex $args 0]
        set args ""
    } else {
        set arg [lindex $args 0]
        set args [lrange $args 1 end]
    }
    
    return $arg
}

proc showParseResults {markup} {
    set taglist [parse $markup]

    foreach {tag value} $taglist {
        puts [list $tag $value]
    }
}

if {$argc == 0} {
    puts "Usage: parse.tcl files..."
    exit
}


set f [open [lindex $argv 0] r]
set markup [read $f]
close $f

showParseResults $markup


