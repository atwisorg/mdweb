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
  -c, --only-content        convert markdown without opening an html document
  -f, --force               do not prompt before overwriting
  -i, --input=FILE          specify the path to the file for tagging the code
  -o, --output=<path>       specify the path to save
  -p, --canonical-pre-code  move the tag '</code></pre>' to a new line
  -s, --style=<style>       specify the style of the HTML page
  -t, --title=<title>       specify the HTML page title
  -v, --version             display version information and exit
  -h, -?, --help            display this help and exit

An argument of '--' disables further option processing
When FILE is '-', read standard input. Standard input takes priority over the
input file.

Report bugs to: bug-$PKG@atwis.org
$PKG home page: <https://www.atwis.org/shell-script/$PKG/>"
    die
}

show_version ()
{
    echo "${0##*/} ${1:-0.4.2} - (C) 23.07.2025

Written by Mironov A Semyon
Site       www.atwis.org
Email      info@atwis.org"
    die
}

try ()
{
    say "$@" >&2
    echo "Try '$PKG --help' for more information." >&2
    exit "$RETURN"
}

say ()
{
    RETURN="$?"
    SAVE_ONE_LINE="${ONE_LINE:-}" ONE_LINE=
    while is_diff $# 0
    do
        case "${1:-}" in
            -n)
                ONE_LINE="-n"
                ;;
            *[!0-9]*|"")
                break
                ;;
            *)
                RETURN="$1"
        esac
        shift
    done
    case "$@" in
        ?*)
            echo ${ONE_LINE:-} "$PKG:${FUNC_NAME:+" $FUNC_NAME:"}${1:+" $@"}"
    esac
    ONE_LINE="${SAVE_ONE_LINE:-}" SAVE_ONE_LINE=
}

die ()
{
    say "$@" >&2
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
        0|stdin)
            echo 0 ;;
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
    SHORT_OPTIONS="?hvcfiost"
     LONG_OPTIONS="help version only-content force input output style title"
    STDIN="terminal"
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
            -c|--only-content)
                ONLY_CONTENT="$1"
                ;;
            -c*)
                ONLY_CONTENT="${1%"${1#??}"}"
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
            -p|--canonical-pre-code)
                CANONICAL_PRE_CODE="$1"
                ;;
            -p*)
                CANONICAL_PRE_CODE="${1%"${1#??}"}"
                ARG="-${1#??}"
                shift
                set -- '' "$ARG" "$@"
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
            -)
                STDIN="pipeline"
                ;;
            --*)
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

    is_terminal stdin || STDIN="pipeline"

    is_equal  "${#ARGS[@]}" 0 || {
        set -- "${ARGS[@]}"
        is_equal "$STDIN" "terminal" &&
        while is_diff $# 0
        do
            is_empty  "${INPUT:-}" &&  INPUT="$1" || {
            is_empty "${OUTPUT:-}" && OUTPUT="$1"
            } || try 2 "unknow argument: '$1'"
            shift
        done ||
        while is_diff $# 0
        do
            is_empty "${OUTPUT:-}" && OUTPUT="$1" ||
            try 2 "unknow argument: '$1'"
            shift
        done
    }
}

check_args ()
{
    is_empty "${PAGE_STYLE:-}" && {
        GET_CODE_BLOCK_TAG="get_code_block_tag"
        GET_HEADING_TAG="get_heading_tag"
    } || {
        is_file "$PAGE_STYLE" || {
            is_file "$PKG_DIR/style/${PAGE_STYLE%.css}.css" &&
            PAGE_STYLE="$PKG_DIR/style/${PAGE_STYLE%.css}.css"
        } || die 2 "no such file: -- '$PAGE_STYLE'"
        GET_CODE_BLOCK_TAG="get_code_block_tag_with_class"
        GET_HEADING_TAG="get_heading_tag_with_class"
    }

    is_equal "$STDIN" "pipeline"  && INPUT= || {
        is_not_empty "${INPUT:-}" || try 2 "input file not specified"
        is_file       "$INPUT"    || die 2 "no such file: -- '$INPUT'"
        INPUT="$(readlink -e -- "$INPUT" 2>&1)" || die "$INPUT"
        is_diff "$INPUT" "$PKG_PATH" || try 2 "i can't be an input file: -- '$INPUT'"
    }

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
                OUTPUT="$(readlink -m -- "$OUTPUT" 2>&1)"
                is_diff "$OUTPUT" "$PKG_PATH"  || try 2 "i can't be an output file: -- '$OUTPUT'"
                is_diff "${INPUT:-}" "$OUTPUT" || die 2 "input and output file match"
                is_not_empty "${FORCE:-}" || {
                    if is_terminal stdin
                    then
                        request "output file '$OUTPUT' exists, overwrite it (y/N): " ||
                        die 0 'сanceled'
                    else
                        say "output file exists: -- '$OUTPUT'"
                        try "add the '--force' option to overwrite the file"
                    fi
                } >&2
            } || :
        else
            is_diff "${INPUT:-}" "$OUTPUT" || die 2 "input and output file match"
            BASEDIR="${OUTPUT%/*}"
            STATUS="$(mkdir -vp -- "${BASEDIR:-/}" 2>&1)" && say "$STATUS" ||
            die "$STATUS"
        fi
        STATUS="$(touch "$OUTPUT" 2>&1)" || die "$STATUS"
    }
}

add_paragraph_to_list_item ()
{
    #         example         | input          |  output   |
    #-------------------------|----------------|-----------|
    # - foo                   | <ul>      skip | <ul>      |
    #        < - empty string | <li>\x18  skip | <li>\x18  |
    #   bar                   | foo\x01\x01bar | <p>\x18   |
    #-------------------------| </li>\x19 skip | \x1ffoo   |
    #                         | </ul>     skip | </p>\x19  |
    #                         |----------------| <p>\x18   |
    #                                          | \x1fbar   |
    #                                          | </p>\x19  |
    #                                          | </li>\x19 |
    #                                          | </ul>     |
    #                                          |-----------|

    sed '
        # (^_|\x1f|\037) MARKER_FORMAT_STRING first in the buffer string
        /^\x1f/!{
            # skip the created html tag and code
            b end_of_line
        }

        : remove_empty_line
        s%\x01*\x1a\+\x01*%\x1a%g

        # add a break tag marker
        s%\( \{2,\}\|\\\)\x01%\x7f%g

        # trim the white space at the end of each paragraph string
        s%[[:blank:]]\+\x01%\x01%g

        # trim the white space at the beginning of each paragraph string
        s%\x01[[:blank:]]\+%\x01%g

        # if the list (<li>) contains an empty string,
        # add a paragraph tag
        /\x1a/ {
            s%[[:blank:]]*\(\x1a\)%\1%g
            s%\x1a\(\x1f\)\?$%\1%
            s%^\(.*\)$%<p>\x18\n\1\n\x19</p>%
            s%\x1a%\n\x19</p>\n<p>\x18\n\x1f%g
        }
        : end_of_line
    '
}

format_string ()
{
    # 1. search for single-line code
    #    1. masking escaped control characters before single-line code
    #    2. mask backslashes and control characters in code
    #    3. recognize single-line code and insert tags
    # 2. search for links
    #    1. control character masking map
    #       |   |   extra    |   need    |
    #       |---|------------|-----------|
    #       | ` | \x07  [^G] | \x1d [^]] |
    #       | [ | \x11  [^Q] | \x1e [^^] |
    #       | ] | \x12  [^R] | \x0e [^N] |
    #       | ( | \x14  [^T] | \x1c [^\] |
    #       | ) | \x15  [^U] | \x0c [^L] |
    #       |---|------------|-----------|
    #       [[^][)(]*]([[:blank:]]*[^][)([:blank:]]*[[:blank:]]*)

    sed '
        # (^_|\x1f|\037) MARKER_FORMAT_STRING first in the buffer string
        /^\x1f/!{
            # skip the created html tag and code
            b end_of_line
        }

        # delete MARKER_FORMAT_STRING
        s%^\x1f%%
        b add_tag_code

        : mask_escaped_characters
        s%\\\\%\x02%g
        s%\\&%\x03%g
        /[<>]/ {
            s%\\<%\&lt;%g
            s%\\>%\&gt;%g
            : mask_html_tags
            {
                s%^\([^<>]*\)>%\1\&gt;%
                s%^\([^<>]*\)<\([^<>]*<\)%\1\&lt;\2%
                s%^\([^<>]*\)<\([^<>]\+\)>%\1\x04\2\x05%
            }
            t mask_html_tags
            s%\x04%<%g
            s%\x05%>%g
        }
        s%&lt;%\x04%g
        s%&gt;%\x05%g
        s%\(&\|&amp;\)%\x03%g
        s%\\\*%\x06%g
        s%\\`%\x07%g
        s%\\_%\x08%g
        s%\\~%\x10%g
        s%\\\[%\x11%g
        s%\\]%\x12%g
        s%\\!%\x13%g
        s%\\(%\x14%g
        s%\\)%\x15%g
        s%\\#%\x16%g
        s%\\|%\x17%g
        s%\\\([\x27"$%+,./:;=?@^{}-]\)%\1%g

        b mask_acute

        # preliminary check to see if there are any
        # hints of a single-line code;
        # string: [word ` code ` word]
        : add_tag_code
        /^[^[`]*`\+[^`]*`/! {
            # since no single-line code was found,
            # it is safe to mask out all escaped control characters;
            t mask_escaped_characters

            # if no one-line code is found,
            # mask acute before possible links;
            # string: [word ` word [ word]
            : mask_acute
            /^[^[`]*`[^[]*\[/ {
                # match : (word )`(word [)
                : mask_first_acute
                s%^\([^[`]*\)`\([^[]*\[\)%\1\06\2%
                t mask_first_acute
            }
            b add_tag_link
        }

        # string: [word `code 0` word]
        # match : (word )`(code 0)`( word)
        /^[^`]*\(`\{1,\}\)[^`].*[^`]\1\([^`]\|$\)/! {
            : masking_the_first_non-paired_acute
            {
                # string: [word ``\x1dcode `0]
                # match : (word `)`(\x1dcode )
                s%^\([^`]*`*\)`\(\x07\+[^`]*\)%\1\x1d\2%

                # string: [word ```code `0]
                # match : (word ``)`(code )
                s%^\([^`\x1d]*`*\)`\([^`]*\)%\1\x1d\2%
            }
            t masking_the_first_non-paired_acute

            s%\x1d%\x07%g
            b add_tag_code
        }

        # string: [word `code 0` word]
        # match : (word )`(code 0)`( word)
        /^\([^`]*\)\(`\{1,\}\)\([^`]\+\)\2\([^`]\|$\)/ {

            # mask characters in code: []()*_~
            : mask_characters_nested_in_code
            {
                s%^\([^`]*`[^`]*\)\[\([^`]*`\)%\1\x11\2%
                s%^\([^`]*`[^`]*\)]\([^`]*`\)%\1\x12\2%
                s%^\([^`]*`[^`]*\)(\([^`]*`\)%\1\x14\2%
                s%^\([^`]*`[^`]*\))\([^`]*`\)%\1\x15\2%
                s%^\([^`]*`[^`]*\)\*\([^`]*`\)%\1\x06\2%
                s%^\([^`]*`[^`]*\)_\([^`]*`\)%\1\x08\2%
                s%^\([^`]*`[^`]*\)~\([^`]*`\)%\1\x10\2%
            }
            t mask_characters_nested_in_code
        }

        # string: [word `` code 0 `` word]
        # match : (word )`` (code 0) ``( word)
        s%^\([^`]*\)\(`\{1,\}\)\( \?\)\([^`]\+\)\3\2\([^`]\|$\)%\1<code>\4</code>\5%
        t add_tag_code

        # string: [word`cat file0; `` `` word`cat file0`; ``` word]
        # match : (word)`(cat file0; `` `` word)`(c)
        s%^\([^`]*\)`\(\([^`]\+`\{2,\}\)\+[^`]\+\)`\([^`]\|$\)%\1\x1d\2\x1d\4%
        {
            # string: [\x1dcat file0; `` `` wordx1d ]
            # match : (\x1dcat file0; )`(` `` word\x1d )

            : masking_nested_acute_in_a_single_pair
            s%\(\x1d[^`\x1d]*\)`\([^\x1d]*\x1d\)%\1\x07\2%
            t masking_nested_acute_in_a_single_pair

            s%\x1d%`%g
            t add_tag_code
        }

        # string: [word ```word`cat file0; ``` word`cat file0`; ``` word]
        # match : (word )```(word`cat file0; )```( )
        s%^\([^`]*\)\(`\{2,\}\)\(\([^`]\+`\+\)\+[^`]*[^`]\)\2\([^`]\|$\)%\1\x1d\3\x1d\5%
        {
            # string: [\x1d word`cat file0; x1d ]
            # match : (\x1d word)`(cat file0; \x1d )

            : masking_nested_acute_in_multipare
            s%\(\x1d[^`\x1d]*\)`\([^\x1d]*\x1d\)%\1\x07\2%
            t masking_nested_acute_in_multipare

            s%\x1d%`%g
            t add_tag_code
        }

        : add_tag_link
        /^[^[`]*\[.*]([^)]*)/! {
            /^[^[`]*\[[^`]*`/ {
                : mask_first_square_bracket
                s%^\([^[`]*\)\[\([^`]*`\)%\1\x11%
                t mask_first_square_bracket
                b add_tag_code
            }
            b add_tag_del
        }

        : mask_nested_links
        {
            # string: word [name (link)] word
            # match : {word [name }({link)]}
            s%^\([^[`]*\[[^][)(]*\)(\([^]]*\]\)%\1\x14\2%

            # string: word [name \x14link)] word
            # match : {word [name \x14link}){]}
            s%^\([^[`]*\[[^][)(]*\))\([^]]*\]\)%\1\x15\2%

            # string: word [name [subname](sublink)](link)
            # match : {word [name }[{subname}]{(sublink)](link)}
            s%^\([^`]*\[[^[]*\)\[\([^][)(]*\)]\([^[]*]([[:blank:]]*[^[:blank:]]*[[:blank:]]*)\)%\1\x11\2\x12\3%

            # string: word [name [subword] name](link)
            # match : {word [name }[{subword}]{ name](link)}
            s%^\([^`]*\)\[\([^]]*\)]\([^][)(]*]([[:blank:]]*[^[:blank:]]*[[:blank:]]*)\)%\1\x11\2\x12\3%

            # string: word [name \x11subname\x12(sublink)](link)
            # match : {word [name \x11subname\x12}({sublink)](link)}
            s%^\([^`]*\[[^[]*\)(\([^][)(]*]([[:blank:]]*[^[:blank:]]*[[:blank:]]*)\)%\1\x14\2%

            # string: word [name \x11subname\x12\x14sublink)](link)
            # match : {word [name \x11subname\x12\x14sublink}){](link)}
            s%^\([^`]*\[[^[]*\))\([^][)(]*]([[:blank:]]*[^[:blank:]]*[[:blank:]]*)\)%\1\x15\2%

            # string: word [name](link(subword)link)
            # match : {word [name](link}({subword}){link)}
            s%\([^`]*\[[^][)(]*]([[:blank:]]*[^][)([:blank:]]*\)(\([^)[:blank:]]*\))\([^[:blank:]]*[[:blank:]]*)\)%\1\x14\2\x15\3%

            # string: word [name](link(subword)
            # match : {word [name](link}({subword)}
            s%\([^`]*\[[^][)(]*]([[:blank:]]*[^][)([:blank:]]*\)(\([^[:blank:]]*[[:blank:]]*)\)%\1\x14\2%

            # string: word [name](link[subword])
            # match : {word [name](link}[{subword])}
            s%\([^`]*\[[^][)(]*]([[:blank:]]*[^][)([:blank:]]*\)\[\([^[:blank:]]*[[:blank:]]*)\)%\1\x11\2%

            # string: word [name](link\x11subword])
            # match : {word [name](link\x11subword}]{)}
            s%\([^`]*\[[^][)(]*]([[:blank:]]*[^][)([:blank:]]*\)]\([^[:blank:]]*[[:blank:]]*)\)%\1\x12\2%
        }
        t mask_nested_links

        : mask_nested_acute
        # string: word [name](`link`)
        # match : {word [name](}`{link`)}
        s%^\([^`]*\[[^][)(`]*]([^)`]*\)`\([^)]*)\)%\1\x07\2%
        t mask_nested_acute

        # string: word [name link](link)
        # match : {word }[{name link}]({link})
        s%^\([^[`]*\)\[\([^][)(]*\)](\([[:blank:]]*[^][)([:blank:]]*[[:blank:]]*\))%\1\x1e\2\x0e\x1c\3\x0c%

        s/\[/\x11/g
        s/]/\x12/g
        s/(/\x14/g
        s/)/\x15/g
        s/\x1e/\[/g
        s/\x0e/]/g
        s/\x1c/(/g
        s/\x0c/)/g

        /^[^[`]*`/ b add_tag_code

        # mask characters in alt: *`_~"
        /^[^[`]*\!\[[^]]*[*`_~"][^]]*]/ {

            # string: word ![ alt * ]( link )
            # match : {word ![ alt }*{ ]}

            : mask_alt
            s%^\([^[`]*\!\[[^*]*\)\*\([^]]*]\)%\1\x06\2%
            s%^\([^[`]*\!\[[^`]*\)`\([^]]*]\)%\1\x07\2%
            s%^\([^[`]*\!\[[^_]*\)_\([^]]*]\)%\1\x08\2%
            s%^\([^[`]*\!\[[^~]*\)~\([^]]*]\)%\1\x10\2%
            s%^\([^[`]*\!\[[^"]*\)"\([^]]*]\)%\1\&quot;\2%
            t mask_alt
        }

        : mask_quot_in_name_link
        s%^\([^[`]*\!\?\[[^"]*\)"\([^]]*]\)%\1\&quot;\2%
        t mask_quot_in_name_link

        # mask characters in link: \<>`[]#"|?^{}_~*
        /^[^[`]*\!\?\[[^]]*]([^)]*[\x02\\\x04\x05\x07\x11\x12\x16#\x17|"?^{}_~*][^)]*)/ {

            # string: word [ name link ]( link* )
            # match : {word [ name link ]( link}*{ )}

            : mask_link
            s%^\([^[`]*\!\?\[[^]]*]([^)\x02]*\)\x02\([^)]*)\)%\1\%5C\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)\x04]*\)\x04\([^)]*)\)%\1\%3C\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)\x05]*\)\x05\([^)]*)\)%\1\%3E\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)\x07]*\)\x07\([^)]*)\)%\1\%60\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)\x11]*\)\x11\([^)]*)\)%\1\%5B\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)\x12]*\)\x12\([^)]*)\)%\1\%5D\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)\x16#]*\)\(#\|\x16\)\([^)]*)\)%\1\%23\3%
            s%^\([^[`]*\!\?\[[^]]*]([^)\x17|]*\)\(|\|\x17\)\([^)]*)\)%\1\%7C\3%
            s%^\([^[`]*\!\?\[[^]]*]([^)"]*\)"\([^)]*)\)%\1\%22\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)?]*\)?\([^)]*)\)%\1\%3F\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)^]*\)^\([^)]*)\)%\1\%5E\2%
            s%^\([^[`]*\!\?\[[^]]*]([^){]*\){\([^)]*)\)%\1\%7B\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)}]*\)}\([^)]*)\)%\1\%7D\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)_]*\)_\([^)]*)\)%\1\x08\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)~]*\)~\([^)]*)\)%\1\x10\2%
            s%^\([^[`]*\!\?\[[^]]*]([^)*]*\)\*\([^)]*)\)%\1\x06\2%
            t mask_link
        }

        # insert tag a
        # string: word ![ alt ]( link )
        # match : {word }![ {alt} ]( {link} )
        s%^\([^[`]*\)\!\[[[:blank:]]*\([^][:blank:]]*[^]]*[^][:blank:]]\)[[:blank:]]*\]([[:blank:]]*\([^)[:blank:]]*\)[[:blank:]]*)%\1<img src="\3" alt="\2">%
        b add_tag_link

        # string: word [ name link ]( link )
        # match : {word }[{ name link }]( {link} )
        s%^\([^[`]*\)\[\([^]]*\)\]([[:blank:]]*\([^)[:blank:]]*\)[[:blank:]]*)%\1<a href="\3">\2</a>%
        b add_tag_link

        : add_tag_del
        /~~/! b add_tag_strong-em_by_asterisk

        # string: [word~word~]
        # match : (word)~(word)~
        s%\(^\|[^~]\)~\([^~]\|$\)%\1\x10\2%g
        t add_tag_del

        # string: [word ~~ word]
        # match : (word )~~( )
        s%^\([^~]*[~\x10]*\)~\([~\x10]*[[:blank:]]\|$\)%\1\x10\2%
        t add_tag_del

        # string: [word ~~del-word~~]
        # match : (word )~~(del-word)~~
        s%\(^\|[^~]\)~~\([^~[:blank:]]\+[^~]*\)~~\([^~]\|$\)%\1<del>\2</del>\3%g
        t masking_nested_tildes

        # string: [word ~~del-word~~~0~~ word]
        # match : (word ~~del-word)~~~(0)
        /^\([^~]*\(~~[^~[:blank:]]\)\?[^~]*\)~\{3,\}\([^~]\|$\)/ {
            : masking_nested_tildes

            # string: [word ~~del-word\x10~~0~~ word]
            # match : (word ~~del-word\x10)~
            s%^\([^~]*\(~~[^~[:blank:]][^~]*\)\?\x10\)~%\1\x10%
            t masking_nested_tildes

            # string: [word ~~del-word~~~0~~ word]
            # match : (word ~~del-word)~(~~)
            s%^\([^~]*\(~~[^~[:blank:]][^~]*\)\?\)~\(~~\+\)%\1\x10\3%
            t masking_nested_tildes
            b add_tag_del
        }

        /\*/! b unmask

        : add_tag_strong-em_by_asterisk

        # string: [word ** word]
        # match : (word )**( )
        s%^\([^*]*[*\x06]*\)\*\([*\x06]*[[:blank:]]\|$\)%\1\x06\2%
        t add_tag_strong-em_by_asterisk

        # string: [word ***bold 0** word]
        # match : (word **)*(bold 0** word)
        s%^\([^*]*\*\*\)\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\*\*[^*]*$\)%\1\x06\2%
        t add_tag_strong-em_by_asterisk

        # string: [word *italic 0* word]
        # match : (word )*(italic 0)*( word)
        s%^\([^*]*\)\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\)\*\([^*]\|$\)%\1<em>\2</em>\3%
        t add_tag_strong-em_by_asterisk

        # string: [word **bold 0** word]
        # match : (word )**(bold 0)**
        s%^\([^*]*\)\*\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\)\*\*%\1<strong>\2</strong>%
        t add_tag_strong-em_by_asterisk

        # string: [word ***bold-italic 0*** word]
        # match : (word **)*(bold-italic 0)*(**) word
        s%^\([^*]*\*\*\)\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\)\*\(\*\*\)%\1<em>\2</em>\3%
        t add_tag_strong-em_by_asterisk

        # string: [***italic-bold 0** italic 0*]
        # match : (*)**(italic-bold 0)**( italic 0*)
        s%^\([^*]*\*\)\*\*\([^*[:blank:]]\+[^*]*\)\*\*\([^*]*\*\)%\1<strong>\2</strong>\3%
        t add_tag_strong-em_by_asterisk

        # string: [*italic 0 **italic-bold 0***]  | [*italic 0 **italic-bold 0** italic 1*]
        # match : (*italic 0 )**(italic-bold 0)**
        s%^\([^*]*\*[^*]*\)\*\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\)\*\*%\1<strong>\2</strong>%
        t add_tag_strong-em_by_asterisk

        # string: [**bold 0 *bold-italic 0* bold 1**] | [**bold 0 *bold-italic 0***]
        # match : (**bold 0 )*(bold-italic 0)*
        s%^\([^*]*\*\*[^*]*\)\*\([^*[:blank:]]\+[^*]*[^*[:blank:]]\)\*%\1<em>\2</em>%
        t add_tag_strong-em_by_asterisk

        # string: [word *italic 0 ***bold 0** word]
        # match : (word )*(italic 0 )*(**)
        s%^\([^*]*\)\*\([^*[:blank:]]\+[^*]*\)\*\(\*\*[^*].*\)%\1<em>\2</em>\3%
        t add_tag_strong-em_by_asterisk

        # string: [word **bold 0 **bold 1** word]
        # match : (word **bold 0 )**
        /^[^*]*\*\*[^*[:blank:]]*[^*]*[[:blank:]]\*\{1,\}.*[^*[:blank:]]\*\*\([^*]\|$\)/ {
          : inside_bold_blank_asterisks
            s%^\([^*]*\*\*[^*[:blank:]]*[^*]*[[:blank:]][*\x06]*\)\*%\1\x06%
          t inside_bold_blank_asterisks
          b add_tag_strong-em_by_asterisk
        }

        # string: [word **bold 0* **bold 1** word]
        # match : (word **bold 0)*( )
        /^[^*]*\*\*[^*[:blank:]]*[^*]*[^*[:blank:]]\*[^*]*.*[^*[:blank:]]\*\*/ {
          : inside_bold_star_blank
            s%^\([^*]*\*\*[^*[:blank:]]*[^*]*[^*[:blank:]]\)\*\([[:blank:]]\|$\)%\1\x06\2%
          t inside_bold_star_blank
          b add_tag_strong-em_by_asterisk
        }

        # string: [word *italic 0 **** italic 1* word]
        # match : (word *italic 0 )****(i)
        /^[^*]*\*[^*[:blank:]]*[^*]*[[:blank:]]\*\+.*[^*[:blank:]]\*\([^*]\|$\)/ {
          : inside_italics_asterisks_end
            s%^\([^*]*\*[^*[:blank:]]*[^*]*[[:blank:]][*\x06]*\)\*\([^*]\|$\)%\1\x06\2%
          t inside_italics_asterisks_end
          b add_tag_strong-em_by_asterisk
        }

        # string: [**italic 0* word **]
        # match : (*)*(italic 0* )
        /^[^*]*\*\*[^*[:blank:]]*[^*]*[^*[:blank:]]\*\([[:blank:]]\|$\)/ {
          : inside_italics_asterisks_start
          s%^\([^*]*\*\)\*\([^*[:blank:]]*[^*]*[^*[:blank:]]\*\([[:blank:]]\|$\)\)%\1\x06\2%
          t inside_italics_asterisks_start
          b add_tag_strong-em_by_asterisk
        }

        # string: [word *italic 0** italic 1* word]
        # match : (word *italic 0)**( italic 1*)
        /^[^*]*\*[^*[:blank:]]*[^*]*[^*[:blank:]]\(\*\{2\}\|\*\{4,\}\).*[^*[:blank:]]\*[^*]*/ {
          : inside_italics_asterisks
          s%^\([^*]*\*[^*[:blank:]]*[^*]*[^[:blank:]]\)\*\([^*]\)%\1\x06\2%
          t inside_italics_asterisks
          b add_tag_strong-em_by_asterisk
        }

        # string: [word *italic 0 * word]
        # match : (word )*(italic 0 )*( word)
        s%^\([^*]*\)\*\([^*[:blank:]]\+[^*]*\)\*\([^*]\+\|$\)%\1<em>\2</em>\3%
        t add_tag_strong-em_by_asterisk

        # string: [word *italic 0 **** word]
        # match : (word *italic 0 ***)*( word)
        s%^\([^*]*\)\*\([^*[:blank:]]\+[^*]*\*\{2,\}\)\*\([^*]*$\)%\1<em>\2</em>\3%
        t add_tag_strong-em_by_asterisk

        : unmask
        s%\x02%\\%g
        s%\x03%\&amp;%g
        s%\x04%\&lt;%g
        s%\x05%\&gt;%g
        s%\x06%*%g
        s%\x07%`%g
        s%\x08%_%g
        s%\x10%~%g
        s%\x11%[%g
        s%\x12%]%g
        s%\x13%!%g
        s%\x14%(%g
        s%\x15%)%g
        s%\x16%#%g
        s%\x17%|%g
        s%\x7f%<br />\x01%g
        s%"%\&quot;%g

        : end_of_line
    '
}

combine_string_with_tag ()
{
    #                 ┌──> sequence of incoming strings <──┐
    #                 │                                    │
    # <ul> ────────── 1 ──┐                                │
    # <li>\x18 ────── 2 ──┤                             ┌─ 1 ─> <ul>
    # STRING_BUFFER ─ 3 ──┼─> combine_string_with_tag ─>┼─ 2 ─> <li>STRING_BUFFER</li>
    # \x19</li> ───── 4 ──┤                             └─ 3 ─> </ul>
    # </ul> ───────── 5 ──┘
    sed '
        # (^X|\x18|\030) MARKER_START_MERGE_STRING at the end of the opening tag
        /\x18$/ {
            : combine_strings
            $!N
            s%\n%%

            # (^Y|\x19|\031) MARKER_STOP_MERGE_STRING at the end of the closing tag
            /\x19/ {
                b split_tag
            }
            t combine_strings

            # \1 - opening tag
            # \2 - any tag
            : split_tag
            s%\x18\x19%%
            s%^\([^\x18]\+\)\x18\(\(<\(script\|pre\|textarea\|style\)[[:blank:]]*\(>\|$\)\)\|<!--\|<?\|<![A-Za-z]\|<\!\[CDATA\[\|</\?\(address\|article\|aside\|base\|basefont\|blockquote\|body\|caption\|center\|col\|colgroup\|dd\|details\|dialog\|dir\|div\|dl\|dt\|fieldset\|figcaption\|figure\|footer\|form\|frame\|frameset\|h[123456]\|head\|header\|hr\|html\|iframe\|legend\|li\|link\|main\|menu\|menuitem\|nav\|noframes\|ol\|optgroup\|option\|p\|param\|section\|source\|summary\|table\|tbody\|td\|tfoot\|th\|thead\|title\|tr\|track\|ul\)[[:blank:]]*\(/\?>\|$\)\)%\1\x01\2%
        }

        s%[\x18\x19]%%g
        s%\x1a%%g
        : end_of_line
    '
}

split_strings ()
{
    sed '
        # (^A|\x01|\001) MARKER_NEW_STRING anywhere in the string
        s%^\x01%%
        s%\x01$%%
        s%\x01%\n%g
    '
}

get_tag_indent ()
{
    case "$1" in
        -) TAG_INDENT="$(printf "%$((${#TAG_INDENT} - ${2:-"${TAG_INDENT_WIDTH:=2}"}))s" '')" ;;
        +) TAG_INDENT="$(printf "%$((${#TAG_INDENT} + ${2:-"${TAG_INDENT_WIDTH:=2}"}))s" '')" ;;
    esac
}

get_code_block_tag_with_class ()
{
    OPENING_TAG="<pre><code class=\"${CLASS:+fenced-code-block language-}${CLASS:-indented-code-block}\">$MARKER_START_MERGE_STRING"
}

get_code_block_tag ()
{
    OPENING_TAG="<pre><code${CLASS:+ class=\"language-$CLASS\"}>$MARKER_START_MERGE_STRING"
}

get_heading_id ()
{
    sed '
        : merge
        $!N
        s%[\]*\n%-%
        t merge
        s%[[:blank:]]%-%g
        s%[^a-zA-Z0-9_-]%%g
        s%-\+%-%g
        s%\(^-\+\|-\+$\)%%g

        # all in lowercase
        s%.*%\L&%g'
}

get_heading_tag_with_class ()
{
    ID="$(get_heading_id <<< "${STRING:-}")"
    is_empty "${ID:-}" || {
        is_empty "${ID_BASE["$ID"]:-}" || ID="$ID-$((ID_NUM+1))"
        ID_BASE["$ID"]="$ID"
    }
    OPENING_TAG="<$1 class=\"${CLASS:-atx}\" id=\"${ID:-}\">$MARKER_START_MERGE_STRING"
}

get_heading_tag ()
{
    OPENING_TAG="<$1>$MARKER_START_MERGE_STRING"
}

get_tag ()
{
    case "$1" in
        blockquote|ul)
            OPENING_TAG="$MARKER_NEW_STRING<$1>"
            CLOSING_TAG="</$1>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
            get_tag_indent +
            ;;
        code_block)
            $GET_CODE_BLOCK_TAG
            CLOSING_TAG="$MARKER_STOP_MERGE_STRING</code></pre>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT=""
            get_tag_indent +
            ;;
        li)
            OPENING_TAG="$MARKER_NEW_STRING<$1>$MARKER_START_MERGE_STRING"
            CLOSING_TAG="$MARKER_STOP_MERGE_STRING</$1>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
            get_tag_indent +
            ;;
        h[1-6])
            $GET_HEADING_TAG "$1"
            CLOSING_TAG="$MARKER_STOP_MERGE_STRING</$1>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT=""
            ;;
        ol)
            OPENING_TAG="$MARKER_NEW_STRING<$1${OL_START:+ start="$OL_START"}>"
            CLOSING_TAG="</$1>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
            get_tag_indent +
            ;;
        paragraph)
            if is_empty "${2:-}"
            then
                OPENING_TAG="<p>$MARKER_START_MERGE_STRING"
                CLOSING_TAG="$MARKER_STOP_MERGE_STRING</p>"
            else
                OPENING_TAG="$2<p>"
                CLOSING_TAG="</p>$2"
            fi
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
            ;;
    esac
    CLASS=
}

put_tag_in_buffer ()
{
    OPENING_INDENT_BUFFER["$DEPTH"]="${OPENING_TAG_INDENT:-}"
    CLOSING_INDENT_BUFFER["$DEPTH"]="${CLOSING_TAG_INDENT:-}"

    OPENING_TAG_BUFFER["$DEPTH"]="$OPENING_TAG"
    CLOSING_TAG_BUFFER["$DEPTH"]="$CLOSING_TAG"

    OPENING_TAG=
    CLOSING_TAG=
}

put_tag_in_subbuffer ()
{
    OPENING_INDENT_SUBBUFFER["$DEPTH"]="${OPENING_TAG_INDENT:-}"
    CLOSING_INDENT_SUBBUFFER["$DEPTH"]="${CLOSING_TAG_INDENT:-}"

    OPENING_TAG_SUBBUFFER["$DEPTH"]="$OPENING_TAG"
    CLOSING_TAG_SUBBUFFER["$DEPTH"]="$CLOSING_TAG"

    OPENING_TAG=
    CLOSING_TAG=
}

string_buffer_is_empty ()
{
    is_empty "${STRING_BUFFER["$DEPTH"]:-}"
}

string_buffer_is_not_empty ()
{
    string_buffer_is_empty && return 1 || return 0
}

remove_last_empty_strings ()
{
    STRING_BUFFER[-1]="${STRING_BUFFER[-1]%"${STRING_BUFFER[-1]##*[!$MARKER_NEW_STRING]}"}"
}

mark_a_string_buffer ()
{
    STRING_BUFFER[-1]="$MARKER_FORMAT_STRING${STRING_BUFFER[-1]}"
}

get_paragraph ()
{
    get_tag "paragraph"
    put_tag_in_buffer
    remove_last_empty_strings
    mark_a_string_buffer
    OPEN_BLOCKS["$DEPTH"]="paragraph"
}

get_string_buffer ()
{
    is_empty "${!STRING_BUFFER[@]}" || {
        if no_open_blocks
        then
            get_paragraph
        else
            case "${OPEN_BLOCKS[-1]}" in
                "indent_code_block")
                    remove_last_empty_strings
                    STRING_BUFFER[-1]="${STRING_BUFFER[-1]}${CANONICAL_PRE_CODE:-}"
                    ;;
                "code_block")
                    STRING_BUFFER[-1]="${STRING_BUFFER[-1]}${CANONICAL_PRE_CODE:-}"
                    ;;
                "block_quote")
                    SAVED_DEPTH="$DEPTH"
                    DEPTH="$((${#OPEN_BLOCKS[@]} + 1))"
                    get_paragraph
                    DEPTH="$SAVED_DEPTH"
                    ;;
                *)
                    mark_a_string_buffer
            esac
        fi
        STRING_BUFFER[-1]="${STRING_BUFFER[-1]}$NEW_STRING"
    }
}

print_opening_tags ()
{
    is_empty "${!OPEN_BLOCKS[@]}" || {
        TAG=
        for i in "${!OPEN_BLOCKS[@]}"
        do
            is_empty "${OPENING_TAG_BUFFER[$i]:-}" ||
                TAG="${TAG:+$TAG$NEW_STRING}${OPENING_INDENT_BUFFER[$i]:-}${OPENING_TAG_BUFFER[$i]}"
            is_empty "${OPENING_TAG_SUBBUFFER[$i]:-}" ||
                TAG="${TAG:+$TAG$NEW_STRING}${OPENING_INDENT_SUBBUFFER[$i]:-}${OPENING_TAG_SUBBUFFER[$i]}"
        done
        OPENING_INDENT_BUFFER=()
        OPENING_INDENT_SUBBUFFER=()
        OPENING_TAG_BUFFER=()
        OPENING_TAG_SUBBUFFER=()
        is_empty "${TAG:-}" || echo "$TAG"
    }
}

print_closing_tags ()
{
    is_empty "${!OPEN_BLOCKS[@]}" || {
        case "${1:-}" in
            "without closing tags")
                return
                ;;
        esac
        TAG=
        # get tags starting from the last one added
        for ((i=${#OPEN_BLOCKS[@]}; i>=1; i--))
        do
            if test "$i" -ge "$DEPTH"
            then
                is_empty "${CLOSING_TAG_SUBBUFFER[$i]:-}" || {
                    TAG="${TAG:+$TAG$NEW_STRING}${CLOSING_INDENT_SUBBUFFER[$i]:-}${CLOSING_TAG_SUBBUFFER[$i]}"
                    unset -v "CLOSING_TAG_SUBBUFFER[-1]" "CLOSING_INDENT_SUBBUFFER[-1]"
                    is_empty "${1:-}" || is_diff "$i" "$DEPTH" || break
                }

                TAG="${TAG:+$TAG$NEW_STRING}${CLOSING_INDENT_BUFFER[-1]:-}${CLOSING_TAG_BUFFER[-1]}"
                unset -v "OPEN_BLOCKS[-1]" "NESTING_DEPTH[-1]" "CLOSING_TAG_BUFFER[-1]" "CLOSING_INDENT_BUFFER[-1]"
            else
                break
            fi
        done
        # TAG_INDENT="${TAG_INDENT%"$(printf "%$((TAG_INDENT_WIDTH*DEPTH+2))s" '')"}"
        is_empty "${TAG:-}" || echo "$TAG"
    }
}

print_buffer ()
{
    get_string_buffer
    print_opening_tags
    echo -n "${STRING_BUFFER[@]:-}"
    print_closing_tags "${1:-}"
    STRING_BUFFER=()
}

put_string_in_buffer ()
{
    is_empty "${!STRING_BUFFER[@]}" && {
        is_empty "${!CLOSING_INDENT_BUFFER[@]}" || TAG_INDENT="${CLOSING_INDENT_BUFFER[-1]}"
        BUFFER_INDENT="${TAG_INDENT:-}"
        STRING_BUFFER["$DEPTH"]="${STRING:-"$EMPTY_STRING"}"
    } || {
        STRING_BUFFER[-1]="${STRING_BUFFER[-1]}$MARKER_NEW_STRING${BUFFER_INDENT:-}$STRING"
    }
    STRING=
}

no_open_blocks ()
{
    is_empty "${!OPEN_BLOCKS[@]}"
}

is_max_nesting ()
{
    is_empty "${OPEN_BLOCKS["$((DEPTH + 1))"]:-}"
}

block_quote_is_closed ()
{
    is_empty "${BLOCK_QUOTE:-}"
}

list_is_open ()
{
    [[ "${OPEN_BLOCKS[@]}" =~ [*+-] ]]
}

code_block_is_closed ()
{
    is_diff "${CODE_BLOCK:-"${INDENT_CODE_BLOCK:-}"}" "open"
}

string_is_empty ()
{
    case "${1:-}" in
        *[![:blank:]]*)
            return 1
    esac
}

string_is_not_empty ()
{
    string_is_empty "${1:-}" && return 1 || return 0
}

parse_empty_string ()
{
    if no_open_blocks
    then
        # print a paragraph
        is_empty "${!STRING_BUFFER[@]}" || print_buffer
    else
        if list_is_open
        then
            if block_quote_is_closed
            then
                if is_empty "${!STRING_BUFFER[@]}"
                then
                    close_list "last list"
                else
                    # add an empty string to the list
                    STRING="$EMPTY_STRING"
                    put_string_in_buffer
                fi
            else
                close_block_quote
            fi
        else
            if block_quote_is_closed
            then
                code_block_is_closed || {
                    # add an empty string to the code block
                    trim_indent "$EXCESS_INDENT"
                    put_string_in_buffer
                }
            else
                close_block_quote
            fi
        fi
    fi
    return 1
}

trim_indent ()
{
    is_not_empty "${STRING:-}" || return
    SAVED_STRING="$STRING"
    TRIM_SPACE="${1:-4}"
    CHARACTER_POSITION="${2:-0}"
    test "$CHARACTER_POSITION" -le 4 ||
    CHARACTER_POSITION=$(( CHARACTER_POSITION - $(( $(( CHARACTER_POSITION / 4 )) * 4 )) ))

    while is_not_empty "${STRING:-}"
    do
        is_diff "$TRIM_SPACE" 0 || break
        is_diff "$CHARACTER_POSITION" 4 &&
            CHARACTER_POSITION="$((CHARACTER_POSITION + 1))" ||
            CHARACTER_POSITION=1
        case "$STRING" in
            $SPACE*)
                STRING="${STRING:1}"
                TRIM_SPACE="$((TRIM_SPACE - 1))"
                ;;
            $TAB*)
                TAB_LENGTH="$((4 -  $((CHARACTER_POSITION - 1))))"
                CHARACTER_POSITION="$((CHARACTER_POSITION - 1 + TAB_LENGTH))"
                if is_equal "$TRIM_SPACE" "$TAB_LENGTH"
                then
                    STRING="${STRING:1}"
                    break
                elif test "$TRIM_SPACE" -lt "$TAB_LENGTH"
                then
                    STRING="$(printf "%$((TAB_LENGTH - TRIM_SPACE))s")${STRING:1}"
                    break
                else
                    STRING="${STRING:1}"
                    TRIM_SPACE="$((TRIM_SPACE - TAB_LENGTH))"
                fi
                ;;
            *)
                break
        esac
    done
    is_diff "$SAVED_STRING" "${STRING:-}"
}

expand_indent ()
{
    STRING="$1"
    CHARACTER_POSITION="${2:-0}"
    test "$CHARACTER_POSITION" -le 4 ||
    CHARACTER_POSITION=$(( CHARACTER_POSITION - $(( $(( CHARACTER_POSITION / 4 )) * 4 )) ))
    INDENT=""
    while is_not_empty "${STRING:-}"
    do
        is_diff "$CHARACTER_POSITION" 4 &&
            CHARACTER_POSITION="$((CHARACTER_POSITION + 1))" ||
            CHARACTER_POSITION=1
        case "$STRING" in
            $SPACE*)
                INDENT="${INDENT:-} "
                STRING="${STRING:1}"
                ;;
            $TAB*)
                TAB_LENGTH="$((4 -  $((CHARACTER_POSITION - 1))))"
                CHARACTER_POSITION="$((CHARACTER_POSITION - 1 + TAB_LENGTH))"
                INDENT="${INDENT:-}$(printf "%${TAB_LENGTH}s")"
                STRING="${STRING:1}"
                ;;
            *)
                break
        esac
    done
    echo "${INDENT:-}${STRING:-}"
}

get_indent ()
{
    string_is_not_empty "${STRING:-}" || return
    INDENT="${STRING%%[![:blank:]]*}"
    INDENT_LENGTH="$(expand_indent "${STRING:-}" "$CHAR_NUM")"
    INDENT_LENGTH="${INDENT_LENGTH%%[![:blank:]]*}"
    INDENT_LENGTH="${#INDENT_LENGTH}"
}

is_beginning_of_string ()
{
    test "$DEPTH" -eq 0
}

parse_indent ()
{
    # ┌>-> DEPTH -> 0 (0:2)
    # │ ┌>---┌> DEPTH -> 1 (3:8)       # ┌>---┌> DEPTH -> 1 (0:5)
    # ├┐│    ├>---┌> DEPTH -> 2 (8:13) # │    ├>---┌> DEPTH -> 2 (5:10)
    # ◦◦◦-◦◦◦◦-◦◦◦◦foo                 # -◦◦◦◦-◦◦◦◦foo
    # ◦◦◦◦◦◦◦◦-◦◦◦◦baz
    get_indent || {
        is_empty "${NESTING_DEPTH[-1]}" || {
            #     ┌> there are no characters after the indent
            # ◦◦◦-◦◦◦◦
            NESTING_DEPTH[-1]="${NESTING_DEPTH[-1]}:$((${NESTING_DEPTH[-1]} + 2))"
        }
        return 1
    }

    if no_open_blocks
    then
        if test "$INDENT_LENGTH" -lt 4
        then
            #   ┌> the indent length is less than or equal to 3
            # ◦◦◦foo (current string)
            CHAR_NUM="$((CHAR_NUM + INDENT_LENGTH + 1))"
            return 0
        else
            #    ┌> indent length greater than 3
            # ◦◦◦◦foo (current string)
            if string_buffer_is_empty
            then
                open_indent_code_block
            else
                put_string_in_buffer
            fi
            return 1
        fi
    elif is_max_nesting
    then
        if test "$INDENT_LENGTH" -lt 4
        then
            #         ┌> the indent length is less than or equal to 3
            # ◦◦◦-◦◦◦-◦foo (current string)
            CHAR_NUM="$((CHAR_NUM + INDENT_LENGTH + 1))"
            NESTING_DEPTH[-1]="${NESTING_DEPTH[-1]}:$((CHAR_NUM - 1))"
            return 0
        else
            #             ┌> indent length greater than 3
            # ◦◦◦-◦◦◦-◦◦◦◦◦foo (current string)
            NESTING_DEPTH[-1]="${NESTING_DEPTH[-1]}:$CHAR_NUM"
            if string_buffer_is_empty
            then
                open_indent_code_block
            else
                put_string_in_buffer
            fi
            return 1
        fi
    else
        case "${OPEN_BLOCKS["$((DEPTH + 1))"]}" in
            "code_block")
                if test "$INDENT_LENGTH" -lt 4
                then
                    trim_indent "$EXCESS_INDENT"
                    add_to_code_block
                else
                    trim_indent "$EXCESS_INDENT"
                    put_string_in_buffer
                fi
                return 1
                ;;
            "indent_code_block")
                if test "$INDENT_LENGTH" -lt 4
                then
                    print_buffer
                    CHAR_NUM="$((CHAR_NUM + INDENT_LENGTH + 1))"
                    return 0
                else
                    trim_indent
                    put_string_in_buffer
                    return 1
                fi
                ;;
            "block_quote")
                if test "$INDENT_LENGTH" -lt 4
                then
                    CHAR_NUM="$((CHAR_NUM + INDENT_LENGTH + 1))"
                    return 0
                else
                    if  string_buffer_is_empty ||
                        is_equal "${OPEN_BLOCKS[-1]}" "indent_code_block"
                    then
                        print_buffer
                        open_indent_code_block
                    else
                        put_string_in_buffer
                    fi
                fi
        esac

        while true
        do
            if test "$INDENT_LENGTH" -lt "${NESTING_DEPTH["$((DEPTH + 1))"]#*:}"
            then
                test "$INDENT_LENGTH" -ge 4 || return 0
                if string_buffer_is_empty
                then
                    #   ┌> ${NESTING_DEPTH["$DEPTH"]%:*} -> 3
                    #   │ ┌> ${NESTING_DEPTH["$DEPTH"]#*:} -> 5 <┐
                    # ◦◦◦-                                       │
                    #    ┌> the current indent is less than the next nesting level
                    # ◦◦◦◦-◦◦◦◦bar (current string)
                    print_buffer
                    open_indent_code_block
                else
                    #   ┌> ${NESTING_DEPTH["$DEPTH"]%:*} -> 3
                    #   │ ┌> ${NESTING_DEPTH["$DEPTH"]#*:} -> 5 <┐
                    # ◦◦◦-◦foo                                   │
                    #    ┌> the current indent is less than the next nesting level
                    # ◦◦◦◦-◦◦◦◦bar (current string)
                    DEPTH="$((DEPTH + 1))"
                    put_string_in_buffer
                fi
                return 1
            elif test "$INDENT_LENGTH" -eq "${NESTING_DEPTH["$((DEPTH + 1))"]#*:}"
            then
                # ┌> ${NESTING_DEPTH["$DEPTH"]%:*} -> 1
                # │ ┌> ${NESTING_DEPTH["$DEPTH"]#*:} -> 3 <┐
                # ◦-◦foo                                   │
                #   ┌> the current indent is equal to the next nesting level
                # ◦◦◦-◦◦◦◦bar (current string)
                DEPTH="$((DEPTH + 1))"
                CHAR_NUM="$((CHAR_NUM + INDENT_LENGTH + 1))"
                return 0
            else
                if is_empty "${NESTING_DEPTH["$((DEPTH + 2))"]:-}"
                then
                    #   ┌> ${NESTING_DEPTH["$DEPTH"]%:*} -> 3
                    #   │ ┌> ${NESTING_DEPTH["$DEPTH"]#*:} -> 5 <┐
                    # ◦◦◦-◦foo                                   │
                    #        ┌> the current indent is no more than 3 spaces larger than the last nesting level
                    # ◦◦◦◦◦◦◦◦-◦◦◦◦bar (current string)
                    DEPTH="$((DEPTH + 1))"
                    test "$INDENT_LENGTH" -le "$(( ${NESTING_DEPTH["$DEPTH"]#*:} + 3))" || {
                        if string_buffer_is_empty
                        then
                            is_diff "${OPEN_BLOCKS["$DEPTH"]}" "block_quote" || print_buffer
                            open_indent_code_block "$(( ${NESTING_DEPTH["$DEPTH"]#*:} + 4))"
                        else
                            if [[ "${STRING_BUFFER[-1]}" =~ $EMPTY_STRING$ ]]
                            then
                                DEPTH="$((DEPTH + 1))"
                                print_buffer
                                open_indent_code_block "$(( ${NESTING_DEPTH["$((DEPTH - 1))"]#*:} + 4))"
                            else
                                put_string_in_buffer
                            fi
                        fi
                        return 1
                    }
                    CHAR_NUM="$((CHAR_NUM + INDENT_LENGTH + 1))"
                    return 0
                else
                    #   ┌> ${NESTING_DEPTH["$DEPTH"]%:*} -> 3
                    #   │    ┌> ${NESTING_DEPTH["$DEPTH"]#*:} -> 8 <────┐
                    #   │    ├> ${NESTING_DEPTH["$DEPTH"]%:*} -> 8      │
                    #   │    │   ┌> ${NESTING_DEPTH["$DEPTH"]#*:} -> 12 │
                    # ◦◦◦-◦◦◦◦-◦◦◦foo                                   │
                    #          ┌> the current indent is greater than the next nesting level
                    # ◦◦◦◦◦◦◦◦◦◦-◦◦◦◦bar (current string)
                    DEPTH="$((DEPTH + 1))"
                fi
            fi
        done
    fi
}

parse_block_structure ()
{
    DEPTH="0"
    CHAR_NUM="0"
    string_is_not_empty "${STRING:-}" || parse_empty_string || return 0

    NESTING_DEPTH["$DEPTH"]=""

    while is_not_empty "${STRING:-}"
    do
        parse_indent || return 0

        STRING="${STRING#"${INDENT:-}"}"
        case "$STRING" in
            \>*)
                open_block_quote
                ;;
            [_]*)
                print_horizontal_rule "_" || put_string_in_buffer
                return
                ;;
            [#]*)
                print_heading_atx || put_string_in_buffer
                return
                ;;
            [=]*)
                print_heading_setext "=" || put_string_in_buffer
                return
                ;;
            [-]*)
                print_heading_setext  "-" ||
                print_horizontal_rule "-" && return ||
                open_unordered_list   "-" || {
                    put_string_in_buffer
                    return
                }
                ;;
            [*]*)
                print_horizontal_rule "*" && return ||
                is_not_empty "${NESTING_DEPTH[$((DEPTH+1))]:-}" ||
                [[ "$STRING" =~ ^"*"[[:blank:]]+[![:blank:]] ]] ||
                string_buffer_is_empty  &&
                open_unordered_list "*" || {
                    put_string_in_buffer
                    return
                }
                ;;
            [+]*)
                is_not_empty "${NESTING_DEPTH[$((DEPTH+1))]:-}" ||
                [[ "$STRING" =~ ^"+"[[:blank:]]+[![:blank:]] ]] ||
                string_buffer_is_empty  &&
                open_unordered_list "+" || {
                    put_string_in_buffer
                    return
                }
                ;;
            *)
                add_to_code_block ||
                put_string_in_buffer
                return
        esac
        STRING="${STRING:1}"
        trim_indent 1 "$CHAR_NUM" && CHAR_NUM="$((CHAR_NUM + 1))" || true
    done
    is_empty "${NESTING_DEPTH[-1]:-}" || {
        #     ┌> current position
        # ◦◦◦-
        NESTING_DEPTH[-1]="${NESTING_DEPTH[-1]}:$((${NESTING_DEPTH[-1]} + 2))"
    }
}

serialize_pre_code_language ()
{
    sed '
        # get the first word
        s%^[[:blank:]]*\([^[:blank:]]\+\).*$%\1%g

        # all in lowercase
        s%.*%\L&%g

        # mask ampersand
        s%\([^\\]\?\)&%\1\x03%g

        # remove backslash-escaped
        s%\\\([][!"#$%&\x27()*+,./:;<=>?@\\^_`{|}~-]\)%\1%g

        s%&%\&amp;%g
        s%"%\&quot;%g
        s%<%\&lt;%g
        s%>%\&gt;%g

        # unmask ampersand
        s%\x03%\&%g'
}

is_code_block ()
{
    if is_empty "${FENCE_CHAR:-}"
    then
        [[ "${STRING:-}" =~ ^[[:blank:]]*\`{3,}[^\`]*$ ]] ||
        [[ "${STRING:-}" =~ ^[[:blank:]]*~{3,} ]] && {
            FENCE_CHAR="${STRING%%[!~\`]*}"
            FENCE_LENGTH="${#FENCE_CHAR}"
            CLASS="${STRING#"$FENCE_CHAR"}"
            is_empty "${CLASS:-}" ||
                CLASS="$(serialize_pre_code_language <<< "$CLASS")"
            FENCE_CHAR="${FENCE_CHAR:0:1}"
        }
    else
        [[ "${STRING:-}" =~ ^[[:blank:]]*$FENCE_CHAR{$FENCE_LENGTH,}[[:blank:]]*$ ]]
    fi
}

open_code_block ()
{
    DEPTH="$((DEPTH + 1))"
    get_tag "code_block"
    put_tag_in_buffer
    CODE_BLOCK="open"
    OPEN_BLOCKS["$DEPTH"]="code_block"
    EXCESS_INDENT="${#INDENT}"
}

close_code_block ()
{
    print_buffer
    FENCE_CHAR=
    INDENTED_CODE_BLOCK="closed"
             CODE_BLOCK="closed"
}

add_to_code_block ()
{
    if is_equal "${CODE_BLOCK:-}" "open"
    then
        is_code_block && close_code_block "$DEPTH" || put_string_in_buffer
    else
        is_code_block && {
            string_buffer_is_empty || print_buffer
            open_code_block
        }
    fi
}

open_indent_code_block ()
{
    DEPTH="$((DEPTH + 1))"
    NESTING_DEPTH["$DEPTH"]=
    OPEN_BLOCKS["$DEPTH"]="indent_code_block"
    INDENT_CODE_BLOCK="open"
    EXCESS_INDENT="${1:-4}"
    trim_indent "$EXCESS_INDENT" "$CHAR_NUM"
    get_tag "code_block"
    put_tag_in_buffer
    put_string_in_buffer
}

close_indent_code_block ()
{
    is_empty "${INDENT_CODE_BLOCK:-}" || print_buffer
}

open_list_item ()
{
    get_tag "li"
    put_tag_in_subbuffer
}

open_unordered_list ()
{
    [[ "$STRING" =~ ^"$1"([[:blank:]]|$) ]] && {
        if is_equal "${OPEN_BLOCKS["$((DEPTH + 1))"]:-}" "$1"
        then
            DEPTH="$((DEPTH + 1))"
            print_buffer "close tags to the current list item"
        else
            if is_empty "${!STRING_BUFFER[@]}"
            then
                DEPTH="$((DEPTH + 1))"
            else
                DEPTH="$((DEPTH + 1))"
                print_buffer
            fi
            OPEN_BLOCKS["$DEPTH"]="$1"
            get_tag "ul"
            put_tag_in_buffer
        fi
        open_list_item
        NESTING_DEPTH["$DEPTH"]="$((CHAR_NUM - 1))"
    }
}

close_list ()
{
    case "${1:-}" in
        "last list")
            print_buffer "$((${#OPEN_BLOCKS[@]} - 2))"
    esac
}

open_block_quote ()
{
    # remember the first nesting depth of the block to close all tags,
    # including this block, when an empty string or other block occurs.
    DEPTH="$((DEPTH + 1))"
    BLOCK_QUOTE="${BLOCK_QUOTE:-"$DEPTH"}"

    get_tag "blockquote"
    is_empty "${!CLOSING_TAG_BUFFER[@]}" || is_empty "${CLOSING_TAG_BUFFER["$DEPTH"]:-}" && {
        string_buffer_is_empty || print_buffer "without closing tags"
    } || {
        if is_equal "${CLOSING_TAG_BUFFER["$DEPTH"]}" "$CLOSING_TAG"
        then
            return 0
        else
            print_buffer
        fi
    }
    OPEN_BLOCKS["$DEPTH"]="block_quote"
    NESTING_DEPTH["$DEPTH"]="$((CHAR_NUM - 1))"
    put_tag_in_buffer
}

close_block_quote ()
{
    print_buffer
    BLOCK_QUOTE=
}

trim_white_space ()
{
    STRING="${STRING#"${STRING%%[![:blank:]]*}"}"
    STRING="${STRING%"${STRING##*[![:blank:]]}"}"
}

print_heading ()
{
    is_equal "$DEPTH" 0  &&
            print_buffer || print_buffer "without closing tags"
    DEPTH="$((DEPTH + 1))"
    OPEN_BLOCKS["$DEPTH"]="heading"
    NESTING_DEPTH["$DEPTH"]=""
    trim_white_space
    get_tag "$1"
    put_tag_in_buffer
    is_empty "${STRING:-}" || put_string_in_buffer
    print_buffer
    DEPTH="$((DEPTH - 1))"
}

print_heading_atx ()
{
    [[ "${STRING:-}" =~ ^#{1,6}([[:blank:]].*|$) ]] && {
        HEADER="${STRING%%[[:blank:]]*}"
        STRING="$(sed 's%\(^#\+\|[[:blank:]]\+#*[[:blank:]]*$\)%%g' <<< "$STRING")"
        CLASS="atx"
        print_heading "h${#HEADER}"
    }
}

print_heading_setext ()
{
    string_buffer_is_not_empty &&
    [[ "$STRING" =~ ^"$1"+[[:blank:]]*$ ]] && {
        STRING="$STRING_BUFFER"
        unset -v "STRING_BUFFER[-1]"
        CLASS="setext"
        case "$1" in
            =) print_heading "h1" ;;
            -) print_heading "h2" ;;
        esac
    }
}

print_horizontal_rule ()
{
    [[ "${STRING//[[:blank:]]}" =~ ^"$1"{3,}$ ]] && {
        STRING="${TAG_INDENT:-}<hr />$MARKER_NEW_STRING$NEW_STRING"
        is_equal "$DEPTH" 0  &&
                print_buffer || print_buffer "without closing tags"
        echo -n "$STRING"
    }
}

reset_block_variables ()
{
    STRING_BUFFER=()
    INDENT_CODE_BLOCK=
    CODE_BLOCK=
    BLOCK_QUOTE=
    LIST_ITEM=
}

open_block ()
{
    while IFS= read -r STRING || is_not_empty "${STRING:-}"
    do
        TAG_INDENT="${MAIN_TAG_INDENT:-}"
        parse_block_structure
    done < <(cat "${INPUT:--}")
    if no_open_blocks
    then
        print_buffer
    else
        DEPTH="0"
        case "${OPEN_BLOCKS[-1]}" in
            "code_block" | "indent_code_block")
                close_code_block
                ;;
            *)
                print_buffer
        esac
    fi
}

convert_md2html ()
{
    PREFIX_INDENT=
    TAG_INDENT_WIDTH=0
    MAIN_TAG_INDENT=""

    NESTING_DEPTH=()
    OPENING_TAG_BUFFER=()
    CLOSING_TAG_BUFFER=()
    OPENING_INDENT_BUFFER=()
    CLOSING_INDENT_BUFFER=()

    OPENING_TAG_SUBBUFFER=()
    OPENING_INDENT_SUBBUFFER=()

    OPEN_BLOCKS=()
    reset_block_variables

    ID_NUM=0
    declare -A ID_BASE

    MARKER_START_MERGE_STRING="$(tr '\n' '\030' <<< "")" # ^X [\x18]
     MARKER_STOP_MERGE_STRING="$(tr '\n' '\031' <<< "")" # ^Y [\x19]
         MARKER_FORMAT_STRING="$(tr '\n' '\037' <<< "")" # ^_ [\x1f]
            MARKER_NEW_STRING="$(tr '\n' '\001' <<< "")" # ^A [\x01]
                MARKER_TAG_BR="$(tr '\n' '\177' <<< "")" # ^? [\x7f]
                 EMPTY_STRING="$(tr '\n' '\032' <<< "")" # ^Z [\x1a]
                        SPACE=" "                        #    [\x20]
                          TAB=$'\t'                      # ^I [\x09]
                   NEW_STRING=$'\n'                      #  $ [\x0a]
           CANONICAL_PRE_CODE="${CANONICAL_PRE_CODE:+"$MARKER_NEW_STRING"}"

    # open_block | cat -A
    # open_block
    # open_block | add_paragraph_to_list_item | cat -A
    # open_block | add_paragraph_to_list_item
    # open_block | add_paragraph_to_list_item | format_string | cat -A
    # open_block | add_paragraph_to_list_item | format_string
    # open_block | add_paragraph_to_list_item | format_string | combine_string_with_tag | cat -A
    # open_block | add_paragraph_to_list_item | format_string | combine_string_with_tag
    # open_block | add_paragraph_to_list_item | format_string | combine_string_with_tag | split_strings | cat -A
    open_block | add_paragraph_to_list_item | format_string | combine_string_with_tag | split_strings

    # open_block | add_paragraph_to_list_item | combine_string_with_tag | cat -A
    # open_block | add_paragraph_to_list_item | combine_string_with_tag
    # open_block | add_paragraph_to_list_item | combine_string_with_tag | split_strings | cat -A
    # open_block | add_paragraph_to_list_item | combine_string_with_tag | split_strings
    # open_block | add_paragraph_to_list_item | format_string | split_strings | cat -A
    # open_block | add_paragraph_to_list_item | format_string | split_strings
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

convert ()
{
    if is_empty "${ONLY_CONTENT:-}"
    then
        open_html
        add_title
        open_head
        add_style
        close_head
        open_body
        convert_md2html
        close_body
        close_html
    else
        convert_md2html
    fi
}

report_and_convert ()
{
    is_equal "$STDIN" "pipeline" &&
    say "converting stdin" >&2 ||
    say "converting a file: $INPUT" >&2
    convert >&3
    say "conversion completed" >&2
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

main "$@"
