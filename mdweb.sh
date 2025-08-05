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
    echo "${0##*/} ${1:-0.6.25} - (C) 05.08.2025

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
                    return
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
    RETURN="0"
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
                                RETURN="1"
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

get_code_block_tag_with_class ()
{
    OPENING_TAG="<pre><code class=\"${CLASS:+fenced-code-block language-}${CLASS:-indented-code-block}\">$MERGE_START_MARKER"
}

get_code_block_tag ()
{
    OPENING_TAG="<pre><code${CLASS:+ class=\"language-$CLASS\"}>$MERGE_START_MARKER"
}

get_heading_id ()
{
    #             ┌─> sequence of incoming strings
    #
    # Line ────── 1 ─┬─> get_heading_id ─> line-header-h2
    # header h2 ─ 2 ─┘
    # -------

    sed '
        # The following tasks are solved here:
        # - merge lines of a multi-line header by replacing the newline
        #   character with '-' to create the header ID;

        # List of symbols used:
        #       `\x0a` - `newline`

        : add_next_line
        $!N
        s%\x0a%-%
        t add_next_line

        # replace spaces with the '-' character
        s%[[:blank:]]%-%g

        # remove punctuation characters
        s%[^a-zA-Z0-9_-]%%g

        # replace duplicate '-' characters with one
        s%-\+%-%g

        # remove the '-' character at the beginning and end
        s%\(^-\|-$\)%%g

        # all in lowercase
        s%.*%\L&%g
    '
}

is_new_id ()
{
    is_empty "${ID_BASE:-}" || {
        for i in $ID_BASE
        do
            is_diff "$ID" "$i" || return
        done
    }
}

get_heading_tag_with_class ()
{
    ID="$(get_heading_id <<< "${LINE:-}")"
    is_empty "${ID:-}" || {
        is_new_id || ID="$ID-$(( ${ID_NUM:=0} + 1 ))"
        ID_BASE="${ID_BASE:+"$ID_BASE$NEW_LINE"}$ID"
    }
    OPENING_TAG="<$1 class=\"${CLASS:-atx}\" id=\"${ID:-}\">$MERGE_START_MARKER"
}

get_heading_tag ()
{
    OPENING_TAG="<$1>$MERGE_START_MARKER"
}

get_tag_indent ()
{
    case "$1" in
        -) TAG_INDENT="$(printf "%$((${#TAG_INDENT} - ${2:-"${TAG_INDENT_WIDTH:="2"}"}))s" '')" ;;
        +) TAG_INDENT="$(printf "%$((${#TAG_INDENT} + ${2:-"${TAG_INDENT_WIDTH:="2"}"}))s" '')" ;;
    esac
}

get_tag ()
{
    case "$1" in
        blockquote|ul)
            OPENING_TAG="<$1>"
            CLOSING_TAG="</$1>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
            get_tag_indent +
            ;;
        ol)
            OPENING_TAG="<$1${OL_START:+ start=\"$OL_START\"}>"
            CLOSING_TAG="</$1>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
            OL_START=
            get_tag_indent +
            ;;
        li)
            OPENING_TAG="<$1>$MERGE_START_MARKER"
            CLOSING_TAG="$MERGE_STOP_MARKER</$1>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${TAG_INDENT:-}"
            get_tag_indent +
            ;;
        paragraph)
            OPENING_TAG="<p>$MERGE_START_MARKER"
            CLOSING_TAG="$MERGE_STOP_MARKER</p>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT=
            ;;
        code_block)
            $GET_CODE_BLOCK_TAG
            CLOSING_TAG="$MERGE_STOP_MARKER${CANONICAL_PRE_CODE:-}</code></pre>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT="${CANONICAL_PRE_CODE:+"${TAG_INDENT:-}"}"
            CLASS=
            get_tag_indent +
            ;;
        h[1-6])
            $GET_HEADING_TAG "$1"
            CLOSING_TAG="$MERGE_STOP_MARKER</$1>"
            OPENING_TAG_INDENT="${TAG_INDENT:-}"
            CLOSING_TAG_INDENT=
            CLASS=
            ;;
    esac
}

put_in_tag_block ()
{
    OPENING_INDENT_BLOCK["$LEVEL"]="${OPENING_TAG_INDENT:-}"
    CLOSING_INDENT_BLOCK["$LEVEL"]="${CLOSING_TAG_INDENT:-}"

    OPENING_TAG_BLOCK["$LEVEL"]="$OPENING_TAG"
    CLOSING_TAG_BLOCK["$LEVEL"]="$CLOSING_TAG"

    OPENING_TAG=
    CLOSING_TAG=
}

put_tag_in_sub_block ()
{
    OPENING_INDENT_SUB_BLOCK["$LEVEL"]="${OPENING_TAG_INDENT:-}"
    CLOSING_INDENT_SUB_BLOCK["$LEVEL"]="${CLOSING_TAG_INDENT:-}"

    OPENING_TAG_SUB_BLOCK["$LEVEL"]="$OPENING_TAG"
    CLOSING_TAG_SUB_BLOCK["$LEVEL"]="$CLOSING_TAG"

    OPENING_TAG=
    CLOSING_TAG=
}

remove_last_empty_lines ()
{
    STRING_BLOCK[-1]="${STRING_BLOCK[-1]%"${STRING_BLOCK[-1]##*[!$NEW_LINE]}"}"
}

mark_a_string_block ()
{
    STRING_BLOCK[-1]="${STRING_BLOCK[-1]:+"$PARAGRAPH_MARKER${STRING_BLOCK[-1]}$PARAGRAPH_MARKER"}"
}

get_paragraph ()
{
    get_tag "paragraph"
    put_in_tag_block
    remove_last_empty_lines
    BLOCK_TYPE["${LEVEL:-0}"]="paragraph"
    NESTING_DEPTH["${LEVEL:-0}"]=
}

string_block_is_empty ()
{
    is_empty "${!STRING_BLOCK[@]}"
}

no_open_blocks ()
{
    is_empty "${!BLOCK_TYPE[@]}"
}

get_string_block ()
{
    string_block_is_empty || {
        if no_open_blocks
        then
            get_paragraph
            mark_a_string_block
        else
            case "${BLOCK_TYPE[-1]}" in
                "indent_code_block")
                    remove_last_empty_lines
                    STRING_BLOCK[-1]="$CODE_MARKER${STRING_BLOCK[-1]}$CODE_MARKER"
                    ;;
                "code_block")
                    STRING_BLOCK[-1]="$CODE_MARKER${STRING_BLOCK[-1]}$CODE_MARKER"
                    ;;
                "block_quote")
                    remove_last_empty_lines
                    is_empty "${STRING_BLOCK[-1]:-}" || {
                        [[ "${STRING_BLOCK[-1]}" =~ "$NEW_LINE$NEW_LINE" ]] || {
                            SAVED_DEPTH="$LEVEL"
                            LEVEL="${#BLOCK_TYPE[@]}"
                            get_paragraph
                            LEVEL="$SAVED_DEPTH"
                        }
                        mark_a_string_block
                    }
                    ;;
                *)
                    test "$LEVEL" -ge "${!STRING_BLOCK[@]}" || remove_last_empty_lines
                    mark_a_string_block
            esac
        fi
        STRING_BLOCK[-1]="${STRING_BLOCK[-1]:+"${STRING_BLOCK[-1]}$NEW_LINE"}"
    }
}

print_opening_tags ()
{
    no_open_blocks || {
        TAG=
        for i in "${!NESTING_DEPTH[@]}"
        do
            is_empty "${OPENING_TAG_BLOCK[$i]:-}" ||
                TAG="${TAG:+$TAG$NEW_LINE}${OPENING_INDENT_BLOCK[$i]:-}${OPENING_TAG_BLOCK[$i]}"
            is_empty "${OPENING_TAG_SUB_BLOCK[$i]:-}" ||
                TAG="${TAG:+$TAG$NEW_LINE}${OPENING_INDENT_SUB_BLOCK[$i]:-}${OPENING_TAG_SUB_BLOCK[$i]}"
        done
        OPENING_INDENT_BLOCK=()
        OPENING_INDENT_SUB_BLOCK=()
        OPENING_TAG_BLOCK=()
        OPENING_TAG_SUB_BLOCK=()
        is_empty "${TAG:-}" || echo "$TAG"
    }
}

print_closing_tags ()
{
    no_open_blocks || {
        case "${1:-}" in
            "without closing tags")
                return
                ;;
        esac
        TAG=
        # get tags starting from the last one added
        for ((i=$((${#NESTING_DEPTH[@]} - 1)); i>=0; i--))
        do
            if test "$i" -ge "$LEVEL"
            then
                is_empty "${CLOSING_TAG_SUB_BLOCK[$i]:-}" || {
                    TAG="${TAG:+$TAG$NEW_LINE}${CLOSING_INDENT_SUB_BLOCK[$i]:-}${CLOSING_TAG_SUB_BLOCK[$i]}"
                    unset -v "CLOSING_TAG_SUB_BLOCK[-1]" "CLOSING_INDENT_SUB_BLOCK[-1]"
                    is_empty "${1:-}" || is_diff "$i" "$LEVEL" || break
                }

                TAG="${TAG:+$TAG$NEW_LINE}${CLOSING_INDENT_BLOCK[-1]:-}${CLOSING_TAG_BLOCK[-1]}"
                unset -v "BLOCK_TYPE[-1]" "NESTING_DEPTH[-1]" "CLOSING_TAG_BLOCK[-1]" "CLOSING_INDENT_BLOCK[-1]"
            else
                break
            fi
        done
        # TAG_INDENT="${TAG_INDENT%"$(printf "%$((TAG_INDENT_WIDTH*LEVEL+2))s" '')"}"
        is_empty "${TAG:-}" || echo "$TAG"
    }
}

finalize ()
{
    get_string_block
    print_opening_tags
    echo -n "${STRING_BLOCK[@]:-}"
    print_closing_tags "${1:-}"
    STRING_BLOCK=()
}

put_in_string_block ()
{
    STRING_BLOCK[-1]="${STRING_BLOCK[-1]:-}$NEW_LINE${BUFFER_INDENT:-}${LINE:-}"
}

open_string_block ()
{
    string_block_is_empty && {
        is_empty "${BLOCK_TYPE["$LEVEL"]:-}" || finalize
        is_empty "${!CLOSING_INDENT_BLOCK[@]}" || TAG_INDENT="${CLOSING_INDENT_BLOCK[-1]}"
        BUFFER_INDENT="${TAG_INDENT:-}"
        STRING_BLOCK["$LEVEL"]="${LINE:-}"
    } || {
        if [[ "${STRING_BLOCK[-1]}" =~ "$NEW_LINE"$ ]]
        then
            if is_empty "${BLOCK_TYPE["$LEVEL"]:-}"
            then
                if [[ "${STRING_BLOCK[-1]}" =~ ^"$NEW_LINE" ]]
                then
                    LEVEL="$((LEVEL - 1))"
                    finalize
                    STRING_BLOCK["$LEVEL"]="$LINE"
                elif [[ "${STRING_BLOCK[-1]}" =~ ^"$NEW_LINE" ]]
                then
                    STRING_BLOCK[-1]="${STRING_BLOCK[-1]#"$NEW_LINE"}$LINE"
                else
                    put_in_string_block
                fi
            else
                finalize
                STRING_BLOCK["$LEVEL"]="$LINE"
            fi
        else
            if is_empty "${STRING_BLOCK[-1]:-}"
            then
                STRING_BLOCK[-1]="$LINE"
            else
                put_in_string_block
            fi
        fi
    }
    LINE=
}

trim_indent ()
{
    is_not_empty "${LINE:-}" || return 0
    SAVED_STRING="$LINE"
    TRIM_SPACE="${1:-4}"
    CHARACTER_POSITION="${2:-0}"
    test "$CHARACTER_POSITION" -le 4 ||
    CHARACTER_POSITION=$(( CHARACTER_POSITION - $(( $(( CHARACTER_POSITION / 4 )) * 4 )) ))

    while is_not_empty "${LINE:-}"
    do
        is_diff "$TRIM_SPACE" 0 || break
        is_diff "$CHARACTER_POSITION" 4 &&
            CHARACTER_POSITION="$((CHARACTER_POSITION + 1))" ||
            CHARACTER_POSITION="1"
        case "$LINE" in
            $SPACE*)
                LINE="${LINE:1}"
                TRIM_SPACE="$((TRIM_SPACE - 1))"
                ;;
            $TAB*)
                TAB_LENGTH="$((4 -  $((CHARACTER_POSITION - 1))))"
                CHARACTER_POSITION="$((CHARACTER_POSITION - 1 + TAB_LENGTH))"
                if is_equal "$TRIM_SPACE" "$TAB_LENGTH"
                then
                    LINE="${LINE:1}"
                    break
                elif test "$TRIM_SPACE" -lt "$TAB_LENGTH"
                then
                    LINE="$(printf "%$((TAB_LENGTH - TRIM_SPACE))s")${LINE:1}"
                    break
                else
                    LINE="${LINE:1}"
                    TRIM_SPACE="$((TRIM_SPACE - TAB_LENGTH))"
                fi
                ;;
            *)
                break
        esac
    done
    is_diff "$SAVED_STRING" "${LINE:-}"
}

open_indent_code_block ()
{
    EXCESS_INDENT="${1:-4}"
    trim_indent "$EXCESS_INDENT" "$CHAR_NUM"
    get_tag "code_block"
    put_in_tag_block
    INDENT_CODE_BLOCK="open"
    BLOCK_TYPE["$LEVEL"]="indent_code_block"
    NESTING_DEPTH["$LEVEL"]="$CHAR_NUM:$EXCESS_INDENT"
    LEVEL="$((LEVEL + 1))"
    open_string_block
}

open_code_block ()
{
    get_tag "code_block"
    put_in_tag_block
    EXCESS_INDENT="${#INDENT}"
    CODE_BLOCK="open"
    BLOCK_TYPE["$LEVEL"]="code_block"
    NESTING_DEPTH["$LEVEL"]=
}

close_code_block ()
{
    finalize
    FENCE_CHAR=
    INDENTED_CODE_BLOCK="closed"
             CODE_BLOCK="closed"
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
        [[ "${LINE:-}" =~ ^[[:blank:]]*\`{3,}[^\`]*$ ]] ||
        [[ "${LINE:-}" =~ ^[[:blank:]]*~{3,} ]] && {
            FENCE_CHAR="${LINE%%[!~\`]*}"
            FENCE_LENGTH="${#FENCE_CHAR}"
            CLASS="${LINE#"$FENCE_CHAR"}"
            is_empty "${CLASS:-}" ||
                CLASS="$(serialize_pre_code_language <<< "$CLASS")"
            FENCE_CHAR="${FENCE_CHAR:0:1}"
        }
    else
        [[ "${LINE:-}" =~ ^[[:blank:]]*$FENCE_CHAR{$FENCE_LENGTH,}[[:blank:]]*$ ]]
    fi
}

add_to_code_block ()
{
    if is_equal "${BLOCK_TYPE["$LEVEL"]:-}" "code_block"
    then
        is_code_block && close_code_block "$LEVEL" || open_string_block
    else
        is_code_block && {
            is_empty "${BLOCK_TYPE["$LEVEL"]:-"${STRING_BLOCK["$LEVEL"]:-}"}" || finalize
            open_code_block
        }
    fi
}

open_list_item ()
{
    get_tag "li"
    put_tag_in_sub_block
}

open_unordered_list ()
{
    [[ "$LINE" =~ ^"$1"([[:blank:]]|$) ]] && {
        if is_equal "${BLOCK_TYPE["$LEVEL"]:-}" "$1"
        then
            finalize "close tags to the current list item"
        else
            string_block_is_empty || finalize
            BLOCK_TYPE["$LEVEL"]="$1"

            get_tag "ul"
            put_in_tag_block
        fi
        open_list_item
        BULLET_CHAR_NUM="$CHAR_NUM"
        if is_equal "$LEVEL" 0
        then
            NESTING_DEPTH["$LEVEL"]="$CHAR_NUM"
        else
            NESTING_DEPTH["$LEVEL"]="${NESTING_DEPTH["$((LEVEL - 1))"]#*:}"
        fi
        CHAR_NUM="$((CHAR_NUM + 1))"
        LEVEL="$((LEVEL + 1))"
    }
}

open_ordered_list ()
{
    if is_equal "${BLOCK_TYPE["$LEVEL"]:-}" "$1"
    then
        finalize "close tags to the current list item"
    else
        string_block_is_empty || finalize
        BLOCK_TYPE["$LEVEL"]="$1"

        OL_START="${LINE%%[!0-9]*}"
        LENGTH_ORDERED_LIST_NUM="${#OL_START}"
        is_equal "$LENGTH_ORDERED_LIST_NUM" 1 || OL_START="${OL_START#"${OL_START%%[!0]*}"}"
        is_diff "$OL_START" 1 || OL_START=

        get_tag "ol"
        put_in_tag_block
    fi
    open_list_item
    BULLET_CHAR_NUM="$CHAR_NUM"
    if is_equal "$LEVEL" 0
    then
        NESTING_DEPTH["$LEVEL"]="$CHAR_NUM"
    else
        NESTING_DEPTH["$LEVEL"]="${NESTING_DEPTH["$((LEVEL - 1))"]#*:}"
    fi
    CHAR_NUM="$((CHAR_NUM + 1 + LENGTH_ORDERED_LIST_NUM))"
    LEVEL="$((LEVEL + 1))"
}

open_block_quote ()
{
    # remember the first nesting depth of the block to close all tags,
    # including this block, when an empty string or other block occurs.
    BLOCK_QUOTE="${BLOCK_QUOTE:-"$LEVEL"}"
    is_equal "${BLOCK_TYPE["$LEVEL"]:-}" "block_quote" || {
        string_block_is_empty || finalize
        BLOCK_TYPE["$LEVEL"]="block_quote"

        get_tag "blockquote"
        put_in_tag_block
    }
    if is_equal "$LEVEL" 0
    then
        NESTING_DEPTH["$LEVEL"]="$CHAR_NUM"
    else
        NESTING_DEPTH["$LEVEL"]="${NESTING_DEPTH["$((LEVEL - 1))"]#*:}"
    fi
    CHAR_NUM="$((CHAR_NUM + 1))"
    LEVEL="$((LEVEL + 1))"
}

close_block_quote ()
{
    LEVEL="$BLOCK_QUOTE"
    finalize
    BLOCK_QUOTE=
    PRIMARY_INDENT="0"
}

trim_white_space ()
{
    LINE="${LINE#"${LINE%%[![:blank:]]*}"}"
    LINE="${LINE%"${LINE##*[![:blank:]]}"}"
}

print_heading ()
{
    finalize
    BLOCK_TYPE["$LEVEL"]="heading"
    NESTING_DEPTH["$LEVEL"]=
    trim_white_space
    get_tag "$1"
    put_in_tag_block
    LEVEL="$((LEVEL + 1))"
    is_empty "${LINE:-}" || open_string_block
    LEVEL="$((LEVEL - 1))"
    finalize
}

print_heading_atx ()
{
    [[ "${LINE:-}" =~ ^#{1,6}([[:blank:]].*|$) ]] && {
        HEADER="${LINE%%[[:blank:]]*}"
        LINE="$(sed 's%\(^#\+\|[[:blank:]]\+#*[[:blank:]]*$\)%%g' <<< "$LINE")"
        CLASS="atx"
        print_heading "h${#HEADER}"
    }
}

current_depth_string_block_is_empty ()
{
    is_empty "${STRING_BLOCK["$LEVEL"]:-}"
}

current_depth_string_block_is_not_empty ()
{
    current_depth_string_block_is_empty && return 1 || return 0
}

print_heading_setext ()
{
    current_depth_string_block_is_not_empty &&
    [[ "$LINE" =~ ^"$1"+[[:blank:]]*$ ]] && {
        LINE="${STRING_BLOCK[-1]}"
        unset -v "STRING_BLOCK[-1]"
        CLASS="setext"
        case "$1" in
            =) print_heading "h1" ;;
            -) print_heading "h2" ;;
        esac
    }
}

print_horizontal_rule ()
{
    [[ "${LINE//[[:blank:]]}" =~ ^"$1"{3,}$ ]] && {
        LINE="${TAG_INDENT:-}<hr />"
        is_equal "$LEVEL" 0  &&
                finalize || finalize "without closing tags"
        echo "$LINE"
    }
}

block_quote_is_closed ()
{
    is_empty "${BLOCK_QUOTE:-}"
}

code_block_is_closed ()
{
    is_diff "${CODE_BLOCK:-"${INDENT_CODE_BLOCK:-}"}" "open"
}

list_is_open ()
{
    [[ "${BLOCK_TYPE["$LEVEL"]}" =~ [\).*+-] ]]
}

parse_empty_string ()
{
    if no_open_blocks
    then
        # print a paragraph
        string_block_is_empty || finalize
    else
        if list_is_open
        then
            LINE=
            string_block_is_empty && open_string_block || put_in_string_block
        else
            if block_quote_is_closed
            then
                code_block_is_closed || {
                    # add an empty string to the code block
                    trim_indent "$EXCESS_INDENT"
                    string_block_is_empty && open_string_block || put_in_string_block
                }
            else
                close_block_quote
            fi
        fi
    fi
    return 1
}

line_is_empty ()
{
    case "${LINE:-}" in
        *[![:blank:]]*)
            return 1
    esac
}

line_is_not_empty ()
{
    line_is_empty && return 1 || return 0
}

expand_indent ()
{
    LINE="$1"
    CHARACTER_POSITION="${2:-0}"
    test "$CHARACTER_POSITION" -le 4 ||
    CHARACTER_POSITION=$(( CHARACTER_POSITION - $(( $(( CHARACTER_POSITION / 4 )) * 4 )) ))
    INDENT=
    while is_not_empty "${LINE:-}"
    do
        is_diff "$CHARACTER_POSITION" 4 &&
            CHARACTER_POSITION="$((CHARACTER_POSITION + 1))" ||
            CHARACTER_POSITION="1"
        case "$LINE" in
            $SPACE*)
                INDENT="${INDENT:-} "
                LINE="${LINE:1}"
                ;;
            $TAB*)
                TAB_LENGTH="$((4 -  $((CHARACTER_POSITION - 1))))"
                CHARACTER_POSITION="$((CHARACTER_POSITION - 1 + TAB_LENGTH))"
                INDENT="${INDENT:-}$(printf "%${TAB_LENGTH}s")"
                LINE="${LINE:1}"
                ;;
            *)
                break
        esac
    done
    echo "${INDENT:-}${LINE:-}"
}

get_indent ()
{
    line_is_not_empty || return
    INDENT="${LINE%%[![:blank:]]*}"
    INDENT_LENGTH="$(expand_indent "${LINE:-}" "$CHAR_NUM")"
    INDENT_LENGTH="${INDENT_LENGTH%%[![:blank:]]*}"
    INDENT_LENGTH="${#INDENT_LENGTH}"
}

parse_indent ()
{
    #    ┌>┌─────────────> LEVEL="0" BLOCK_TYPE[0]="-"                 NESTING_DEPTH[0]="3:6"
    #    │ │┌────────────> LEVEL="1" BLOCK_TYPE[1]="block_quote"       NESTING_DEPTH[1]="6:0"
    #    │ ││  ┌>--┌─────> LEVEL="2" BLOCK_TYPE[2]="*"                 NESTING_DEPTH[2]="3:5"
    #    │ ││  │   │┌>-┌─> LEVEL="3" BLOCK_TYPE[3]=")"                 NESTING_DEPTH[3]="5:4"
    #    │ ││  │   ││  │┌> LEVEL="4" BLOCK_TYPE[4]="indent_code_block" NESTING_DEPTH[4]="4:4"
    # ◦◦◦-◦◦>◦◦*◦◦◦◦12)◦◦◦◦◦foo
    if is_empty "${!BLOCK_TYPE[@]}"
    then
        #   ┌> the indent length is less than or equal to 4
        # ◦◦◦-◦◦>◦◦*◦◦◦◦12)◦◦◦◦◦foo
        test "$INDENT_LENGTH" -lt 4 || {
            # ┌───┬─> indent length greater than 4
            # ◦◦◦◦◦foo
            if current_depth_string_block_is_empty
            then
                open_indent_code_block
            else
                open_string_block
            fi
            return 1
        }
        PRIMARY_INDENT="$INDENT_LENGTH"
        return
    elif is_empty "${BLOCK_TYPE["$LEVEL"]:-}"
    then
        #     ┌┬─> the indent length is less than or equal to 4
        # ◦◦◦-◦◦>◦◦*◦◦◦◦12)◦◦◦◦◦foo
        if test "$INDENT_LENGTH" -le 3
        then
            if is_equal "${BLOCK_TYPE[-1]}" "block_quote"
            then
                #        ┌┬─> the indent is not added to "block_quote"
                # ◦◦◦-◦◦>◦◦*◦◦◦◦12)◦◦◦◦◦foo
                PRIMARY_INDENT="$INDENT_LENGTH"
                NESTING_DEPTH[-1]="${NESTING_DEPTH[-1]}:0"
            else
                #           ┌──┬─> the indent length is less than or equal to 4
                # ◦◦◦-◦◦>◦◦*◦◦◦◦12)◦◦◦◦◦foo
                # ◦-◦◦◦-◦◦◦foo
                NESTING_DEPTH[-1]="${NESTING_DEPTH[-1]}:$(( $(( CHAR_NUM + INDENT_LENGTH )) - BULLET_CHAR_NUM + PRIMARY_INDENT ))"
                PRIMARY_INDENT="0"
            fi
            return
        else
            #                  ┌───┬─> indent length greater than 4
            # ◦◦◦-◦◦>◦◦*◦◦◦◦12)◦◦◦◦◦foo
            NESTING_DEPTH[-1]="${NESTING_DEPTH[-1]}:$CHAR_NUM"
            if current_depth_string_block_is_empty
            then
                open_indent_code_block
            else
                open_string_block
            fi
            return 1
        fi
    else
        while true
        do
            case "${BLOCK_TYPE["$LEVEL"]}" in
                "code_block")
                    trim_indent "$EXCESS_INDENT"
                    if test "$INDENT_LENGTH" -lt 4
                    then
                        add_to_code_block
                    else
                        open_string_block
                    fi
                    return 1
                    ;;
                "indent_code_block")
                    if test "$INDENT_LENGTH" -lt 4
                    then
                        finalize
                        return
                    else
                        trim_indent "$EXCESS_INDENT"
                        put_in_string_block
                        return 1
                    fi
                    ;;
                "block_quote")
                    test "$INDENT_LENGTH" -lt 4 || {
                        if  string_block_is_empty ||
                            is_equal "${BLOCK_TYPE[-1]}" "indent_code_block"
                        then
                            finalize
                            open_indent_code_block
                        else
                            open_string_block
                        fi
                        return 1
                    }
                    return
            esac

            if test "$INDENT_LENGTH" -lt "${NESTING_DEPTH["$LEVEL"]#*:}"
            then
                test "$INDENT_LENGTH" -ge 4 || {
                    if is_equal "$LEVEL" 0
                    then
                        PRIMARY_INDENT="$INDENT_LENGTH"
                    else
                        NESTING_DEPTH[-1]="${NESTING_DEPTH[-1]}:$(( $(( CHAR_NUM + INDENT_LENGTH )) - BULLET_CHAR_NUM + PRIMARY_INDENT ))"
                        PRIMARY_INDENT="0"
                    fi
                    return 0
                }
                if string_block_is_empty
                then
                    # ┌───┬─> LEVEL="0" BLOCK_TYPE[0]="-" NESTING_DEPTH[0]="3:5" <┐
                    # ◦◦◦-                                                      │
                    # ┌──┬─> the current indent is less than the next nesting level
                    # ◦◦◦◦-◦◦◦◦bar (current string)
                    finalize
                    open_indent_code_block
                else
                    # ┌───┬─> LEVEL="0" BLOCK_TYPE[0]="-" NESTING_DEPTH[0]="3:5" <┐
                    # ◦◦◦-◦foo                                                  │
                    # ┌──┬─> the current indent is less than the next nesting level
                    # ◦◦◦◦-◦◦◦◦bar (current string)
                    if [[ "${STRING_BLOCK[-1]}" =~ "$NEW_LINE"$ ]]
                    then
                        finalize
                        open_indent_code_block
                    else
                        open_string_block
                    fi
                fi
                return 1
            elif test "$INDENT_LENGTH" -eq "${NESTING_DEPTH["$LEVEL"]#*:}"
            then
                # ┌───┬─> LEVEL="0" BLOCK_TYPE[0]="-" NESTING_DEPTH[0]="3:5" <┐
                # ◦◦◦-◦foo                                                  │
                # ┌───┬─> the current indent is equal to the next nesting level
                # ◦◦◦◦◦-◦◦◦◦bar (current string)
                LEVEL="$((LEVEL + 1))"
                return
            else
                if is_empty "${BLOCK_TYPE["$((LEVEL + 1))"]:-}"
                then
                    # ┌───┬─> LEVEL="0" BLOCK_TYPE[0]="-" NESTING_DEPTH[0]="3:5" <┐
                    # ◦◦◦-◦foo                                                  │
                    # ┌─────┬─> the current indent is no more than 3 spaces larger than the last nesting level
                    # ◦◦◦◦◦◦◦-◦◦◦◦bar (current string)
                    test "$INDENT_LENGTH" -le "$(( ${NESTING_DEPTH["$LEVEL"]#*:} + 3))" || {
                        if string_block_is_empty
                        then
                            is_diff "${BLOCK_TYPE["$LEVEL"]}" "block_quote" || finalize
                            LEVEL="$((LEVEL + 1))"
                            open_indent_code_block "$(( ${NESTING_DEPTH["$((LEVEL - 1))"]#*:} + 4))"
                        else
                            if [[ "${STRING_BLOCK[-1]}" =~ "$NEW_LINE"$ ]]
                            then
                                LEVEL="$((LEVEL + 1))"
                                case "${STRING_BLOCK[-1]}" in
                                    *[!$NEW_LINE]*)
                                        get_paragraph
                                        finalize
                                        ;;
                                    *)  STRING_BLOCK=()
                                esac
                                trim_indent  "${NESTING_DEPTH["$((LEVEL - 1))"]#*:}" "$CHAR_NUM"
                                CHAR_NUM="$(( ${NESTING_DEPTH["$((LEVEL - 1))"]#*:} +  CHAR_NUM ))"
                                get_indent
                                open_indent_code_block
                            else
                                put_in_string_block
                            fi
                        fi
                        return 1
                    }
                    LEVEL="$((LEVEL + 1))"
                    return
                else
                    #    ┌>--┌───────> LEVEL="0" BLOCK_TYPE[0]="*" NESTING_DEPTH[0]="3:8" <┐
                    #    │   │┌>-┌───> LEVEL="1" BLOCK_TYPE[1]="+" NESTING_DEPTH[1]="8:4"  │
                    #    │   ││  │┌>┌> LEVEL="2" BLOCK_TYPE[2]="-" NESTING_DEPTH[2]="4:3"  │
                    # ◦◦◦*◦◦◦◦+◦◦◦-◦◦foo                                                 │
                    # ┌──────────────┬─> the current indent is greater than the indent at the 0th nesting level
                    # ◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦◦-◦◦◦◦bar (current string)
                    LEVEL="$((LEVEL + 1))"
                    trim_indent  "${NESTING_DEPTH["$LEVEL"]%:*}" "$CHAR_NUM"
                    CHAR_NUM="$(( ${NESTING_DEPTH["$LEVEL"]%:*} +  CHAR_NUM ))"
                    get_indent
                    #    ┌>--┌───────> LEVEL="0" BLOCK_TYPE[0]="*" NESTING_DEPTH[0]="3:8" <┐
                    #    │   │┌>-┌───> LEVEL="1" BLOCK_TYPE[1]="+" NESTING_DEPTH[1]="8:4"  │
                    #    │   ││  │┌>┌> LEVEL="2" BLOCK_TYPE[2]="-" NESTING_DEPTH[2]="4:3"  │
                    # ◦◦◦*◦◦◦◦+◦◦◦-◦◦foo                                                 │
                    #         ┌──────┬─> the current indent is greater than the indent at the 1th nesting level
                    #         ◦◦◦◦◦◦◦◦-◦◦◦◦bar (LEVEL="1")
                    #             ┌──┬─> the current indent is greater than the indent at the 2th nesting level
                    #             ◦◦◦◦-◦◦◦◦bar (LEVEL="2")
                fi
            fi
        done
    fi
}

parse_block_structure ()
{
    LEVEL="0"
    CHAR_NUM="0"
    BULLET_CHAR_NUM="0"
    INDENT_LENGTH="0"
    PRIMARY_INDENT="0"
    TAG_INDENT="${MAIN_TAG_INDENT:-}"

    line_is_not_empty || parse_empty_string || return 0
    while  is_not_empty "${LINE:-}"
    do
          get_indent || break
        parse_indent || return 0
        LINE="${LINE#"${INDENT:-}"}"
        CHAR_NUM="$((CHAR_NUM + INDENT_LENGTH))"
        case "$LINE" in
            [_]*)
                print_horizontal_rule "_" || open_string_block
                return
                ;;
            [#]*)
                print_heading_atx || open_string_block
                return
                ;;
            [=]*)
                print_heading_setext "=" || open_string_block
                return
                ;;
            [-]*)
                print_heading_setext  "-" ||
                print_horizontal_rule "-" && return ||
                open_unordered_list   "-" || {
                    open_string_block
                    return
                }
                ;;
            [*]*)
                print_horizontal_rule "*" && return ||
                [[ "$LINE" =~ ^"*"[[:blank:]]+[![:blank:]] ]] ||
                current_depth_string_block_is_empty &&
                open_unordered_list "*" || {
                    open_string_block
                    return
                }
                ;;
            [+]*)
                is_not_empty "${NESTING_DEPTH[$((LEVEL+1))]:-}" ||
                [[ "$LINE" =~ ^"+"[[:blank:]]+[![:blank:]] ]] ||
                current_depth_string_block_is_empty  &&
                open_unordered_list "+" || {
                    open_string_block
                    return
                }
                ;;
             \>*)
                open_block_quote
                ;;
               *)
                [[ "$LINE" =~ ^[0-9]{1,9}[\).]([[:blank:]]|$) ]] && {
                [[ "$LINE" =~ ^[0-9]{1,9}[\).][[:blank:]]+[![:blank:]] ]] ||
                    current_depth_string_block_is_empty && {
                        [[ "$LINE" =~ ^[0-9]{1,9}\) ]] && open_ordered_list ")" || {
                        [[ "$LINE" =~ ^[0-9]{1,9}\. ]] && open_ordered_list "."  ; }
                        LINE="${LINE:"$LENGTH_ORDERED_LIST_NUM"}"
                    }
                } || {
                    add_to_code_block || open_string_block
                    return
                }
                ;;
        esac
        LINE="${LINE:1}"
        trim_indent 1 "$CHAR_NUM" && CHAR_NUM="$((CHAR_NUM + 1))" || true
    done
    no_open_blocks || {
        is_not_empty "${BLOCK_QUOTE:-}" ||
            NESTING_DEPTH[-1]="${NESTING_DEPTH[-1]}:$(( CHAR_NUM - BULLET_CHAR_NUM ))"
        LINE=
        open_string_block
    }
}

reset_container ()
{
    unset -v CONTAINER CONTAINER_TREE
    declare -A CONTAINER
    CONTAINER_TREE=()
}

container_is_empty ()
{
    is_empty "${!CONTAINER[@]}"
}

preparing_input ()
{
                        # replace NUL characters for security
    cat "${INPUT:--}" | sed 's%\x00%\xef\xbf\xbd%g'
}

open_block ()
{
    reset_container
    while IFS= read -r LINE || is_not_empty "${LINE:-}"
    do
        parse_block_structure
    done < <(preparing_input)
    no_open_blocks || {
        LEVEL="0"
        case "${BLOCK_TYPE[-1]}" in
            "code_block" | "indent_code_block")
                close_code_block
                die
        esac
    }
    finalize
}

prepare_code ()
{
    #       ┌────> sequence of incoming strings <────┐
    #       │                                        │
    #
    # ``` ─ 1 ─┐                ┌─ <pre><code>ˆ[ ─── 1 ─┐
    # < ─── 2 ─┤                ├─ ˆC< ───────────── 2 ─┤                  ┌─ <pre><code>ˆ[
    # ◦> ── 3 ─┼─> open_block ─>┼─  >ˆC ──────────── 3 ─┼─> prepare_code ─>┼─ ˆC&lt;ˆ@ &gt;ˆC
    # ``` ─ 4 ─┘                └─ ˆ]</code></pre> ─ 4 ─┘                  └─ ˆ]</code></pre>

    sed '
        # The following tasks are solved here:
        # - starting from the first `CODE_MARKER` marker found to the next,
        #   combine the lines into one by replacing the newline character with
        #   `NULL`;
        # - remove `CODE_MARKER`
        # - convert several characters;

        # List of symbols used:
        # `ˆC`, `\x03` - `CODE_MARKER`
        # `ˆ@`, `\x00` - `NULL`
        #       `\x0a` - `newline`

        # Skip all lines that are not code
        /^\x03/! b exit

        : add_next_line
        /\x03$/ b remove_marker
        $!N
        s%\x0a%\x00%
        b add_next_line

        : remove_marker
        s%\(^\x03\|\x03$\)%%g

        # convert characters
        s%&%\&amp;%g
        s%<%\&lt;%g
        s%>%\&gt;%g

        : exit
    '
}

prepare_paragraph ()
{
    #         ┌─> sequence of incoming strings <─┐
    #         │                                                             ┌─ <ul>
    #         │                     ┌─ <ul> ──── 1 ─┐                       ├─ <li>ˆ[
    #                               ├─ <li>ˆ[ ── 2 ─┤                       ├─ <p>ˆ[
    # -◦foo ─ 1 ─┐                  ├─ ˆPfoo ─── 3 ─┤                       ├─ ˆPfooˆ@bazˆP
    # ◦◦baz ─ 2 ─┤                  ├─ baz ───── 4 ─┤                       ├─ ˆ]</p>
    #  ────── 3 ─┼──> open_block ──>┼─  ──────── 5 ─┼─> prepare_paragraph ─>┼─ <p>ˆ[
    # ◦◦bar ─ 4 ─┘                  ├─ barˆP ─── 6 ─┤                       ├─ ˆPbarˆP
    #                               ├─ ˆ]</li> ─ 7 ─┤                       ├─ ˆ]</p>
    #                               └─ </ul> ─── 8 ─┘                       ├─ ˆ]</li>
    #                                                                       └─ </ul>

    sed '
        # The following tasks are solved here:
        # - starting from the first `PARAGRAPH_MARKER` marker found to the next,
        #   combine the lines into one by replacing the newline character with
        #   `NULL`;
        # - if there are empty lines, add <p> tag with merge markers;
        # - if the string has 2 spaces at the end or the last character `\`,
        #   then replace them with `TAG_BR_MARKER`;
        # - remove spaces from the end of each line

        # List of symbols used:
        # `ˆ[`, `\x1b` - `MERGE_START_MARKER`
        # `ˆ]`, `\x1d` - `MERGE_STOP_MARKER`
        # `ˆP`, `\x10` - `PARAGRAPH_MARKER`
        # `ˆB`, `\x02` - `TAG_BR_MARKER`
        # `ˆ@`, `\x00` - `NULL`
        #       `\x0a` - `newline`
        # `ˆZ`, `\x1a` - temporary character to indicate an empty string

        # Skip all lines that are not a paragraph
        /^\x10/! b exit

        : add_next_line
        /.\x10$/ b remove_empty_line
        $!N
        s%\x0a%\x00%
        b add_next_line

        : remove_empty_line
        s%\x00\{2,\}%\x1a%g

        # Add a break tag marker
        s%\( \{2,\}\|\\\)\x00%\x02%g

        # Remove spaces from the beginning and end of each line
        s%\([[:blank:]]\+\x00\|\x00[[:blank:]]\+\)%\x00%g

        # If the list (<li>) contains an empty string, add a paragraph tag
        /\x1a/ {
            /^\x10\x1a$/d
            s%[[:blank:]]*\(\x1a\)%\1%g
            s%\(^\x10\|\x10$\)%%g
            s%^\(.*\)$%<p>\x1b\x0a\x10\1\x10\x0a\x1d</p>%
            s%\x1a%\x10\x0a\x1d</p>\x0a<p>\x1b\x0a\x10%g
        }

        : exit
    '
}

format_paragraph ()
{
    # 1. search for single-line code
    #    1. masking escaped control characters before single-line code
    #    2. mask backslashes and control characters in code
    #    3. recognize single-line code and insert tags
    # 2. search for links
    #    1. control character masking map
    #       |   |   extra    |   need    |
    #       |---|------------|-----------|
    #       | ` | \x07  [ˆG] | \x1d [ˆ]] |
    #       | [ | \x11  [ˆQ] | \x1e [ˆˆ] |
    #       | ] | \x12  [ˆR] | \x0e [ˆN] |
    #       | ( | \x14  [ˆT] | \x1c [ˆ\] |
    #       | ) | \x15  [ˆU] | \x0c [ˆL] |
    #       |---|------------|-----------|
    #       [[^][)(]*]([[:blank:]]*[^][)([:blank:]]*[[:blank:]]*)

    sed '
        # Skip all lines that are not a paragraph
        /^\x10/! b exit

        # remove PARAGRAPH_MARKER
        s%\(^\x10\|\x10$\)%%g
        b add_tag_code

        : mask_escaped_characters
        s%\\\\%\x7f%g
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
        /^[^[`]*\!\?\[[^]]*]([^)]*[\x7f\\\x04\x05\x07\x11\x12\x16#\x17|"?^{}_~*][^)]*)/ {

            # string: word [ name link ]( link* )
            # match : {word [ name link ]( link}*{ )}

            : mask_link
            s%^\([^[`]*\!\?\[[^]]*]([^)\x7f]*\)\x7f\([^)]*)\)%\1\%5C\2%
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
        s%\x7f%\\%g
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
        s%"%\&quot;%g

        : exit
    '
}

combine_with_tag ()
{
    #             ┌─> sequence of incoming strings <─┐
    #                                                │
    # <ul> ─────  1 ─┐                               │
    # <li>ˆ[ ───  2 ─┤
    # <p>ˆ[ ────  3 ─┤                            ┌─ 1 ─ <ul>
    # fooˆ@baz ─  4 ─┤                            ├─ 2 ─ <li>
    # ˆ]</p> ───  5 ─┤                            ├─ 3 ─ <p>fooˆ@baz</p>
    # <p>ˆ[ ────  6 ─┼────> combine_with_tag ────>┼─ 4 ─ <p>bar</p>
    # bar ──────  7 ─┤                            ├─ 5 ─ </li>
    # ˆ]</p> ───  8 ─┤                            └─ 6 ─ </ul>
    # ˆ]</li> ──  9 ─┤
    # </ul> ──── 10 ─┘

    sed '
        # The following tasks are solved here:
        # - merge lines with the opening and closing tags by removing the merge
        #   markers and newline characters between them;
        # - before the closing tag if necessary you must save the newline
        #   character by converting `CANONICAL_PRE_CODE` to `NULL`

        # List of symbols used:
        # `ˆ[`, `\x1b` - `MERGE_START_MARKER`
        # `ˆ]`, `\x1d` - `MERGE_STOP_MARKER`
        # `ˆP`, `\x10` - `PARAGRAPH_MARKER`
        # `ˆC`, `\x03` - `CODE_MARKER`
        # `ˆN`, `\x0e` - `CANONICAL_PRE_CODE`
        # `ˆ@`, `\x00` - `NULL`
        #       `\x0a` - `newline`

        # If the `</p>` tag is nested in the `</li>` tag,
        # the `</li>` and `</p>` tags must be on different lines
        s%^\x1d%%

        # Waiting for the opening tag with `MERGE_START_MARKER` at the end
        /\x1b$/! b exit

        : add_next_line
        $!N

        # In case `<li>ˆ[<p>ˆ[...` or `<li>ˆ[<pre><code>ˆ[...`,
        # remove `MERGE_START_MARKER` from the tag `<li>`
        /\x1b$/ {
            s%^\([^\x1b]\+\)\x1b%\1%
            b add_next_line
        }

        # Waiting for the closing tag with `MERGE_STOP_MARKER` at the beginning
        /\x0a\x1d/ {
            # If the `list item` or `code block` is empty:
            s%\x1b\x0a\x1d\x0e\?%%g
            t exit

            # If the `list item` or `code block` is not empty:
            s%\x1b\x0a%%
            s%\x0a\x1d\x0e%\x00%
            s%\x0a\x1d%%
            b exit
        }

        b add_next_line

        # : split_tag
        # s%^\([^\x1b]\+\)\x1b\(\(<\(script\|pre\|textarea\|style\)[[:blank:]]*\(>\|$\)\)\|<!--\|<?\|<![A-Za-z]\|<\!\[CDATA\[\|</\?\(address\|article\|aside\|base\|basefont\|blockquote\|body\|caption\|center\|col\|colgroup\|dd\|details\|dialog\|dir\|div\|dl\|dt\|fieldset\|figcaption\|figure\|footer\|form\|frame\|frameset\|h[123456]\|head\|header\|hr\|html\|iframe\|legend\|li\|link\|main\|menu\|menuitem\|nav\|noframes\|ol\|optgroup\|option\|p\|param\|section\|source\|summary\|table\|tbody\|td\|tfoot\|th\|thead\|title\|tr\|track\|ul\)[[:blank:]]*\(/\?>\|$\)\)%\1\x00\2%

        : exit
    '
}

split ()
{
    #                   ┌─> sequence of incoming strings <─┐
    #
    # <ul> ──────────── 1 ─┐                            ┌─ 1 ─ <ul>
    # <li> ──────────── 2 ─┤                            ├─ 2 ─ <li>
    # <p>fooˆ@baz</p> ─ 3 ─┤                            ├─ 3 ─ <p>foo
    # <p>bar</p> ────── 4 ─┼──────────> split ─────────>┼─ 4 ─ baz</p>
    # </li> ─────────── 5 ─┤                            ├─ 5 ─ <p>bar</p>
    # </ul> ─────────── 6 ─┘                            ├─ 6 ─ </li>
    #                                                   └─ 7 ─ </ul>

    sed '
        # The following tasks are solved here:
        # - return paragraph and code line separators by replacing the `NULL`
        #   character with a newline;

        # List of symbols used:
        # `ˆ@`, `\x00` - `NULL`
        #       `\x0a` - `newline`

        s%\x00%\x0a%g
    '
}

# The main parsing function.  Returns a parsed document HTML.
parse ()
{
    PREFIX_INDENT=
    TAG_INDENT_WIDTH="0"
    MAIN_TAG_INDENT=

    BLOCK_TYPE=()
    NESTING_DEPTH=()

    OPENING_TAG_BLOCK=()
    CLOSING_TAG_BLOCK=()
    OPENING_INDENT_BLOCK=()
    CLOSING_INDENT_BLOCK=()

    OPENING_TAG_SUB_BLOCK=()
    OPENING_INDENT_SUB_BLOCK=()

    STRING_BLOCK=()
    INDENT_CODE_BLOCK=
    CODE_BLOCK=
    BLOCK_QUOTE=
    LIST_ITEM=

    MERGE_START_MARKER="$(sed 's%.%\x1b%' <<< ".")" # ˆ[ [\x1b]
     MERGE_STOP_MARKER="$(sed 's%.%\x1d%' <<< ".")" # ˆ] [\x1d]
      PARAGRAPH_MARKER="$(sed 's%.%\x10%' <<< ".")" # ˆP [\x10]
           CODE_MARKER="$(sed 's%.%\x03%' <<< ".")" # ˆC [\x03]
       NEW_LINE_MARKER="$(sed 's%.%\x0e%' <<< ".")" # ˆN [\x0e]
         TAG_BR_MARKER="$(sed 's%.%\x02%' <<< ".")" # ˆB [\x02]
              NEW_LINE=$'\n'                        #  $ [\x0a]
                   TAB=$'\t'                        # ˆI [\x09]
                 SPACE=" "                          #    [\x20]
    CANONICAL_PRE_CODE="${CANONICAL_PRE_CODE:+"$NEW_LINE_MARKER"}"

    # open_block | cat -vT
    # open_block | prepare_paragraph | cat -vT
    # open_block | prepare_paragraph | combine_with_tag | cat -vT
    # open_block | prepare_paragraph | combine_with_tag | split | cat -vT

    # open_block | cat -vT
    # open_block
    # open_block | prepare_code | cat -vT
    # open_block | prepare_code | prepare_paragraph | cat -vT
    # open_block | prepare_code | prepare_paragraph
    # open_block | prepare_code | prepare_paragraph | format_paragraph | cat -vT
    # open_block | prepare_code | prepare_paragraph | format_paragraph
    # open_block | prepare_code | prepare_paragraph | format_paragraph | combine_with_tag | cat -vT
    # open_block | prepare_code | prepare_paragraph | format_paragraph | combine_with_tag
    # open_block | prepare_code | prepare_paragraph | format_paragraph | combine_with_tag | split | cat -vT
    open_block | prepare_code | prepare_paragraph | format_paragraph | combine_with_tag | split

    # open_block | prepare_code | prepare_paragraph | combine_with_tag | cat -vT
    # open_block | prepare_code | prepare_paragraph | combine_with_tag
    # open_block | prepare_code | prepare_paragraph | combine_with_tag | split | cat -vT
    # open_block | prepare_code | prepare_paragraph | combine_with_tag | split
    # open_block | prepare_code | prepare_paragraph | format_paragraph | split | cat -vT
    # open_block | prepare_code | prepare_paragraph | format_paragraph | split
}

create_document ()
{
    if is_empty "${ONLY_CONTENT:-}"
    then
        open_html
        add_title
        open_head
        add_style
        close_head
        open_body
        parse
        close_body
        close_html
    else
        parse
    fi
}

create_document_with_message ()
{
    is_equal "$STDIN" "pipeline" &&
    >&2 say "converting stdin"   ||
    >&2 say "converting a file: $INPUT"
    >&3 create_document
    >&2 say "conversion completed"
}

main ()
{
    get_pkg_vars
    argparse "$@"
    is_empty "${HELP:-}"    || show_help
    is_empty "${VERSION:-}" || show_version
    check_args

       is_empty "${OUTPUT:-}" && exec 3>&1 || exec 3>"$OUTPUT"
    if is_empty "${OUTPUT:-}" && is_terminal stdout
    then
        is_terminal stderr
    else
        is_not_terminal stderr && is_equal_fds stderr 3
    fi && >&3 create_document  || create_document_with_message
}

main "$@"
