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
    echo "${0##*/} ${1:-0.2.0} - (C) 28.06.2025

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
    is_empty "${PAGE_STYLE:-}" && GET_CODE_BLOCK_TAG="get_code_block_tag" || {
        is_file "$PAGE_STYLE" || {
            is_file "$PKG_DIR/style/${PAGE_STYLE%.css}.css" &&
            PAGE_STYLE="$PKG_DIR/style/${PAGE_STYLE%.css}.css"
        } || die 2 "no such file: -- '$PAGE_STYLE'"
        GET_CODE_BLOCK_TAG="get_code_block_tag_with_class"
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

combine_string ()
{
    #         example         | input | output  |
    #-------------------------|-------|---------|
    # - foo                   | foo   | <p>     |
    #        < - empty string |       | \x1ffoo |
    #   bar                   | bar   | </p>    |
    #-------------------------|-------| <p>     |
    #                                 | \x1fbar |
    #                                 | </p>    |
    #                                 |---------|

    sed '
        /^\x1f/!{
            # skip the created html tag and code
            b end_of_line
        }

        : combine_string
        /\x1f$/ {
            s%\x1f$%%g
            b remove_empty_line
        }
        $!N
        s%\n%\x01%
        t combine_string

        : remove_empty_line
        s%\x01\{2,\}%\x02%g
        s%\x01$%\x02%

        # add a break tag marker
        s%\( \{2,\}\|\\\)\x01%\x7f%g

        # remove spaces at the end of the line
        s% *\x01%\x01%g

        # if the list (<li>) contains an empty string,
        # add a paragraph tag
        /\x02/ {
            s%[[:blank:]]*\(\x02\)%\1%g
            s%\x02$%%
            s%^\(.*\)$%<p>\x18\n\1\n</p>\x19%
            s%\x02%\n</p>\x19\n<p>\x18\n\x1f%g
        }

        : end_of_line'
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
        s%\x7f%<br />\n%g
        s%"%\&quot;%g

        # delete empty strings
        s%\x01\x01\+%\x02%g

        : add_tag_p
        s%^\(\x1a[^\x1b]*\x1b[^\x02]*\)\x02%\1</p>\x01<p>%
        t add_tag_p
        s%^\x1a\([^\x1b]*\)\x1b\(.*\)$%\1<p>\2</p>%

        : end_of_line'
}

combine_string_with_tag ()
{
    sed '
        /\x18$/ {
            s%\x18$%%
            : combine_string
            $!N
            s/\n//
            /\x19$/ {
                s%\x19$%%
                b end_of_line
            }
            t combine_string
        }
        : end_of_line'
}

split_strings ()
{
    sed 's%\x01%\n%g'
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
    OPENING_TAG="<pre><code class=\"${CLASS:+fenced-code-block language-}${CLASS:-indented-$1}\">$MARKER_START_MERGE_STRING"
}

get_code_block_tag ()
{
    OPENING_TAG="<pre><code${CLASS:+ class=\"language-$CLASS\"}>$MARKER_START_MERGE_STRING"
}

get_tag ()
{
    case "$1" in
        code-block)
            $GET_CODE_BLOCK_TAG
            CLOSING_TAG="${CANONICAL_PRE_CODE:-}</code></pre>$MARKER_STOP_MERGE_STRING"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT=""
            get_tag_indent +
            ;;
        blockquote|li|ul)
            OPENING_TAG="<$1>"
            CLOSING_TAG="</$1>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
            get_tag_indent +
            ;;
        ol)
            OPENING_TAG="<$1${OL_START:+ start="$OL_START"}>"
            CLOSING_TAG="</$1>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
            get_tag_indent +
            ;;
        h[1-6])
            ID="${STRING,,}"
            ID="$(sed  ': merge
                        $!N
                        s%[\]*\n%-%
                        t merge
                        s/[[:blank:]]/-/g
                        s/[^a-zA-Z0-9_-]//g
                        s/-\+/-/g
                        s/\(^-\+\|-\+$\)//g' <<< "${ID:-}")"
            is_empty "${ID:-}" || {
                is_empty "${ID_BASE["$ID"]:-}" || ID="$ID-$((ID_NUM+1))"
                ID_BASE["$ID"]="$ID"
            }
            OPENING_TAG="<$1 class=\"${CLASS:-atx}\" id=\"${ID:-}\">$MARKER_START_MERGE_STRING"
            CLOSING_TAG="</$1>$MARKER_STOP_MERGE_STRING"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT=""
            ;;
        p)
            OPENING_TAG="<$1>$MARKER_START_MERGE_STRING"
            CLOSING_TAG="</$1>$MARKER_STOP_MERGE_STRING"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
    esac
    CLASS=
}

print_opening_tags ()
{
    is_empty "${!OPENING_TAG_BUFFER[@]}" || {
        TAG=
        for i in "${!OPENING_TAG_BUFFER[@]}"
        do
            TAG="${TAG:+$TAG$NEW_STRING}${OPENING_INDENT_BUFFER[$i]:-}${OPENING_TAG_BUFFER[$i]}"
        done
        OPENING_INDENT_BUFFER=()
        OPENING_TAG_BUFFER=()
        echo "${TAG:-}"
    }
}

print_closing_tags ()
{
    is_not_empty "${!CLOSING_TAG_BUFFER[@]}" || return 0

    if is_not_empty "${1:-}"
    then
        is_diff "$1" 0 || return 0

        SHIFT="$1"
        TAG=
        for i in $(seq 1 $SHIFT)
        do
            TAG="${TAG:+$TAG$NEW_STRING}${CLOSING_INDENT_BUFFER[-1]:-}${CLOSING_TAG_BUFFER[-1]}"
            unset -v "CURRENT_BLOCK[-1]" "CLOSING_TAG_BUFFER[-1]" "CLOSING_INDENT_BUFFER[-1]"
        done
        # STRING_NESTING_DEPTH="$((STRING_NESTING_DEPTH-SHIFT))"
        # TAG_INDENT="${TAG_INDENT%"$(printf "%$((TAG_INDENT_WIDTH*SHIFT+2))s" '')"}"
    else
        TAG=
        for i in "${!CLOSING_TAG_BUFFER[@]}"
        do
            TAG="${CLOSING_INDENT_BUFFER[$i]:-}${CLOSING_TAG_BUFFER[$i]}${TAG:+$NEW_STRING$TAG}"
        done
        CLOSING_INDENT_BUFFER=()
        CLOSING_TAG_BUFFER=()
        # STRING_NESTING_DEPTH=
        TAG_INDENT="${MAIN_TAG_INDENT:-}"
    fi
    echo "${TAG:-}"
}

put_tag_in_buffer ()
{
    OPENING_INDENT_BUFFER=( "${OPENING_INDENT_BUFFER[@]}" "${OPENING_TAG_INDENT:-}" )
    CLOSING_INDENT_BUFFER=( "${CLOSING_INDENT_BUFFER[@]}" "${CLOSING_TAG_INDENT:-}" )

    OPENING_TAG_BUFFER=( "${OPENING_TAG_BUFFER[@]}" "$OPENING_TAG" )
    CLOSING_TAG_BUFFER=( "${CLOSING_TAG_BUFFER[@]}" "$CLOSING_TAG" )

    OPENING_TAG=
    CLOSING_TAG=
}

get_string_buffer ()
{
    is_empty "${STRING_BUFFER:-}" || {
        if is_equal "${CODE_BLOCK:-"${INDENT_CODE_BLOCK:-}"}" "open"
        then
            STRING_BUFFER="${STRING_BUFFER//"$NEW_STRING"/"$MARKER_NEW_STRING"}"
        else
            if is_empty "${!CURRENT_BLOCK[@]}"
            then
                STRING_BUFFER="$MARKER_FORMAT_STRING$MARKER_ADD_TAG_P${BUFFER_INDENT:-}$POSITION_TAG_P$STRING_BUFFER$MARKER_FORMAT_STRING"
                BUFFER_INDENT=
            else
                is_diff "${CURRENT_BLOCK[-1]}" "block_quote" || {
                    get_tag p
                    put_tag_in_buffer
                }
                STRING_BUFFER="$MARKER_FORMAT_STRING${BUFFER_INDENT:-}$STRING_BUFFER$MARKER_FORMAT_STRING"
            fi
        fi
        STRING_BUFFER="${STRING_BUFFER%"${STRING_BUFFER##*[![:space:]]}"}$NEW_STRING"
    }
}

print_buffer ()
{
    get_string_buffer
    print_opening_tags
    echo -n "${STRING_BUFFER:-}"
    print_closing_tags "${1:-}"
    reset_block_variables
}

put_string_in_buffer ()
{
    is_empty "${STRING_BUFFER:-}" && {
        is_empty "${!CLOSING_INDENT_BUFFER[@]}" || TAG_INDENT="${CLOSING_INDENT_BUFFER[-1]}"
        BUFFER_INDENT="${TAG_INDENT:-}"
        STRING_BUFFER="$STRING"
    } || {
        STRING_BUFFER="$STRING_BUFFER$NEW_STRING${BUFFER_INDENT:-}${STRING:-}"
    }
    STRING=
}

put_string_in_buffer ()
{
    STRING_BUFFER="${STRING_BUFFER:+"$STRING_BUFFER$NEW_STRING"}${STRING:-}"
    STRING=
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

trim_string ()
{
    STRING="$(sed 's%^\(\x09\|\x20\{4\}\|\x20\{1,3\}\x09\)%%' <<< "$STRING")"
}

read_an_empty_string ()
{
    string_is_empty "${STRING:-}" || return 0
    is_not_empty "${!CURRENT_BLOCK[@]}" || return

    if is_not_empty "${BLOCK_QUOTE:-}"
    then
        close_block_quote
    elif is_not_empty "${LIST_ITEM:-}"
    then
        STRING=""
        put_string_in_buffer
        return 1
    elif is_equal "${CODE_BLOCK:-"${INDENT_CODE_BLOCK:-}"}" "open"
    then
        trim_string
        put_string_in_buffer
        return 1
    else
        return 1
    fi
}

trim_indent ()
{
    TRIM_SPACE="${1:-4}"
    CHARACTER_POSITION="${2:-"${CHAR_NUM:-0}"}"
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
}

expand_indent ()
{
    CHARACTER_POSITION="${1:-0}"
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
    string_is_empty "${STRING:-}" || {
        INDENT="${STRING%%[![:blank:]]*}"
        INDENT_LENGTH="$(expand_indent "$CHAR_NUM")"
        INDENT_LENGTH="${INDENT_LENGTH%%[![:blank:]]*}"
        INDENT_LENGTH="${#INDENT_LENGTH}"
        return
    }
    return 1
}

is_beginning_of_string ()
{
    is_equal "$CHAR_NUM" 0
}

parse_indent ()
{
    get_indent || return
    if test "$INDENT_LENGTH" -lt 4
    then
        if is_beginning_of_string
        then
            close_indent_code_block
        else
            is_equal "${PREFIX_INDENT:-0}" 0 || PREFIX_INDENT="$((PREFIX_INDENT + INDENT_LENGTH))"
        fi
    else
        is_empty "${!CURRENT_BLOCK[@]}" && {
            if is_empty "${STRING_BUFFER:-}"
            then
                open_indent_code_block
            else
                put_string_in_buffer
            fi
            return 1
        } ||
        case "${CURRENT_BLOCK[-1]}" in
            block_quote)
                is_beginning_of_string || {
                    open_indent_code_block
                    return 1
                }
                ;;
            indent_code_block)
                trim_indent 4
                put_string_in_buffer
                return 1
                ;;
            unordered_list)
                if is_beginning_of_string
                then
                    if is_empty "${STRING_BUFFER:-}"
                    then
                        if test "$INDENT_LENGTH" -ge "$PREFIX_INDENT"
                        then
                            test "$((INDENT_LENGTH - PREFIX_INDENT))" -lt 4 || {
                                open_indent_code_block "$((INDENT_LENGTH + PREFIX_INDENT))"
                                return 1
                            }
                        else
                            print_buffer
                            open_indent_code_block
                            return 1
                        fi
                    else
                        if test "$INDENT_LENGTH" -ge "$PREFIX_INDENT"
                        then
                            test "$INDENT_LENGTH" -le "$((PREFIX_INDENT + 3))" || {
                                print_buffer 0
                                open_indent_code_block "$((INDENT_LENGTH - PREFIX_INDENT))"
                                return 1
                            }
                        else
                            put_string_in_buffer
                            return 1
                        fi
                    fi
                else
                    open_indent_code_block
                    return 1
                fi
                ;;
        esac
    fi
    сut_indent
}

сut_indent ()
{
    STRING="${STRING#"${INDENT:-}"}"
}

read_block_structure ()
{
    CHAR_NUM=0
    STRING_NESTING_DEPTH=-1
    PREFIX_INDENT="${PREFIX_INDENT:-0}"

    while is_not_empty "${STRING:-}"
    do
        parse_indent || return
        CHAR_NUM="$((CHAR_NUM + INDENT_LENGTH + 1))"
        case "$STRING" in
            \>*)
                open_block_quote
                CHAR_NUM="$((CHAR_NUM + 1))"
                ;;
            [#]*)
                print_heading_atx || put_string_in_buffer
                return 1
                ;;
            [=]*)
                is_not_empty "${STRING_BUFFER:-}" &&
                    print_heading_setext_h1 || put_string_in_buffer
                return 1
                ;;
            [-]*)
                is_not_empty "${STRING_BUFFER:-}" &&
                    print_heading_setext_h2 && return 1 ||
                if [[ "$(tr -d '[:blank:]' <<< "${STRING:-}")" =~ ^\-{3,}$ ]]
                then
                    print_horizontal_rule
                    return 1
                else
                    [[ "${STRING:1}" =~ ^([[:blank:]]|$) ]] && {

                        if is_empty "${POSITION_LIST_ITEM:-}"
                        then
                            BULLET_CHAR="-"
                            POSITION_LIST_ITEM="$CHAR_NUM"
                            CHAR_NUM="$((CHAR_NUM + 1))"
                            open_unordered_list
                            open_list_item
                            PREFIX_INDENT="$((PREFIX_INDENT + CHAR_NUM))"
                            LIST_ITEM="${LIST_ITEM:-$STRING_NESTING_DEPTH}"
                        elif test "$CHAR_NUM" -le "$PREFIX_INDENT"
                        then
                            BULLET_CHAR="-"
                            POSITION_LIST_ITEM="$CHAR_NUM"
                            CHAR_NUM="$((CHAR_NUM + 1))"
                            print_buffer 1
                            open_list_item
                            PREFIX_INDENT="$CHAR_NUM"
                        else
                            test "$CHAR_NUM" -le $((PREFIX_INDENT + 4 )) && {
                                BULLET_CHAR="-"
                                POSITION_LIST_ITEM="$CHAR_NUM"
                                CHAR_NUM="$((CHAR_NUM + 1))"
                                print_buffer 0
                                open_unordered_list
                                open_list_item
                                PREFIX_INDENT="$CHAR_NUM"
                            }
                        fi

                    } || {
                        put_string_in_buffer
                        return 1
                    }
                fi
                ;;
            [*]*)
                if [[ "$(tr -d '[:blank:]' <<< "${STRING:-}")" =~ ^\*{3,}$ ]]
                then
                    print_horizontal_rule
                    return 1
                else
                    [[ "${STRING:1}" =~ ^([[:blank:]]|$) ]] && {
                        string_is_not_empty "${STRING:1}" ||
                        is_empty "${STRING_BUFFER:-}" && {
                            BULLET_CHAR="*"
                            INDENT_LENGTH=-1
                            open_list
                        }
                    } || {
                        put_string_in_buffer
                        return 1
                    }
                fi
                ;;
            [+]*)
                [[ "${STRING:1}" =~ ^([[:blank:]]|$) ]] && {
                    string_is_not_empty "${STRING:1}" ||
                    is_empty "${STRING_BUFFER:-}" && {
                        BULLET_CHAR=+
                        INDENT_LENGTH=-1
                        open_list
                    }
                } || {
                    put_string_in_buffer
                    return 1
                }
                ;;
            *)
                return
        esac
        STRING="${STRING:1}"
        trim_indent 1 "$((CHAR_NUM - 1))"
    done
}

open_block_quote ()
{
    STRING_NESTING_DEPTH="$((STRING_NESTING_DEPTH + 1))"
    BLOCK_QUOTE="${BLOCK_QUOTE:-"$STRING_NESTING_DEPTH"}"
    CURRENT_BLOCK+=( "block_quote" )

    get_tag blockquote
    is_empty "${!CLOSING_TAG_BUFFER[@]}" || is_empty "${CLOSING_TAG_BUFFER[$STRING_NESTING_DEPTH]:-}" && {
        is_empty   "${STRING_BUFFER:-}"  || print_buffer 0
    } || {
        if is_equal "${CLOSING_TAG_BUFFER[$STRING_NESTING_DEPTH]}" "$CLOSING_TAG"
        then
            return 0
        else
            print_buffer "$((${#CLOSING_TAG_BUFFER[@]} - STRING_NESTING_DEPTH))"
        fi
    }
    put_tag_in_buffer
}

close_block_quote ()
{
    print_buffer "$BLOCK_QUOTE"
}

open_unordered_list ()
{
    CURRENT_BLOCK+=( "unordered_list" )
    get_tag ul
    put_tag_in_buffer
}

open_list_item ()
{
    get_tag li
    put_tag_in_buffer
}

open_list ()
{
    STRING_NESTING_DEPTH="$((STRING_NESTING_DEPTH + 1))"
    LIST_ITEM="${LIST_ITEM:-$STRING_NESTING_DEPTH}"

    is_empty "${!CLOSING_TAG_BUFFER[@]}" && {
        open_unordered_list
        open_list_item
    } || {
        is_empty "${CLOSING_TAG_BUFFER[$STRING_NESTING_DEPTH]:-}" && {
            is_empty "${STRING_BUFFER:-}" || print_buffer 0
            open_unordered_list
            open_list_item
        }
    } || {
        get_tag ul
        if is_equal "${CLOSING_TAG_BUFFER[$STRING_NESTING_DEPTH]:-}" "$CLOSING_TAG"
        then
            print_buffer 1
            open_list_item
        else
            print_buffer "$((${#CLOSING_TAG_BUFFER[@]} - STRING_NESTING_DEPTH))"
            put_tag_in_buffer
            open_list_item
        fi
    }

    STRING_NESTING_DEPTH="$((STRING_NESTING_DEPTH + 1))"
}

is_code_block ()
{
    if is_empty "${FENCE_CHAR:-}"
    then
        [[ "${STRING:-}" =~ ^\`{3,}[^\`]*$ ]] ||
        [[ "${STRING:-}" =~  ^~{3,}        ]] && {
            FENCE_CHAR="${STRING%%[!~\`]*}"
            FENCE_LENGTH="${#FENCE_CHAR}"
            CLASS="${STRING#"$FENCE_CHAR"}"
            CLASS="${CLASS#"${CLASS%%[![:blank:]]*}"}"
            CLASS="${CLASS%%[[:blank:]]*}"
            CLASS="${CLASS,,}"
            FENCE_CHAR="${FENCE_CHAR:0:1}"
        }
    else
        [[ "${STRING:-}" =~ ^$FENCE_CHAR{$FENCE_LENGTH,}[[:blank:]]*$ ]]
    fi
}

open_code_block ()
{
    get_tag code-block
    put_tag_in_buffer
    CODE_BLOCK="open"
}

close_code_block ()
{
    case "${1:-}" in
        close_all)
            print_buffer
            ;;
        *)
            print_buffer 1
    esac
    FENCE_CHAR=
    INDENTED_CODE_BLOCK="closed"
             CODE_BLOCK="closed"
}

add_to_code_block ()
{
    if is_equal "${CODE_BLOCK:-}" "open"
    then
        is_empty "${INDENTED_CODE_BLOCK:-}" &&
        is_code_block  &&  close_code_block ||
        STRING_BUFFER="${STRING_BUFFER:+"$STRING_BUFFER$NEW_STRING"}${STRING:-}"
    else
        is_code_block && {
            is_empty "${STRING_BUFFER:-}" || print_buffer
            open_code_block
        }
    fi
}

open_indent_code_block ()
{
    CURRENT_BLOCK+=( "indent_code_block" )
    INDENT_CODE_BLOCK="open"
    trim_indent "${1:-4}"
    get_tag code-block
    put_tag_in_buffer
    put_string_in_buffer
}

close_indent_code_block ()
{
    is_empty "${INDENT_CODE_BLOCK:-}" || print_buffer 1
}

trim_white_space ()
{
    STRING="${STRING#"${STRING%%[![:blank:]]*}"}"
    STRING="${STRING%"${STRING##*[![:blank:]]}"}"
}

print_heading ()
{
    print_buffer 0
    trim_white_space
    get_tag "$TAG_HEADER"
    put_tag_in_buffer
    put_string_in_buffer
    CURRENT_BLOCK+=( "heading" )
    print_buffer 1
}

print_heading_atx ()
{
    [[ "${STRING:-}" =~ ^#{1,6}([[:blank:]].*|$) ]] && {
        HEADER="${STRING%%[[:blank:]]*}"
        STRING="${STRING#"$HEADER"}"
        TAG_HEADER="h${#HEADER}"
        CLASS="atx"
        print_heading
    }    
}

print_heading_setext_h1 ()
{
    
    [[ "${STRING:-}" =~ ^=+$ ]] && {
        STRING="$STRING_BUFFER" STRING_BUFFER=
        TAG_HEADER="h1"
        CLASS="setext"
        print_heading
    }
}

print_heading_setext_h2 ()
{
    [[ "${STRING:-}" =~ ^-+$ ]] && {
        STRING="$STRING_BUFFER" STRING_BUFFER=
        TAG_HEADER="h2"
        CLASS="setext"
        print_heading
    }
}

print_horizontal_rule ()
{
    STRING="${TAG_INDENT:-}<hr />$NEW_STRING"
    is_empty "${STRING_NESTING_DEPTH:-}" &&
    print_buffer ||
    print_buffer 0
    echo -n "$STRING"
}

reset_block_variables ()
{
    STRING_BUFFER=
    INDENT_CODE_BLOCK=
    CODE_BLOCK=
    BLOCK_QUOTE=
    LIST_ITEM=
}

convert_md2html ()
{
    PREFIX_INDENT=
    TAG_INDENT_WIDTH=0
    MAIN_TAG_INDENT=""

    OPENING_TAG_BUFFER=()
    CLOSING_TAG_BUFFER=()
    OPENING_INDENT_BUFFER=()
    CLOSING_INDENT_BUFFER=()

    CURRENT_BLOCK=()
    reset_block_variables

    ID_NUM=0
    declare -A ID_BASE

    MARKER_START_MERGE_STRING="$(tr '\n' '\030' <<< "")" # ^X [\x18]
     MARKER_STOP_MERGE_STRING="$(tr '\n' '\031' <<< "")" # ^Y [\x19]
         MARKER_FORMAT_STRING="$(tr '\n' '\037' <<< "")" # ^_ [\x1f]
            MARKER_NEW_STRING="$(tr '\n' '\001' <<< "")" # ^A [\x01]
                MARKER_TAG_BR="$(tr '\n' '\177' <<< "")" # ^? [\x7f]
             MARKER_ADD_TAG_P="$(tr '\n' '\032' <<< "")" # ^Z [\x1a]
               POSITION_TAG_P="$(tr '\n' '\033' <<< "")" # ^[ [\x1b]
                        SPACE=" "                        #    [\x20]
                          TAB=$'\t'                      # ^I [\x09]
                   NEW_STRING=$'\n'                      #  $ [\x0a]

    is_empty "${CANONICAL_PRE_CODE:-}" || CANONICAL_PRE_CODE="$MARKER_NEW_STRING"
    {
        while IFS= read -r STRING || is_not_empty "${STRING:-}"
        do
            TAG_INDENT="${MAIN_TAG_INDENT:-}"
            read_an_empty_string  &&
            read_block_structure  || continue
            add_to_code_block     ||
            put_string_in_buffer
        done < <(cat "${INPUT:--}")
        if is_equal "${CODE_BLOCK:-}" "open"
        then
            close_code_block close_all
        else
            print_buffer
        fi
    # } | cat -A
    # } | combine_string | cat -A
    # } | combine_string | combine_string_with_tag | cat -A
    # } | combine_string | format_string | combine_string_with_tag | split_strings | cat -A
    } | combine_string | format_string | combine_string_with_tag | split_strings
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
