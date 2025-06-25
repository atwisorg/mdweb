#!/bin/bash
# mdweb.sh. Convert markdown to html.
#
# Copyright (c) 2025 Semyon A Mironov
#
# Authors: Semyon A Mironov <s.mironov@atwis.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
set -eu
usage ()
{
    echo "Usage: $PKG [OPTION] [-s PAGE_STYLE] [-t PAGE_TITLE] [-i] FILE [[-o] <path>]"
}

show_help ()
{
    usage
    echo "
Options:
  -f, --force               do not prompt before overwriting
  -i, --input=FILE          specify the path to the file for tagging the code
  -o, --output=<path>       specify the path to save
  -s, --style=<style>       specify the style of the HTML page
  -t, --title=<title>       specify the HTML page title
  -v, --version             display version information and exit
  -h, -?, --help            display this help and exit

  An argument of '--' disables further option processing

Report bugs to: bug-$PKG@atwis.org
$PKG home page: <https://www.atwis.org/shell-script/$PKG/>"
    die
}

show_version ()
{
    echo "${0##*/} ${1:-0.0.1} - (C) 25.06.2025

Written by Mironov A Semyon
Site       www.atwis.org
Email      info@atwis.org"
    die
}

try ()
{
    get_rc "$@" >&2
    echo "Try '$PKG --help' for more information."
    exit "$RETURN"
}

say ()
{
    echo "$PKG:${FUNC_NAME:+" $FUNC_NAME:"}${1:+" $@"}"
}

get_rc ()
{
    RETURN="$?"
    case "${1:-}" in
        *[!0-9]*|"")
            ;;
        *)
            RETURN="$1"
            shift
    esac
    case "$@" in
        ?*)
            say "$*"
    esac
}

die ()
{
    get_rc "$@" >&2
    exit "$RETURN"
}

is_diff ()
{
    case "${1:-}" in
        "${2:-}")
            return 1
    esac
}

is_equal ()
{
    case "${1:-}" in
        "${2:-}")
            return 0
    esac
    return 1
}

is_empty ()
{
    case "${1:-}" in
        ?*)
            return 1
    esac
}

is_not_empty ()
{
    case "${1:-}" in
        "")
            return 1
    esac
}

is_dir ()
{
    test -d "${1:-}"
}

is_exists ()
{
    test -e "${1:-}"
}

is_file ()
{
    test -f "${1:-}"
}

get_file_descriptor ()
{
    case "${1:-1}" in
        1|stdout)
            echo 1 ;;
        2|stderr|stderror)
            echo 2 ;;
        * ) echo "$1"
    esac
}

is_terminal ()
{
    test -t "$(get_file_descriptor "${1:-1}")"
}

is_not_terminal ()
{
    is_terminal "${1:-1}" && return 1 || return 0
}

get_inode ()
{
    INODE="$(ls -Li "/dev/fd/$(get_file_descriptor "${1:-1}")")"
    echo "${INODE%%[[:blank:]]*}"
}

is_equal_fds ()
{
    is_not_empty "${1:-}" &&
    is_not_empty "${2:-}" &&
    STATUS="$(ls -Li "/dev/fd/1" 2>&1)" || return 0
    is_equal "$(get_inode "$1")" "$(get_inode "$2")"
}

request ()
{
    while :
    do
        is_empty "${1:-}" || echo -n "$(say "$1")"
        while IFS= read REPLY
        do
            case "${REPLY:-}" in
                [yYдД]|[yY][eE]|[yY][eE][sS]|[дД][аА])
                    return 0
                    ;;
                ""|[nNнН]|[nN][oO]|[нН][еЕ]|[нН][еЕ][тТ])
                    return 1
                    ;;
                *)
                    say "invalid input: -- '$REPLY'" >&2
                    break
            esac
        done
    done
}

abs_dirpath ()
{
    cd -- "$1" 2>&1 && pwd -P 2>&1
}

get_pkg_vars ()
{
    PKG="${0##*/}"
    PKG_DIR="${0%"$PKG"}"
    PKG_DIR="${PKG_DIR:-/}"
    PKG_DIR="$(abs_dirpath "$PKG_DIR")"
    PKG_PATH="$PKG_DIR/$PKG"
    MASK_NEW_LINE="$(tr '\n' '\01' <<< "")"
    NEW_LINE='
'
}

main ()
{
    get_pkg_vars
    argparse "$@"
    is_empty "${HELP:-}"    || show_help
    is_empty "${VERSION:-}" || show_version
    check_args

    is_empty "${OUTPUT:-}" && exec 3>&1 || exec 3>"$OUTPUT"
    is_empty "${OUTPUT:-}" && {
        is_terminal stdout && {
            is_terminal stderr && convert >&3 || report_and_convert
        }
    } || {
        is_not_terminal stderr && is_equal_fds stderr 3 && convert >&3 || report_and_convert
    }
}

report_and_convert ()
{
    say "convert a file: $INPUT" >&2
    convert >&3
    say "conversion completed" >&2
}

convert ()
{
    open_html
    add_title
    open_head
    add_style
    close_head
    open_body
    convert_md2html
    close_body
    close_html
}

open_html ()
{
    echo "\
<!DOCTYPE html>
<html lang=\"en\">"
}

add_title ()
{
    echo "<title>${PAGE_TITLE:-}</title>"
}

open_head ()
{
    echo "\
<head>
<meta charset=\"UTF-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
}

add_style ()
{
    is_empty "${PAGE_STYLE:-}" || {
        echo "<style>"
        cat "$PAGE_STYLE" || die "$STATUS"
        echo "</style>"
    }
}

close_head ()
{
    echo "</head>"
}

open_body ()
{
    echo "\
<body>
<article class=\"markdown-body\">"
}

close_body ()
{
    echo "\
</article>
</body>"
}

close_html ()
{
    echo "</html>"
}

convert_md2html ()
{

    STRING_NUM=0
    SAVE_STRING=
    STRING_BUFFER=

    MD_SAVE_INDENT=
    MD_EXCESS_INDENT=
    MD_INDENT_WIDTH=3
    TAG_INDENT_WIDTH=0
    STAR_TAG_INDENT="    "
    STAR_TAG_INDENT=""

    MAP_OPENING_TAG=()
    MAP_CLOSING_TAG=()
    OPENING_TAG_BUFFER=()
    CLOSING_TAG_BUFFER=()

    BLOCKQUOTE_IS_OPEN="no"
    CODE_BLOCK=

    ID_NUM=0
    declare -A ID_BASE

    while IFS= read -r STRING || is_not_empty "${STRING:-}"
    do
        ROW_NESTING_DEPTH=
        TAG_INDENT="${STAR_TAG_INDENT:-}"
        while :
        do
                get_string_indent ||
                add_to_code_block ||
                add_to_blockquote ||
                    print_heading ||
            print_horizontal_rule ||
                    add_to_buffer && read_string_again || break
        done
    done < "$INPUT"

    if is_equal "${CODE_BLOCK:-}" "open"
    then
        print_code_block
    else
        print_buffer
    fi
}

get_string_indent ()
{
    MD_INDENT="${STRING%%[![:blank:]]*}"
    STRING="${STRING#"${MD_INDENT:-}"}"

    is_not_empty "${STRING:-}" || {
        # is_equal "$BLOCKQUOTE_IS_OPEN" "no" && {
        #     add_to_code_block || print_buffer
        # } || {
        #     is_not_empty "${ROW_NESTING_DEPTH:-}" || {
        #         print_buffer
        #         BLOCKQUOTE_IS_OPEN="no"
        #     }
        # }

        add_to_code_block || {
            is_not_empty "${ROW_NESTING_DEPTH:-}" || {
                print_buffer
                BLOCKQUOTE_IS_OPEN="no"
            }
        }
        return
    }

    if is_equal "${INDENTED_CODE_BLOCK:-}" "open"
    then
        test "${#MD_INDENT}" -ge "$((MD_INDENT_WIDTH + 1))" &&
        STRING="${MD_INDENT#????}$STRING" || {
            print_code_block
            MD_EXCESS_INDENT="${MD_INDENT:-}"
        }
    elif is_equal "${CODE_BLOCK:-}" "open"
    then
        STRING="${MD_INDENT:"${#MD_EXCESS_INDENT}"}$STRING"
    elif test "${#MD_INDENT}" -ge "$((MD_INDENT_WIDTH + 1))"
    then
        is_empty "${STRING_BUFFER:-}" && {
            is_not_empty "${ROW_NESTING_DEPTH:-}" || print_buffer
            add_code_block_tag
            INDENTED_CODE_BLOCK="open"
            STRING="${MD_INDENT#????}$STRING"
        } || {
            add_to_buffer
            return
        }
    else
        MD_EXCESS_INDENT="${MD_INDENT:-}"
    fi
    return 1

    # MD_INDENT="$(printf "%$((${#MD_INDENT} ))s" '')"
    # # MD_INDENT="$(printf "%$((${#MD_INDENT} / MD_INDENT_WIDTH * MD_INDENT_WIDTH))s" '')"
    # test "${#MD_SAVE_INDENT}" -ge "${#MD_INDENT}" ||
    # MD_INDENT="$(printf "%$((${#MD_SAVE_INDENT} + MD_INDENT_WIDTH))s" '')"
}

masking_characters ()
{
    # |   |   extra    |   need    |
    # |---|------------|-----------|
    # | ` | \x06  [^F] | \x1d [^]] |
    # | [ | \x10  [^P] | \x1e [^^] |
    # | ] | \x11  [^Q] | \x0e [^N] |
    # | ( | \x13  [^S] | \x1c [^\] |
    # | ) | \x14  [^T] | \x0c [^L] |
    # |---|------------|-----------|
    # \[[^][)(]*]([[:blank:]]*[^][)([:blank:]]*[[:blank:]]*)
    sed '
        s/\\\\/\x02/g
        s/\\&/\x03/g
        s/&lt;/\x04/g
        s/&gt;/\x05/g
        s/\(&amp;\|&\)/\x03/g
        s/\\`/\x06/g
        s/\\_/\x07/g
        s/\\~/\x08/g
        s/\\\*/\x1a/g
        s/\\\[/\x10/g
        s/\\]/\x11/g
        s/\\!/\x12/g
        s/\\(/\x13/g
        s/\\)/\x14/g
        s/\$/\x15/g
        s/\//\x16/g
        s/"/\x17/g
        s/|/\x18/g
        s/%/\x19/g
        s/]$/\x11/g

        :masking_nested_links
        {
            s/\(\[[^][)(]*\)(\([^]]*\]\)/\1\x13\2/g
            s/\(\[[^][)(]*\))\([^]]*\]\)/\1\x14\2/g
            s/\(\[[^[]*\)\[\([^][)(]*\)]\([^[]*]([[:blank:]]*[^[:blank:]]*[[:blank:]]*)\)/\1\x10\2\x11\3/g
            s/\[\([^]]*\)]\([^][)(]*]([[:blank:]]*[^[:blank:]]*[[:blank:]]*)\)/\x10\1\x11\2/
            s/\(\[[^[]*\)(\([^][)(]*]([[:blank:]]*[^[:blank:]]*[[:blank:]]*)\)/\1\x13\2/
            s/\(\[[^[]*\))\([^][)(]*]([[:blank:]]*[^[:blank:]]*[[:blank:]]*)\)/\1\x14\2/

            s/\(\[[^][)(]*]([[:blank:]]*[^][)([:blank:]]*\)(\([^)[:blank:]]*\))\([^[:blank:]]*[[:blank:]]*)\)/\1\x13\2\x14\3/g
            s/\(\[[^][)(]*]([[:blank:]]*[^][)([:blank:]]*\)(\([^[:blank:]]*[[:blank:]]*)\)/\1\x13\2/
            s/\(\[[^][)(]*]([[:blank:]]*[^][)([:blank:]]*\)\[\([^[:blank:]]*[[:blank:]]*)\)/\1\x10\2/
            s/\(\[[^][)(]*]([[:blank:]]*[^][)([:blank:]]*\)]\([^[:blank:]]*[[:blank:]]*)\)/\1\x11\2/
        }
        t masking_nested_links

        s/\[\([^][)(]*\)](\([[:blank:]]*[^][)([:blank:]]*[[:blank:]]*\))/\x1e\1\x0e\x1c\2\x0c/g

        s/\[/\x10/g
        s/]/\x11/g
        s/(/\x13/g
        s/)/\x14/g
        s/\x1e/\[/g
        s/\x0e/]/g
        s/\x1c/(/g
        s/\x0c/)/g
        
        s/`\+/`/g

        :code
        {
            :href
            s/^\([^`]*\[[^][`]*]([^)`]*\)`\([^)]*)\)/\1\x06\2/
            t href
            s/^\([^`]*`[^`]*\)\[\([^`]*`\)/\1\x10\2/
            s/^\([^`]*`[^`]*\)]\([^`]*`\)/\1\x11\2/
            s/^\([^`]*`[^`]*\)(\([^`]*`\)/\1\x13\2/
            s/^\([^`]*`[^`]*\))\([^`]*`\)/\1\x14\2/
            s/^\([^`]*`[^`]*\)\*\([^`]*`\)/\1\x1a\2/
            s/^\([^`]*`[^`]*\)_\([^`]*`\)/\1\x07\2/
            s/^\([^`]*`[^`]*\)~\([^`]*`\)/\1\x08\2/
        }
        t code
        
        s/^\([^`]*\)`\([^`]*\)`/\1\x1d\2\x1d/
        t masking_nested_links

        s/`/\x06/g
        s/\x1d/`/g'
}

unmasking_characters ()
{
    sed 's/\x02/\\/g
         s/\x03/\&amp;/g
         s/\x04/\&lt;/g
         s/\x05/\&gt;/g
         s/\x06/`/g
         s/\x07/_/g
         s/\x08/~/g
         s/\x1a/*/g
         s/\x10/\[/g
         s/\x11/]/g
         s/\x12/!/g
         s/\x13/(/g
         s/\x14/)/g
         s/\x15/$/g
         s/\x16/\//g
         s/\x17/"/g
         s/\x18/|/g
         s/\x19/%/g
         s/\x01/<br>\n/g'
}

convert_href_link ()
{
    sed 's/\x02/%5C/g
         s/\x17/%22/g
         s/#/%23/g
         s/</%3C/g
         s/>/%3E/g
         s/?/%3F/g
         s/\x10/%5B/g
         s/\x11/%5D/g
         s/\^/%5E/g
         s/`/%60/g
         s/{/%7B/g
         s/}/%7D/g
         s/\x18/%7C/g
         s/\&/\\\&amp;/g
         s/\*/\x1a/g
         s/_/\x07/g
         s/~/\x08/g'
}

convert_name_link ()
{
    sed 's/\&/\\\&amp;/g
         s/</\\\&lt;/g
         s/>/\\\&gt;/g'
}

convert_alt_link ()
{
    sed 's/\&/\\\&amp;/g
         s/\x17/\\\&quot;/g
         s/\*/\x1a/g
         s/`/\x06/g
         s/_/\x07/g
         s/~/\x08/g'
}

create_img_link ()
{
    
    ALT_LINK="$(sed 's|\!\[\([^][]*\)]([[:blank:]]*[^)[:blank:]]*[[:blank:]]*)|\1|g' <<< "$LINK")"
    SRC_LINK="$(sed 's|\!\[[^][]*]([[:blank:]]*\([^)[:blank:]]*\)[[:blank:]]*)|\1|g' <<< "$LINK")"
    ALT_LINK="$(convert_alt_link  <<< "$ALT_LINK")"
    SRC_LINK="$(convert_href_link <<< "$SRC_LINK")"
    HTML_LINK="<img alt=\"$ALT_LINK\" src=\"$SRC_LINK\">"
}

create_a_link ()
{
    HREF_LINK="$(sed 's|\[[^][]*]([[:blank:]]*\([^)[:blank:]]*\)[[:blank:]]*)|\1|g' <<< "$LINK")"
    NAME_LINK="$(sed 's|\[\([^][]*\)]([[:blank:]]*[^)[:blank:]]*[[:blank:]]*)|\1|g' <<< "$LINK")"
    HREF_LINK="$(convert_href_link <<< "$HREF_LINK")"
    NAME_LINK="$(convert_name_link <<< "$NAME_LINK")"
    HTML_LINK="<a href=\"$HREF_LINK\">$NAME_LINK</a>"
}

print_link ()
{
    while IFS= read -r LINK || is_not_empty "${LINK:-}"
    do
        case "$LINK" in
            !*) create_img_link ;;
             *) create_a_link
        esac
        LINK="$(sed 's/\\//g; s/\*/\\*/g; s/\[/\\[/g' <<< "$LINK")"
        LINE="$(sed "s/\\\//g; s|$LINK|$HTML_LINK|" <<< "$LINE")"
    done < <(grep -o '!\?\[[^][]*]([[:blank:]]*[^()[:blank:]]*[[:blank:]]*)' <<< "$LINE")
    echo "$LINE"
}

print_text ()
{
    sed '
        : code
        /`/! b del_text
        /^[^`]*`\+[^`]*$/ b del_text

        #  line: [word `code 0` word]
        # match: (word )`(code 0)`( word)
        /^[^`]*\(`\{1,\}\)[^`].*[^`]\1\([^`]\|$\)/!{
            : unique_tildes

            #  line: [word ``\x1dcode `0]
            # match: (word `)`(\x1dcode )
            s%^\([^`]*`*\)`\(\x06\+[^`]*\)%\1\x1d\2%
            t unique_tildes

            #  line: [word ```code `0]
            # match: (word ``)`(code )
            s%^\([^`\x1d]*`*\)`\([^`]*\)%\1\x1d\2%
            t unique_tildes

            s%\x1d%\x06%g
            b code
        }

        #  line: [word `code 0` word]
        # match: (word )`(code 0)`( word)
        s%^\([^`]*\)\(`\{1,\}\)\([^`]\+\)\2\([^`]\|$\)%\1<code>\3</code>\4%
        t code

        #  line: [word`cat file0; `` `` word`cat file0`; ``` word]
        # match: (word)`(cat file0; `` `` word)`(c)
        s%^\([^`]*\)`\(\([^`]\+`\{2,\}\)\+[^`]\+\)`\([^`]\|$\)%\1\x1d\2\x1d\4%
        {
            : tildes_inside_single_tilde

            #  line: [\x1dcat file0; `` `` wordx1d ]
            # match: (\x1dcat file0; )`(` `` word\x1d )
            s%\(\x1d[^`\x1d]*\)`\([^\x1d]*\x1d\)%\1\x06\2%
            t tildes_inside_single_tilde

            s%\x1d%`%g
            t code
        }

        #  line: [word ```word`cat file0; ``` word`cat file0`; ``` word]
        # match: (word )```(word`cat file0; )```( )
        s%^\([^`]*\)\(`\{2,\}\)\(\([^`]\+`\+\)\+[^`]*[^`]\)\2\([^`]\|$\)%\1\x1d\3\x1d\5%
        {
            : tildes_inside_multi_tilde

            #  line: [\x1d word`cat file0; x1d ]
            # match: (\x1d word)`(cat file0; \x1d )
            s%\(\x1d[^`\x1d]*\)`\([^\x1d]*\x1d\)%\1\x06\2%
            t tildes_inside_multi_tilde

            s%\x1d%`%g
            t code
        }

        : del_text
        /~~/! b text
        
        #  line: [word~word~]
        # match: (word)~(word)~
        s%\(^\|[^~]\)~\([^~]\|$\)%\1\x08\2%g
        t del_text

        #  line: [word ~~ word]
        # match: (word )~~( )
        s%^\([^~]*[~\x08]*\)~\([~\x08]*[[:blank:]]\|$\)%\1\x08\2%
        t del_text

        #  line: [word ~~del-word~~]
        # match: (word )~~(del-word)~~
        s%\(^\|[^~]\)~~\([^~[:blank:]]\+[^~]*\)~~\([^~]\|$\)%\1<del>\2</del>\3%g
        t remove_triple_tildes

        #  line: [word ~~del-word~~~0~~ word]
        # match: (word ~~del-word)~~~(0)
        /^\([^~]*\(~~[^~[:blank:]]\)\?[^~]*\)~\{3,\}\([^~]\|$\)/{
            : remove_triple_tildes
            
            s%^\([^~]*\(~~[^~[:blank:]][^~]*\)\?\x08\)~%\1\x08%
            t remove_triple_tildes
            
            s%^\([^~]*\(~~[^~[:blank:]][^~]*\)\?\)~\(~~\+\)%\1\x08\3%
            t remove_triple_tildes
            b del_text
        }

        b exit

        /\*/! b exit

        : text

        #  line: [word ** word]
        # match: (word )**( )
        s%^\([^*]*[*\x1a]*\)\*\([*\x1a]*[[:blank:]]\|$\)%\1\x1a\2%
        t text

        #  line: [word ***bold 0** word]
        # match: (word **)*(bold 0** word)
        s%^\([^*]*\*\*\)\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\*\*[^*]*$\)%\1\x1a\2%
        t text

        #  line: [word ***bold 0** word]
        # match: (word *)**(bold 0* word)
        s%^\([^*]*\*\)\*\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\*[^*]*$\)%\1\x1a\2%
        t text

        #  line: [word *italic 0* word]
        # match: (word )*(italic 0)*( word)
        s%^\([^*]*\)\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\)\*\([^*]\|$\)%\1<em>\2</em>\3%
        t text

        #  line: [word **bold 0** word]
        # match: (word )**(bold 0)**
        s%^\([^*]*\)\*\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\)\*\*%\1<strong>\2</strong>%
        t text

        #  line: [word ***bold-italic 0*** word]
        # match: (word **)*(bold-italic 0)*(**) word
        s%^\([^*]*\*\*\)\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\)\*\(\*\*\)%\1<em>\2</em>\3%
        t text

        #  line: [***italic-bold 0** italic 0*]
        # match: (*)**(italic-bold 0)**( italic 0*)
        s%^\([^*]*\*\)\*\*\([^*[:blank:]]\+[^*]*\)\*\*\([^*]*\*\)%\1<strong>\2</strong>\3%
        t text

        #  line: [*italic 0 **italic-bold 0***]  | [*italic 0 **italic-bold 0** italic 1*]
        # match: (*italic 0 )**(italic-bold 0)**
        s%^\([^*]*\*[^*]*\)\*\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\)\*\*%\1<strong>\2</strong>%
        t text

        #  line: [**bold 0 *bold-italic 0* bold 1**] | [**bold 0 *bold-italic 0***]
        # match: (**bold 0 )*(bold-italic 0)*
        s%^\([^*]*\*\*[^*]*\)\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\)\*%\1<em>\2</em>%
        t text

        #  line: [word *italic 0 ***bold 0** word]
        # match: (word )*(italic 0 )*(**)
        s%^\([^*]*\)\*\([^*[:blank:]]\+[^*]*\)\*\(\*\*[^*].*\)%\1<em>\2</em>\3%
        t text

        #  line: [word **bold 0 **bold 1** word]
        # match: (word **bold 0 )**
        /^[^*]*\*\*[^*[:blank:]]*[^*]*[[:blank:]]\*\{1,\}.*[^*[:blank:]]\*\*\([^*]\|$\)/{
          : inside_bold_blank_asterisks
            s%^\([^*]*\*\*[^*[:blank:]]*[^*]*[[:blank:]][*\x1a]*\)\*%\1\x1a%
          t inside_bold_blank_asterisks
          b text
        }

        #  line: [word **bold 0* **bold 1** word]
        # match: (word **bold 0)*( )
        /^[^*]*\*\*[^*[:blank:]]*[^*]*[^*[:blank:]]\*[^*]*.*[^*[:blank:]]\*\*/{
          : inside_bold_star_blank
            s%^\([^*]*\*\*[^*[:blank:]]*[^*]*[^*[:blank:]]\)\*\([[:blank:]]\|$\)%\1\x1a\2%
          t inside_bold_star_blank
          b text
        }

        #  line: [word *italic 0 **** italic 1* word]
        # match: (word *italic 0 )****(i)
        /^[^*]*\*[^*[:blank:]]*[^*]*[[:blank:]]\*\+.*[^*[:blank:]]\*\([^*]\|$\)/{
          : inside_italics_asterisks_end
            s%^\([^*]*\*[^*[:blank:]]*[^*]*[[:blank:]][*\x1a]*\)\*\([^*]\|$\)%\1\x1a\2%
          t inside_italics_asterisks_end
          b text
        }

        #  line: [**italic 0* word **]
        # match: (*)*(italic 0* )
        /^[^*]*\*\*[^*[:blank:]]*[^*]*[^*[:blank:]]\*\([[:blank:]]\|$\)/{
          : inside_italics_asterisks_start
          s%^\([^*]*\*\)\*\([^*[:blank:]]*[^*]*[^*[:blank:]]\*\([[:blank:]]\|$\)\)%\1\x1a\2%
          t inside_italics_asterisks_start
          b text
        }

        #  line: [word *italic 0** italic 1* word]
        # match: (word *italic 0)**( italic 1*)
        /^[^*]*\*[^*[:blank:]]*[^*]*[^*[:blank:]]\(\*\{2\}\|\*\{4,\}\).*[^*[:blank:]]\*[^*]*/{
          : inside_italics_asterisks
          s%^\([^*]*\*[^*[:blank:]]*[^*]*[^[:blank:]]\)\*\([^*]\)%\1\x1a\2%
          t inside_italics_asterisks
          b text
        }

        #  line: [word *italic 0 * word]
        # match: (word )*(italic 0 )*( word)
        s%^\([^*]*\)\*\([^*[:blank:]]\+[^*]*\)\*\([^*]\+\|$\)%\1<em>\2</em>\3%
        t text

        #  line: [word *italic 0 **** word]
        # match: (word *italic 0 ***)*( word)
        s%^\([^*]*\)\*\([^*[:blank:]]\+[^*]*\*\{2,\}\)\*\([^*]*$\)%\1<em>\2</em>\3%
        t text

        s/\x1a/*/g

        : exit

        s/\x06/`/g
        s/\x08/~/g
        '
}

wrap_text_with_tags ()
{
    masking_characters | while IFS= read -r LINE || is_not_empty "${LINE:-}"
    do
        print_link | print_text
    done | unmasking_characters
}

format_string ()
{
    STRING="$(wrap_text_with_tags <<< "${STRING//$NEW_LINE/$MASK_NEW_LINE}")"
}

is_code_block ()
{
    [[ "${STRING:-}" =~ ^([[:blank:]]{3})*\`{3}([[:blank:]]+)*$ ]]
}

is_code_block_with_lang ()
{
    [[ "${STRING:-}" =~ ^\`{3}([^\`]|[[:blank:]]+).+$ ]]
}

close_code_block ()
{
    is_code_block && print_code_block
}

add_to_code_block ()
{
    if is_equal "${CODE_BLOCK:-}" "open"
    then
        is_equal "${INDENTED_CODE_BLOCK:-}" "closed" &&
        close_code_block ||
        STRING_BUFFER="${STRING_BUFFER:+"$STRING_BUFFER$NEW_LINE"}${STRING:-}"
    else
        is_code_block || {
            is_code_block_with_lang && {
                CURRENT_CODE_LANG="$(
                    sed 's/^[`[:blank:]]\+\(.\+\)$/\1/g
                         s/[[:blank:]]\+$//g
                         s/[[:blank:]]/-/g
                         s/[^a-zA-Z0-9_-]//g
                         s/-\+/-/g' <<< "$STRING"
                )"
                CURRENT_CODE_LANG="${CURRENT_CODE_LANG,,}"
            }
        } && {
            is_empty "${STRING_BUFFER:-}" || print_buffer
            add_code_block_tag
        }
    fi
}

add_code_block_tag ()
{
    get_tag code-block
    add_tag_to_a_tag_map
    CODE_BLOCK="open"
}

print_code_block ()
{
    print_buffer 1
    CODE_BLOCK="closed"
    INDENTED_CODE_BLOCK="closed"
}

add_to_blockquote ()
{
    [[ "$STRING" =~ ^\>[[:blank:]]+ ]] && STRING="${STRING#??}" || {
                [[ "$STRING" =~ ^\> ]] && STRING="${STRING#?}"  || return
    }
    BLOCKQUOTE_IS_OPEN="yes"

    get_tag blockquote
    add_tag_to_the_buffer
    ROW_NESTING_DEPTH="$((${ROW_NESTING_DEPTH:--1} + 1))"
    is_equal "${#MAP_CLOSING_TAG[@]}" 0 || is_empty  "${MAP_CLOSING_TAG[$ROW_NESTING_DEPTH]:-}" && {
        is_empty "${STRING_BUFFER:-}"   || {
            print_buffer 0
            # exit
        }
    } || {
        if is_equal "${MAP_CLOSING_TAG[$ROW_NESTING_DEPTH]}" "$CLOSING_TAG"
        then
            # блок для переноса строки c нижнего на текущий уровень
            [[ "$STRING" =~ ^\> ]] || {
                if is_equal "${MAP_CLOSING_TAG[$((ROW_NESTING_DEPTH + 1))]:-}" "$CLOSING_TAG"
                then
                    print_buffer "$((${#MAP_CLOSING_TAG[@]} - $((ROW_NESTING_DEPTH + 1))))"
                fi
            }
            READ_STRING_AGAIN="yes"
            OPENING_TAG_BUFFER=()
            CLOSING_TAG_BUFFER=()
            return
        fi
    }

    add_tag_to_a_tag_map
    READ_STRING_AGAIN="yes"
}

print_heading ()
{
    if [[ "${STRING:-}" =~ ^#{1,6}([[:blank:]].*|$) ]]
    then
        HEADER="${STRING%%[[:blank:]]*}"
        STRING="${STRING#"$HEADER"}"
        TAG="h${#HEADER}"
        TAG_CLASS="atx"
    elif [[ "${STRING:-}" =~ ^=+$ ]]
    then
        is_not_empty "${STRING_BUFFER:-}"   &&
        is_equal "$BLOCKQUOTE_IS_OPEN" "no" || return
        STRING="$STRING_BUFFER" STRING_BUFFER=
        TAG=h1
        TAG_CLASS="setext"
    elif [[ "${STRING:-}" =~ ^-+$ ]]
    then
        is_not_empty "${STRING_BUFFER:-}"   &&
        is_equal "$BLOCKQUOTE_IS_OPEN" "no" || return
        STRING="$STRING_BUFFER" STRING_BUFFER=
        TAG=h2
        TAG_CLASS="setext"
    else
        false
    fi && {
        trim_white_space
        format_string
        get_tag "$TAG"
        STRING="${TAG_INDENT:-}$OPENING_TAG$STRING$CLOSING_TAG"
        print_buffer
        echo -n "$STRING"
    }
}

print_horizontal_rule ()
{
    [[ "$(tr -d '[:blank:]' <<< "${STRING:-}")" =~ ^(-{3,}|_{3,}|\*{3,})$ ]] && {
        get_tag hr
        STRING="${TAG_INDENT:-}$OPENING_TAG$NEW_LINE"
        is_empty "${ROW_NESTING_DEPTH:-}" &&
        print_buffer ||
        print_buffer 0
        echo -n "$STRING"
    }
}

add_to_buffer ()
{
    is_empty "${STRING_BUFFER:-}" && {
        is_empty  "${!MAP_CLOSING_TAG_INDENT[@]}" ||
        TAG_INDENT="${MAP_CLOSING_TAG_INDENT[-1]}"
        get_tag_indent +
        BUFFER_INDENT="${TAG_INDENT:-}"
        STRING_BUFFER="${MD_INDENT:-}$STRING"
    } || {
        STRING_BUFFER="$STRING_BUFFER$NEW_LINE${BUFFER_INDENT:-}${MD_INDENT:-}$STRING"
    }
    STRING=
}

print_buffer ()
{
    SAVE_STRING="${STRING:-}"   STRING=
    STRING="${STRING_BUFFER:-}" STRING_BUFFER=
    STRING="${STRING%"${STRING##*[!"$NEW_LINE"]}"}"
    add_an_open_tag
    add_a_closed_tag "${1:-}"
    echo -n "${STRING:-}"
    STRING="${SAVE_STRING:-}"   SAVE_STRING=
}

add_an_open_tag ()
{
    TAG=
    # for i in "${MAP_OPENING_TAG[@]}"
    # do
    #     TAG="${TAG:-}$i"
    # done
    for i in "${!MAP_OPENING_TAG[@]}"
    do
        TAG="${TAG:-}${MAP_OPENING_TAG_INDENT[$i]:-}${MAP_OPENING_TAG[$i]}"
    done
    add_tag_p
    STRING="${TAG:-}${STRING:-}"
    MAP_OPENING_TAG_INDENT=()
    MAP_OPENING_TAG=()
}

add_a_closed_tag ()
{
    is_diff "${#MAP_CLOSING_TAG[@]}" 0 || return 0

    

    if is_not_empty "${1:-}"
    then
        is_diff "$1" 0 || return 0

        SHIFT="$1"
        TAG=
        # for i in $(seq 1 $SHIFT)
        # do
        #     TAG="${TAG:-}${MAP_CLOSING_TAG[-1]}"
        #     unset -v "MAP_CLOSING_TAG[-1]"
        # done
        for i in $(seq 1 $SHIFT)
        do
            TAG="${TAG:-}${MAP_CLOSING_TAG_INDENT[-1]:-}${MAP_CLOSING_TAG[-1]}"
            unset -v "MAP_CLOSING_TAG[-1]" "MAP_CLOSING_TAG_INDENT[-1]"
        done
        # ROW_NESTING_DEPTH="$((ROW_NESTING_DEPTH-SHIFT))"
        # TAG_INDENT="${TAG_INDENT%"$(printf "%$((TAG_INDENT_WIDTH*SHIFT+2))s" '')"}"
    else
        TAG=
        # for i in "${MAP_CLOSING_TAG[@]}"
        # do
        #     TAG="$i${TAG:-}"
        # done
        for i in "${!MAP_CLOSING_TAG[@]}"
        do
            TAG="${MAP_CLOSING_TAG_INDENT[$i]:-}${MAP_CLOSING_TAG[$i]}${TAG:-}"
        done
        MAP_CLOSING_TAG_INDENT=()
        MAP_CLOSING_TAG=()
        # ROW_NESTING_DEPTH=
        TAG_INDENT="${STAR_TAG_INDENT:-}"
    fi
    STRING="${STRING:-}${TAG:-}"
}

read_string_again ()
{
    is_empty "${ROW_NESTING_DEPTH:-}" || {
        TOTAL_NESTING_DEPTH="$ROW_NESTING_DEPTH"
        # ROW_NESTING_DEPTH=
    }
    is_equal "${READ_STRING_AGAIN:="no"}" "yes" && READ_STRING_AGAIN="no"
}

trim_leading_white_space ()
{
    STRING="${STRING#"${STRING%%[![:blank:]]*}"}"
}

trim_trailing_white_space ()
{
    STRING="${STRING%"${STRING##*[![:blank:]]}"}"
}

trim_white_space ()
{
    trim_leading_white_space
    trim_trailing_white_space
}

get_tag_indent ()
{
    case "$1" in
        -) TAG_INDENT="$(printf "%$((${#TAG_INDENT} - ${2:-"${TAG_INDENT_WIDTH:=2}"}))s" '')" ;;
        +) TAG_INDENT="$(printf "%$((${#TAG_INDENT} + ${2:-"${TAG_INDENT_WIDTH:=2}"}))s" '')" ;;
    esac
}

get_tag ()
{
    case "$1" in
        code-block)
            get_tag_indent +
            OPENING_TAG="<pre><code class=\"${CURRENT_CODE_LANG:+fenced-code-block language-}${CURRENT_CODE_LANG:-indented-$1}\">"
            CLOSING_TAG="</code></pre>$NEW_LINE"
            CURRENT_CODE_LANG=
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT=""
            ;;
        blockquote|li|ul)
            get_tag_indent +
            OPENING_TAG="<$1>$NEW_LINE"
            CLOSING_TAG="</$1>$NEW_LINE"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
            ;;
        ol)
            get_tag_indent +
            is_not_empty "${OL_START:-}" &&
            TAG="<$1 start="$OL_START">" ||
            TAG="<$1>"
            OPENING_TAG="$TAG$NEW_LINE"
            CLOSING_TAG="$TAG$NEW_LINE"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
            ;;
        h[1-6])
            get_tag_indent +
            ID="${STRING,,}"
            ID="${ID//"$NEW_LINE"/-}"
            ID="$(sed 's/\(<br>\|[[:blank:]]\)/-/g
                       s/[^a-zA-Z0-9_-]//g
                       s/-\+/-/g
                       s/\(^-\+\|-\+$\)//g' <<< "${ID:-}")"
            is_empty "${ID:-}" || {
                is_empty "${ID_BASE["$ID"]:-}" || ID="$ID-$((ID_NUM+1))"
                ID_BASE["$ID"]="$ID"
            }
            OPENING_TAG="<$1 class=\"${TAG_CLASS:-atx}\" id=\"${ID:-}\">"
            CLOSING_TAG="</$1>$NEW_LINE"
            TAG_CLASS=
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT=""
            ;;
        hr)
            get_tag_indent +
            OPENING_TAG="<$1>"
            CLOSING_TAG="</$1>$NEW_LINE"
            ;;
        p)
            OPENING_TAG="<$1>"
            CLOSING_TAG="</$1>$NEW_LINE"
            ;;
    esac
}

add_tag_p ()
{
    is_empty "${STRING:-}" || {
        # STRING="$(format_string <<< "${STRING//$NEW_LINE/$MASK_NEW_LINE}")"
        format_string
        if is_diff "${#MAP_CLOSING_TAG[@]}" 0
        then
            if [[ "${MAP_CLOSING_TAG[-1]}" =~ ^[[:blank:]]*\</blockquote\>"$NEW_LINE" ]]
            then
                get_tag p
                STRING="${BUFFER_INDENT:-}$OPENING_TAG$STRING$CLOSING_TAG"
            fi
        else
            get_tag p
            STRING="${BUFFER_INDENT:-}$OPENING_TAG$STRING$CLOSING_TAG"
        fi
        BUFFER_INDENT=
    }
}

add_tag_to_the_buffer ()
{
    OPENING_TAG_BUFFER=( "${OPENING_TAG_BUFFER[@]}" "$OPENING_TAG" )
    CLOSING_TAG_BUFFER=( "${CLOSING_TAG_BUFFER[@]}" "$CLOSING_TAG" )
}

add_tag_to_a_tag_map ()
{
    MAP_OPENING_TAG_INDENT=( "${MAP_OPENING_TAG_INDENT[@]}" "${OPENING_TAG_INDENT:-}" )
    MAP_CLOSING_TAG_INDENT=( "${MAP_CLOSING_TAG_INDENT[@]}" "${CLOSING_TAG_INDENT:-}" )

    MAP_OPENING_TAG=( "${MAP_OPENING_TAG[@]}" "${OPENING_TAG_BUFFER[@]:-"$OPENING_TAG"}" )
    MAP_CLOSING_TAG=( "${MAP_CLOSING_TAG[@]}" "${CLOSING_TAG_BUFFER[@]:-"$CLOSING_TAG"}" )

    OPENING_TAG_BUFFER=() OPENING_TAG=
    CLOSING_TAG_BUFFER=() CLOSING_TAG=
}

arg_is_not_empty ()
{
    RETURN=0
    case "$1" in
        *=)
            case "${2:-}" in
                "")
                    false
            esac
            ;;
        *)
            case "${2:-}" in
                ""|-[$SHORT_OPTIONS]*)
                    false
                    ;;
                *)
                    for i in $LONG_OPTIONS
                    do
                        case $2 in
                            "--$i"|"--$i="*|"$i"|"$i="*)
                                RETURN=1
                                break
                        esac
                    done
                    is_equal "$RETURN" 0
            esac 
    esac || {
        is_equal "${#1}" 2 &&
        try 2 "option requires an argument -- '${1#?}'" ||
        try 2 "option '$1' requires an argument"
    }
}

argparse ()
{
    PARSE_OPTIONS="yes"
    SHORT_OPTIONS="?hvfiost"
     LONG_OPTIONS="help version force input output style title"
    ARGS=()
    while is_diff $# 0
    do
        is_equal "$PARSE_OPTIONS" "yes" &&
        case "${1:-}" in
            "")
                ;;
            --)
                shift
                PARSE_OPTIONS="no"
                ;;
            -[?h]|--help)
                HELP="$1"
                ;;
            -[?h]*)
                HELP="${1%"${1#??}"}"
                ARG="-${1#??}"
                shift
                set -- '' "$ARG" "$@"
                ;;
            -v|--version)
                VERSION="$1"
                ;;
            -v*)
                VERSION="${1%"${1#??}"}"
                ARG="-${1#??}"
                shift
                set -- '' "$ARG" "$@"
                ;;
            -f|--force)
                FORCE="$1"
                ;;
            -f*)
                FORCE="${1%"${1#??}"}"
                ARG="-${1#??}"
                shift
                set -- '' "$ARG" "$@"
                ;;
            -i|--input)
                arg_is_not_empty "$1" "${2:-}"
                INPUT="$2"
                shift
                ;;
            -i=?*|--input=?*)
                arg_is_not_empty "${1%%=*}=" "${1#*=}"
                INPUT="${1#*=}"
                ;;
            -i*)
                INPUT="${1#??}"
                ;;
            -o|--output)
                arg_is_not_empty "$1" "${2:-}"
                OUTPUT="$2"
                shift
                ;;
            -o=*|--output=*)
                arg_is_not_empty "${1%%=*}=" "${1#*=}"
                OUTPUT="${1#*=}"
                ;;
            -o*)
                OUTPUT="${1#??}"
                ;;
            -s|--style)
                arg_is_not_empty "$1" "${2:-}"
                PAGE_STYLE="$2"
                shift
                ;;
            -s=*|--style=*)
                arg_is_not_empty "${1%%=*}=" "${1#*=}"
                PAGE_STYLE="${1#*=}"
                ;;
            -s*)
                PAGE_STYLE="${1#??}"
                ;;
            -t|--title)
                arg_is_not_empty "$1" "${2:-}"
                PAGE_TITLE="$2"
                shift
                ;;
            -t=*|--title=*)
                arg_is_not_empty "${1%%=*}=" "${1#*=}"
                PAGE_TITLE="${1#*=}"
                ;;
            -t*)
                PAGE_TITLE="${1#??}"
                ;;
            -|--*)
                try 2 "unknow option: '$1'"
                ;;
            -*)
                ARG="${1%"${1#??}"}"
                try 2 "unknow option: '${ARG#?}'"
                ;;
            *)
                false
        esac || ARGS+=( "$1" )
        shift
    done

    is_equal "${#ARGS[@]}" 0 || {
        set -- "${ARGS[@]}"
        while is_diff $# 0
        do
            if is_empty "${INPUT:-}"
            then
                INPUT="$1"
            elif is_empty "${OUTPUT:-}"
            then
                OUTPUT="$1"
            else
                try 2 "unknow argument: '$1'"
            fi
            shift
        done
    }
}

check_args ()
{
    is_empty "${PAGE_STYLE:-}" || {
        is_file "$PAGE_STYLE" || {
            is_file "$PKG_DIR/style/${PAGE_STYLE%.css}.css" &&
            PAGE_STYLE="$PKG_DIR/style/${PAGE_STYLE%.css}.css"
        } || die 2 "no such file: -- '$PAGE_STYLE'"
    }

    is_not_empty "${INPUT:-}" || try 2 "input file not specified"
    is_file       "$INPUT"    || die 2 "no such file: -- '$INPUT'"
    INPUT="$(readlink -e -- "$INPUT" 2>&1)" || die "$INPUT"

    is_empty "${OUTPUT:-}" || {
        if is_exists "$OUTPUT"
        then
            is_file "$OUTPUT" || {
                is_dir "$OUTPUT" &&
                OUTPUT="$(sed 's|\.[mM][dD]$||g' <<< "$OUTPUT/${INPUT##*/}").html" ||
                    die 2 "is not a file/directory: -- '$OUTPUT'"
                is_file "$OUTPUT" || {
                    is_exists "$OUTPUT" &&
                        die 2 "exists, but it is not a file: -- '$OUTPUT'"
                }
            } && {
                is_not_empty "${FORCE:-}" || {
                    say "file '$OUTPUT' exists," >&2
                    request " overwrite it (y/N): " >&2 || die 0 'сanceled'
                }
            } || :
            OUTPUT="$(readlink -m -- "$OUTPUT" 2>&1)"
            is_diff "$INPUT" "$OUTPUT" || die 2 "input and output file match"
        else
            OUTPUT="$(readlink -m -- "$OUTPUT" 2>&1)"
            is_diff "$INPUT" "$OUTPUT" || die 2 "input and output file match"
            BASEDIR="${OUTPUT%/*}"
            STATUS="$(mkdir -vp -- "${BASEDIR:-/}" 2>&1)" && say "$STATUS" ||
                die "$STATUS"
        fi
        STATUS="$(touch "$OUTPUT" 2>&1)" || die "$STATUS"
    }
}

main "$@"
