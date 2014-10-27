markupparser 2.0
-----------------------------------------------------------------

markupparser parses Notebook markup into an intermediary form,
a flat list of tag/value pairs.  The parsing proceeds by first 
breaking the input into chunk, where each chunk consists
of one or more full lines of text.  There are (at present)
four kinds of chunk:

Directives
    A directive is a line beginning with a hash "#" character;
    the specific directive is determined by the text that follows
    the hash character.  Unless otherwise indicated, any 
    subsequent text on the line is ignored.  Unrecognized
    directives are permitted.  The existing directives are as 
    follows:

    #--- 
        Rendered as a horizontal line, e.g., <hr>.

    #pre
        Begins a chunk of preformatted text.

    #unpre
        Ends a chunk of preformatted text.

    #Tcl
        Begins a chunk of Tcl Code

    #unTcl
        Ends a chunk of Tcl Code

    #meta <keyword> <value>
        Defines a named value associated with the pages.  It will be
        possible to query a page for its metadata.

    #data <typename>
        Begins a data chunk.  A data chunk is just like a Tcl Code or
        preformatted text chunk in terms of how it's handled; however,
        it will allow other code to easily extract data of a specific
        type from a page.  Eventually, it might be possible to add
        rendering plugins for specific data types.

    #undata
        Ends a data chunk.

Preformatted
    A preformatted chunk is to be rendered verbatim in a
    fixed-width font.  Performatted chunks are found in two
    ways: either a paragraph whose first line begins with
    a whitespace character, or a group of lines beginning with
    a "#pre" directive and ending with a "#unpre" directive
    (or the end of the input).  (The directives are not
    part of the chunk.)

Tcl Code
    A Tcl code chunk is usually rendered Preformatted; it is
    a group of lines bracketed by "#Tcl" and "#unTcl".

Wrapped Text
    A wrapped text paragraph consists of one or more lines of 
    possibly styled text.  Wrapped text paragraphs can be 
    indented; if indented they can have a bullet.  Wrapped
    text can also contain links, magic buttons, and embedded
    macros.

    Note: embedded macros are usually expanded *before* parsing
    the markup, so usually there won't be any in the input.  If
    there are any, they could be anywhere, in any kind of text.
    However, the parser will only recognize them in wrapped text.

Pass-through Text
    Sometimes it's desirable to include text in a page that will be 
    passed through the parser unchanged, e.g., when using macros
    to generate HTML in a page that will be exported as HTML.  
    There are two ways to specify pass-through text.

        #data thru
        Text to be passed through.
        #undata

    Text wrapped by #data thru/#undata will go through the parser
    unchanged, and will be handled by output processors as a single
    paragraph.

        This text has some <thru><tt>HTML</tt></thru> markup.

    Within a paragraph of wrapped text, the <thru>...</thru>
    tags can be used to quote a section of text to pass
    through unchanged.  If the example above were exported
    as HTML without the <thru>...</thru> tags, the angle
    brackets on <tt> and </tt> would be escaped as
    &lt; and &gt;.


Intermediate Form
-----------------------------------------------------------------

The parser parses the input and produces the intermediate form,
a flat list of tag/value pairs.  The tags and their values are
defined as follows:


META <dictionary>
    The value of META is a dict of the #meta values defined in
    this page.  If the same keyword appears multiple times, the
    final value is retained.  If no #meta directives appear in
    this page, META appears with an empty list as its value.

    META is always the first tag in the list.

HASH <directive>
    One of these pairs is produced for each directive; the value is
    the complete line of text, including the newline at the end.

PRE <text>
    This is usually Preformatted text, to be displayed verbatim.  The
    value is the exact set of lines from the input.  If the chunk was
    delimited by "#pre" and "#unpre" directives, then this tag/value
    will be preceded and followed by the appropriate HASH tag/values.

TCL <text> 
    The <text> is a chunk of Tcl code. This tag/value will be preceded
    and followed by the "#Tcl" and "#unTcl" HASH tag/values.

DATA {<name> <text>}
    The value of DATA is a list of two elements; the data name from
    the #data line and the chunk of data that appeared between the
    #data and #undata.

    When the <name> is "thru", the <text> is to be passed through
    the parser unchanged.

P {:|* <indent> <leading>} 
    Begins a paragraph of wrapped text.  The value is a list of three
    items: the paragraph type (":" or "*"), the indent level (0 or
    higher) and (for indented and bulleted paragraphs) the leading
    string, which is the whitespace between the initial "*" or ":"
    and the paragraph text.  (It's used to reconstruct a parsed page
    just exactly as it was.)

    A normal, non-indented non-bulleted paragraph will begin with

        P {: 0 {}}

    A paragraph with an indent level of 1 will begin with this
    (where the length of the leading string depends on the actual
    input):

        P {: 1 { }}

    A bulleted paragraph with an indent level of 1 will begin with
    this:

        P {* 1 { }}

    For bulleted paragraphs, the indent level must be 1 or more.
    Note that a normal paragraph is simply an indented paragraph
    with an indent level of zero.

/P
    Terminates a paragraph of wrapped text, of whatever kind.

The following tags represent components of a paragraph of wrapped
text; they will always appear between P and /P.

TXT <text>
    The value is plain text to be wrapped and rendered.

THRU <text>
    The value is text in the current output format; it
    was passed through the parser unchanged.

STY {<style-code> <style-letter> <flag>}
    Notebook markup defines a number of HTML-like style codes,
    e.g., <b>...</b> and <i>...</i>.  When one is found in a 
    wrapped paragraph, this tag is generated.  The tag's value is
    a list of three elements: the raw style code (</b>), the
    style letter (b), and a flag: 1 when the style turns on and
    0 when the style turns off.  Note that all styles are
    cancelled at the end of the paragraph.  

    A renderer is free to render the styles as it prefers.

LINK <link text> 
    The value is a page link, not including the [ and ].

BTN <button text|command>
    The value is the definition of a magic button, not including the
    [% and %].

MACRO <macro> 
    The value is an embedded macro command, not including the [@ and @].
