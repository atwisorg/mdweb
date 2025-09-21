#!/bin/bash

is_diff ()
{
    case "${1:-}" in
        "${2:-}")
            return 1
    esac
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

is_equal ()
{
    case "${1:-}" in
        "${2:-}")
            return 0
    esac
    return 1
}

is_dir ()
{
    test -d "${1:-}"
}

is_file ()
{
    test -f "${1:-}"
}

can_read_file ()
{
    is_file "${1:-}" || {
        is_exists "${1:-}" &&
        say 2 "can't open '${1:-}': is not a file" ||
        say 2 "can't open '${1:-}': no such file"
        return 2
    } >&2
    test -r "${1:-}" || {
        say 1 "can't open '${1:-}': no read permissions" >&2
        return 1
    }
}

if is_not_empty "${KSH_VERSION:-}"
then
    PUTS=print
    puts ()
    {
        print "${PUTS_OPTIONS:--r}" -- "$*"
    }
else
    if type printf >/dev/null 2>&1
    then
        PUTS=printf
        puts ()
        {
            printf "${PUTS_OPTIONS:-%s\n}" "$*"
        }
    elif type echo >/dev/null 2>&1
    then
        PUTS=echo
        puts ()
        {
            echo "${PUTS_OPTIONS:-}" "$*"
        }
    else
        exit 1
    fi
fi

say ()
{
    RETURN=$?
    PUTS_OPTIONS=
    while is_diff $# 0
    do
        case "${1:-}" in
            -n)
                is_equal "$PUTS" printf &&
                PUTS_OPTIONS=%s ||
                PUTS_OPTIONS=-n
                ;;
            *[!0-9]*|"")
                break
                ;;
            *)
                RETURN=$1
        esac
        shift
    done
    case "${*:-"${STATUS:-}"}" in
        *"$LF"*)
            echo "${*:-"${STATUS:-}"}" | while read -r LINE || is_not_empty "${LINE:-}"
            do
                puts "$PACKAGE_NAME: ${FUNC_NAME:+"$FUNC_NAME "}${LINE:-}"
            done
        ;;
        ?*)
            puts "$PACKAGE_NAME: ${FUNC_NAME:+"$FUNC_NAME "}${*:-"${STATUS:-}"}"
        ;;
    esac
    PUTS_OPTIONS=
}

die ()
{
    say "$@" >&2
    exit "$RETURN"
}

is_exists ()
{
    test -e "${1:-}"
}

abs_dirpath ()
{
    cd -- "$1" 2>&1 && pwd -P 2>&1
}

say_status ()
{
    case $? in
        0)  case "${VERBOSE:-}" in
                ?*) say "${STATUS:-}" ;;
            esac ;;
        *)  case "$DIE" in
                no) say "${STATUS:-}"
                    return "$RETURN"  ;;
                 *) die "${STATUS:-}" ;;
            esac ;;
    esac
}

exec_cmd ()
{
    DIE=yes STATUS= VERBOSE=
    while :
    do
        case "${1:-}" in
            -c ) DIE=no ;;
            -c*) DIE=no
                 ARG="-${1#??}"
                 shift
                 set -- '' "$ARG" "$@" ;;
            -v ) VERBOSE=yes ;;
            -v*) VERBOSE=yes
                 ARG="-${1#??}"
                 shift
                 set -- '' "$ARG" "$@" ;;
            -- ) shift
                 break ;;
              *) break ;;
        esac
        shift
    done
    case "${1:-}" in
        "") STATUS="not enough arguments"
            DIE=yes
            false ;;
    esac && STATUS="$(2>&1 $CMD -- "$@")" && say_status || say_status
}

change_dir ()
{
    CMD="cd"
    FUNC_NAME=change_dir
    exec_cmd "$@" && cd -- "${1:-}"
}

change_mod ()
{
    CMD="chmod $1"
    shift
    exec_cmd "$@"
}

make_dir ()
{
    CMD="mkdir -vp"
    exec_cmd "$@"
}

remove ()
{
    CMD="rm -rvf"
    exec_cmd "$@"
}

has_space ()
{
    STRING="${1:-}"
    case "${STRING:-}" in
        "" | *[[:space:]]*)
            STRING="\"${STRING:-}\""
        ;;
    esac
}

trim_string ()
{
    STRING="${1#"${1%%[![:space:]]*}"}"
    STRING="${STRING%"${STRING##*[![:space:]]}"}"
    echo "$STRING"
}

get_pkg_vars ()
{
    PKG="${0##*/}"
    PACKAGE_NAME="${PKG%.sh}"
    PKG_DIR="${0%"$PKG"}"
    PKG_DIR="${PKG_DIR:-/}"
    PKG_DIR="$(abs_dirpath "$PKG_DIR")"
    PKG_PATH="$PKG_DIR/$PKG"
}

set_color ()
{
          RED="\033[31m"
        GREEN="\033[32m"
       YELLOW="\033[33m"
         CYAN="\033[36m"
         BOLD="\033[1m"
    CLR_RESET="\033[0;0m"
}

get_test_nums ()
{
    TEST_NUM=( $(IFS="$IFS,"; set -- ${TEST_NUM[@]}; echo "$@") )
    set -- "${TEST_NUM[@]}"
    TEST_NUM=()
    while is_diff $# 0
    do
        case "$1" in
            -)
                false
                ;;
            [0-9])
                TEST_NUM+=( "$1" )
                ;;
            *)
                [[ "$1" =~ ^[0-9]+-[0-9]+$ ]] && {
                    test "${1%%-*}" -le "${1##*-}" &&
                    for NUM in $(seq "${1%%-*}" "${1##*-}")
                    do
                        TEST_NUM+=( "$NUM" )
                    done
                } || {
                    [[ "$1" =~ ^[0-9]+$ ]] && TEST_NUM+=( "$1" )
                }

        esac || die 2 "unrecognized test number: -- '$1'"
        shift
    done
    TEST_NUM=( $(printf '%s\n' ${TEST_NUM[@]} | sort -n | uniq) )
}

puts_flow ()
{
    case "${2:-}" in
        "")
            printf "$3%15s$CLR_RESET:\n" "$1"
            printf "$3%s$CLR_RESET\n" "$H2"
        ;;
        *"$LF"*)
            printf "$3%15s$CLR_RESET:\n" "$1"
            printf "$3%s$CLR_RESET\n%s\n$3%s$CLR_RESET\n" "$H2" "$2" "$H2"
        ;;
        ?*)
            printf "$3%15s$CLR_RESET: $3[$CLR_RESET%s$3]$CLR_RESET\n" "$1" "$2"
            printf "%s\n" "$H2"
        ;;
    esac
}

save_result ()
{
    STATUS=":test: $TEST_NAME$LF"
    is_equal "${#TESTED_COMMAND[@]}" 0 ||
        STATUS="$STATUS:command: ${TESTED_COMMAND[@]}$LF"
    is_equal "${#TESTED_ARGS[@]}" 0 ||
        STATUS="$STATUS:args: ${TESTED_ARGS[@]}$LF"
    is_empty "${COMPARE_STDOUT:-}" ||
        STATUS="$STATUS:expect: |$LF${EXPECT:+"$EXPECT$LF"}"
    is_empty "${COMPARE_STDERR:-}" ||
        STATUS="$STATUS:expect-err: |$LF${EXPECT_ERR:+$EXPECT_ERR$LF}"
    is_empty "${EXPECT_RETURN_CODE:-}" ||
        STATUS="$STATUS:return: $EXPECT_RETURN_CODE$LF"
    STATUS="$STATUS:stdin:  |$LF${STDIN:+$STDIN$LF}:run:$LF$LF"
    STATUS="$STATUS:stdout: |$LF${STDOUT_RESULT:+$STDOUT_RESULT$LF}"
    STATUS="$STATUS:stderr: |$LF${STDERR_RESULT:+$STDERR_RESULT$LF}"
    STATUS="$STATUS:return: $RETURN_CODE$LF:end:"
    echo "$STATUS" > "$1/${NAME_TEST_SAMPLE}_$STRING_NUM_TEST.yaml"
}

cmp_results ()
{
    RETURN=0
    STDOUT_RESULT="$(cat "$STDOUT")"
    STDERR_RESULT="$(cat "$STDERR")"
    rm -f "$STDOUT" "$STDERR"

    is_empty "${COMPARE_STDOUT:-}" || {
        if is_equal "${STDOUT_RESULT:-}" "${EXPECT:-}"
        then
            REPORT_STDOUT="$(puts_flow "stdout" "${STDOUT_RESULT:-}" "$BOLD$GREEN")"
        else
            REPORT_STDOUT="$(
                puts_flow "expect-stdout" "${EXPECT:-}" "$YELLOW"
                puts_flow "stdout" "${STDOUT_RESULT:-}" "$BOLD$RED"
            )"
            FAIL+=( "${PREFIX[0]%:}" "${PREFIX[*]:1}: stdout" )
            RETURN=1
        fi
    }

    is_empty "${COMPARE_STDERR:-}" || {
        if is_equal "${STDERR_RESULT:-}" "$EXPECT_ERR"
        then
            REPORT_STDERR="$(puts_flow "stderr" "${STDERR_RESULT:-}" "$BOLD$GREEN")"
        else
            REPORT_STDERR="$(
                puts_flow "expect-stderr" "${EXPECT_ERR:-}" "$YELLOW"
                puts_flow "stderr" "${STDERR_RESULT:-}" "$BOLD$RED"
            )"
            FAIL+=( "${PREFIX[0]%:}" "${PREFIX[*]:1}: stderr" )
            RETURN=1
        fi
    }

    is_empty "${EXPECT_RETURN_CODE:-}" || {
        if is_equal "${RETURN_CODE:-}" "${EXPECT_RETURN_CODE:-}"
        then
            REPORT_RETURN="$(puts_flow "return" "${RETURN_CODE:-}" "$BOLD$GREEN")"
        else
            REPORT_RETURN="$(
                puts_flow "expect-return" "$EXPECT_RETURN_CODE" "$YELLOW"
                puts_flow "return" "$RETURN_CODE" "$BOLD$RED"
            )"
            FAIL+=( "${PREFIX[0]%:}" "${PREFIX[*]:1}: return" )
            RETURN=1
        fi
    }

    is_equal "$RETURN" 0 && PASSED="$((PASSED+1))" || {
                            FAILED="$((FAILED+1))"
        FAILED_TEST_NUMBERS+=( "$TOTAL_TEST_NUMBER" )
    }

    is_not_empty "${COMPARE_STDOUT:-}" || {
        is_empty "${ALL_STREAMS:-"${SHOW_STDOUT:-}"}" && {
            is_not_empty "${NO_STREAMS:-}" || is_equal "$RETURN" 0
        } || REPORT_STDOUT="$(puts_flow "stdout" "${STDOUT_RESULT:-}" "$CYAN")"
    }

    is_not_empty "${COMPARE_STDERR:-}" || {
        is_empty "${ALL_STREAMS:-"${SHOW_STDERR:-}"}" && {
            is_not_empty "${NO_STREAMS:-}" || is_equal "$RETURN" 0
        } || REPORT_STDERR="$(puts_flow "stderr" "${STDERR_RESULT:-}" "$CYAN")"
    }

    is_not_empty "${EXPECT_RETURN_CODE:-}" || {
        is_empty "${ALL_STREAMS:-"${SHOW_RETCODE:-}"}" && {
            is_not_empty "${NO_STREAMS:-}" || is_equal "$RETURN" 0
        } || REPORT_RETURN="$(puts_flow "return" "$RETURN_CODE" "$CYAN")"
    }

    printf '%s\n' "${REPORT_STDOUT[@]}" "${REPORT_STDERR[@]}" "${REPORT_RETURN:-}"

    return "$RETURN"
}

check_test_num ()
{
    is_not_empty "${!TEST_NUM[@]}" || return 1
    set -- "${TEST_NUM[@]}"
    is_equal "$1" "$TOTAL_TEST_NUMBER" || return 2
    shift
    TEST_NUM=( "$@" )
}

trim_white_space ()
{
    STRING="${1#"${1%%[![:blank:]]*}"}"
    STRING="${STRING%"${STRING##*[![:blank:]]}"}"
}

unset_vars ()
{
    COMPARE_STDERR=
    COMPARE_STDOUT=
    EXPECT=
    EXPECT_ERR=
    EXPECT_RETURN_CODE=
    LOAD_TEST="no"
    PRETEST=
    POSTEST=
    SHOW_COMMAND=
    SHOW_TESTED_ARGS=()
    SHOW_TESTED_PKG=
    SOURCE=()
    STDIN=
    TESTED_ARGS=()
    TESTED_COMMAND=
    TIMEOUT=
    REPORT_STDERR=()
    REPORT_STDOUT=()
    REPORT_RETURN=()
    VARS=
    WORKDIR=
    WORKDIR_CLEAN=
    WORKDIR_CHMOD=
}

get_app_path ()
{
    TESTED_APP=
    TESTED_APP_DIR=
    is_exists "$PKG_DIR/$1" ||
    case "$1" in
        */*)
            die 2 "no such app: -- '$1'" 2>&3
        ;;
        *)
            TESTED_APP="$(2>&1 type "$1")" || die 2 "no such app: -- '$1'" 2>&3
            TESTED_APP="${TESTED_APP##*[[:blank:]]}"
            return
        ;;
    esac
    TESTED_APP_DIR="$PKG_DIR/${1%/*}"
    TESTED_APP_DIR="${TESTED_APP_DIR:-/}"
    TESTED_APP_DIR="$(abs_dirpath "$TESTED_APP_DIR")" || die "${TESTED_APP_DIR:-}"
    TESTED_APP="$TESTED_APP_DIR/${1##*/}"
}

get_result ()
{
    if cmp_results
    then
        is_equal "$SAVE_RESULTS" "no" || save_result "$TEST_PASSED"
    else
        save_result "$TEST_FAILED"
        TEST_RETURN_CODE=1
    fi
    is_empty "${POSTEST:-}" || eval "$POSTEST"
    unset_vars
    cd -- "$CURRENT_DIR"
}

puts_heading ()
{
    if is_not_empty "${NO_HEADINGS:-}"
    then
        printf '%s\n' "$H1"
    else
        printf '%16s %s\n' "${PREFIX[@]}"
        printf '%s\n' "$H1"
    fi
}

puts_pretest_start ()
{
    puts_flow "pretest" "" "$YELLOW"
}

puts_h ()
{
    is_equal "$1" 1 && H="$H1" || H="$H2"
    case "${2:-}" in
        ?*) printf "$2%s$CLR_RESET\n" "$H" ;;
        *)  printf "%s\n" "$H" ;;
    esac
}

puts_command ()
{
    puts_flow "command" "$SHOW_COMMAND" "$CYAN"
    is_empty "${STDIN:-}" || puts_flow "stdin" "$STDIN" "$CYAN"
}

run_command ()
{
    if is_empty "${TIMEOUT:-}"
    then
        eval "${TESTED_COMMAND:-"$TESTED_PKG"}" "${TESTED_ARGS[@]}" > "$STDOUT" 2> "$STDERR"
    else
        eval timeout "${TIMEOUT:-"${GLOBAL_TIMEOUT:-3}"}" "${TESTED_COMMAND:-"$TESTED_PKG"}" "${TESTED_ARGS[@]}" > "$STDOUT" 2> "$STDERR"
    fi
}

run_unit_test ()
{
    PREFIX=(
        "test sample:" "[$TEST_SAMPLE]"
        "string num:" "[$STRING_NUM_TEST]"
        "test name:" "|${TEST_NAME//$LF/$LF$INDENT}"
        "test num:" "[$TEST_NUMBER]"
    )
    is_diff "${#TEST_SAMPLES[@]}" 0 || PREFIX=( "${PREFIX[@]}" "total test num:" "[$TOTAL_TEST_NUMBER]" )
    is_diff "${#TESTED_ARGS[@]}"  0 || TESTED_ARGS=( "${GLOBAL_ARGS[@]}" )
    for ARG in "${TESTED_ARGS[@]}"
    do
        has_space "$ARG"
        SHOW_TESTED_ARGS+=( "$STRING" )
    done
    NAME_TEST_SAMPLE="${TEST_SAMPLE##*/}"
    NAME_TEST_SAMPLE="${NAME_TEST_SAMPLE%.yaml}"
    puts_heading

    TIMEOUT="${TIMEOUT:-"${GLOBAL_TIMEOUT:-}"}"
    WORKDIR="${WORKDIR:-"${GLOBAL_WORKDIR:-}"}"
    WORKDIR_CLEAN="${WORKDIR_CLEAN:-"${GLOBAL_WORKDIR_CLEAN:-}"}"
    WORKDIR_CHMOD="${WORKDIR_CHMOD:-"${GLOBAL_WORKDIR_CHMOD:-}"}"
    STDOUT="$TEMP_DIR/${NAME_TEST_SAMPLE}_$STRING_NUM_TEST.out"
    STDERR="$TEMP_DIR/${NAME_TEST_SAMPLE}_$STRING_NUM_TEST.err"
    RETURN_CODE=0

    is_empty "${VARS:-}" || eval "$VARS"

    is_empty "${WORKDIR:-}" && {
        WORKDIR="$TEST_SAMPLE_DIR"
        change_dir "$WORKDIR"
    } || {
        case "$WORKDIR" in
            [!/]*)
                WORKDIR="$TEST_SAMPLE_DIR/$WORKDIR"
            ;;
        esac
        is_dir "$WORKDIR" || make_dir "$WORKDIR"
        WORKDIR="$(abs_dirpath "$WORKDIR")" || die "${WORKDIR:-}"
        is_diff  "${WORKDIR_CLEAN:-}" yes || {
            is_not_empty "${TESTED_APP_DIR:-}" &&
            is_diff "${TESTED_APP_DIR#"$WORKDIR"}" "$TESTED_APP_DIR" ||
            is_diff "${TESTED_PKG_DIR#"$WORKDIR"}" "$TESTED_PKG_DIR" ||
            is_diff "${HOME#"$WORKDIR"}" "$HOME" ||
            is_equal "$WORKDIR" "/root" || remove "$WORKDIR"/*
        }
        is_empty "${WORKDIR_CHMOD:-}" || change_mod "$WORKDIR_CHMOD" "$WORKDIR"
        change_dir "$WORKDIR"
        has_space "$PWD"
        SHOW_COMMAND="cd $STRING;$LF"
    }
    is_empty "${!SOURCE[@]}" || {
        for i in "${SOURCE[@]}"
        do
            source "$TEST_SAMPLE_DIR/source/$i" || die
        done
    }
    is_empty "${PRETEST:-}" || {
        puts_pretest_start
        eval "$PRETEST"
        puts_h 2 "$YELLOW"
    }

    if is_empty "${STDIN:-}"
    then
        SHOW_COMMAND="${SHOW_COMMAND:-}${TESTED_COMMAND:-"$SHOW_TESTED_PKG"}${SHOW_TESTED_ARGS[@]:+" ${SHOW_TESTED_ARGS[@]}"}"
        puts_command
        run_command &
    else
        has_space "$STDIN"
        SHOW_STDIN="$STRING"
        SHOW_COMMAND="${SHOW_COMMAND:-}echo $SHOW_STDIN | ${TESTED_COMMAND:-"$SHOW_TESTED_PKG"}${SHOW_TESTED_ARGS[@]:+" ${SHOW_TESTED_ARGS[@]}"}"
        puts_command
        run_command < <(sed 's%\o357\o277\o275%\o000%g' <<< "$STDIN") &
    fi

    CHILD_PID="$!"
    wait "$CHILD_PID"
    RETURN_CODE="$?"
}

run_test_sample ()
{
    STRING_NUM=0
    TEST_NUMBER=0
    while IFS= read -r LINE || is_not_empty "${LINE:-}"
    do
        STRING_NUM="$((STRING_NUM + 1))"
        case "${LINE:-}" in
            \#:test|\#:test:*)
                TEST_NUMBER="$((TEST_NUMBER + 1))"
                TOTAL_TEST_NUMBER="$((TOTAL_TEST_NUMBER + 1))"
                LOAD_TEST="no"
                continue
                ;;
            :test:*)
                TEST_NUMBER="$((TEST_NUMBER + 1))"
                TOTAL_TEST_NUMBER="$((TOTAL_TEST_NUMBER + 1))"
                is_empty "${SPECIFIC_TEST:-}" || check_test_num || {
                    case $? in
                        1 ) return 1 ;;
                        2 ) continue
                    esac
                }
                LOAD_TEST="yes"
                STRING_NUM_TEST="$STRING_NUM"

                TEST_NAME="$(trim_string "${LINE#:test:}")"
                TEST_NAME="${TEST_NAME:-noname}"
                case "${TEST_NAME:-}" in
                    \|*)
                        NEXT_LINE=test-description
                        TEST_NAME=
                    ;;
                esac
                ;;
            *)
                is_equal "$LOAD_TEST" "yes" || continue
                case "${LINE:-}" in
                    :args|:command|:postest|:pretest|:return|:return-code|:source|:stdin|:test|:timeout|:vars|:workdir|:workdir-clean|:workdir-chmod)
                        NEXT_LINE=
                        ;;
                    :args:*)
                        NEXT_LINE=
                        TESTED_ARGS=( "$(trim_string "${LINE#:args:}")" )
                        case "${TESTED_ARGS:-}" in
                            \|*)
                                NEXT_LINE=args
                                TESTED_ARGS=()
                            ;;
                        esac
                        ;;
                    :command:*)
                        NEXT_LINE=
                        TESTED_COMMAND="$(trim_string "${LINE#:command:}")"
                        case "${TESTED_COMMAND:-}" in
                            \|*)
                                NEXT_LINE=command
                                TESTED_COMMAND=
                            ;;
                        esac
                        ;;
                    :break|:break:*)
                        NEXT_LINE=
                        break
                        ;;
                    :exit|:exit:*)
                        NEXT_LINE=
                        return 1
                        ;;
                    :expect|:expect-out|:expect-stdout|:expect:*|:expect-out:*|:expect-stdout:*)
                        NEXT_LINE="expect-stdout"
                        COMPARE_STDOUT="yes"
                        ;;
                    :expect-err|:expect-stderr|:expect-err:*|:expect-stderr:*)
                        NEXT_LINE="expect-stderr"
                        COMPARE_STDERR="yes"
                        ;;
                    :pretest:*)
                        NEXT_LINE=
                        PRETEST="$(trim_string "${LINE#:pretest:}")"
                        case "${PRETEST:-}" in
                            \|*)
                                NEXT_LINE=pretest
                                PRETEST=
                            ;;
                        esac
                        ;;
                    :postest:*)
                        NEXT_LINE=
                        POSTEST="$(trim_string "${LINE#:postest:}")"
                        case "${POSTEST:-}" in
                            \|*)
                                NEXT_LINE=postest
                                POSTEST=
                            ;;
                        esac
                        ;;
                    :return:*)
                        NEXT_LINE=
                        set -- ${LINE#:return:}
                        EXPECT_RETURN_CODE="${1:-}"
                        ;;
                    :return-code:*)
                        NEXT_LINE=
                        set -- ${LINE#:return-code:}
                        EXPECT_RETURN_CODE="${1:-}"
                        ;;
                    :run|:run:*)
                        NEXT_LINE=
                        run_unit_test
                        get_result
                        ;;
                    :source:*)
                        NEXT_LINE=
                        SOURCE=( "$(trim_string "${LINE#:source:}")" )
                        case "${SOURCE[0]:-}" in
                            \|*)
                                NEXT_LINE=source
                                SOURCE=()
                            ;;
                        esac
                        ;;
                    :stdin:*)
                        NEXT_LINE=
                        STDIN="$(trim_string "${LINE#:stdin:}")"
                        case "${STDIN:-}" in
                            \|*)
                                NEXT_LINE=stdin
                                STDIN=
                            ;;
                        esac
                        ;;
                    :timeout:*)
                        NEXT_LINE=
                        set -- ${LINE#:timeout:}
                        TIMEOUT="${1:-}"
                        ;;
                    :vars:*)
                        NEXT_LINE=
                        VARS="$(trim_string "${LINE#:vars:}")"
                        case "${VARS:-}" in
                            \|*)
                                NEXT_LINE=vars
                                VARS=
                            ;;
                        esac
                        ;;
                    :workdir:*)
                        NEXT_LINE=
                        WORKDIR="$(trim_string "${LINE#:workdir:}")"
                        ;;
                    :workdir-clean:*)
                        NEXT_LINE=
                        set -- ${LINE#:workdir-clean:}
                        WORKDIR_CLEAN="${1:-}"
                        ;;
                    :workdir-chmod:*)
                        NEXT_LINE=
                        set -- ${LINE#:workdir-chmod:}
                        WORKDIR_CHMOD="${1:-}"
                        ;;
                    *)
                        case "$NEXT_LINE" in
                            args)
                                TESTED_ARGS+=( "${LINE:-}" )
                            ;;
                            command)
                                TESTED_COMMAND="${TESTED_COMMAND:+"$TESTED_COMMAND$LF"}$(trim_string "${LINE#:command:}")"
                            ;;
                            expect-stdout)
                                EXPECT="${EXPECT:+"$EXPECT$LF"}${LINE:-}"
                            ;;
                            expect-stderr)
                                EXPECT_ERR="${EXPECT_ERR:+"$EXPECT_ERR$LF"}${LINE:-}"
                            ;;
                            source)
                                SOURCE+=( "$(trim_string "${LINE#:source:}")" )
                            ;;
                            stdin)
                                STDIN="${STDIN:+"$STDIN$LF"}${LINE:-}"
                            ;;
                            pretest)
                                PRETEST="${PRETEST:+"$PRETEST$LF"}${LINE:-}"
                            ;;
                            postest)
                                POSTEST="${POSTEST:+"$POSTEST$LF"}${LINE:-}"
                            ;;
                            test-description)
                                TEST_NAME="${TEST_NAME:+"$TEST_NAME$LF"}$(trim_string "${LINE#:test:}")"
                            ;;
                            vars)
                                VARS="${VARS:+"$VARS$LF"}$(trim_string "${LINE#:vars:}")"
                            ;;
                        esac
                esac
        esac
    done < <(cat "$TEST_SAMPLE" | sed 's%\o000%\o357\o277\o275%g')
}

get_range_nums ()
{
    END_RANGE=
    START_RANGE=
    RANGE_NUMS=
    for NUM in "${FAILED_TEST_NUMBERS[@]}"
    do
        if is_empty "${START_RANGE:-}"
        then
            START_RANGE="$NUM"
        else
            if is_equal "$((NUM - ${END_RANGE:-"$START_RANGE"}))" 1
            then
                END_RANGE="$NUM"
            else
                RANGE_NUMS="${RANGE_NUMS:+"$RANGE_NUMS",}$START_RANGE"
                is_empty "${END_RANGE:-}" || {
                    is_equal $((END_RANGE - START_RANGE)) 1 &&
                    RANGE_NUMS="$RANGE_NUMS,$END_RANGE" ||
                    RANGE_NUMS="$RANGE_NUMS-$END_RANGE"
                }
                START_RANGE="$NUM"
                END_RANGE=
            fi
        fi
    done
    is_empty "${END_RANGE:-"${START_RANGE:-}"}" || {
        RANGE_NUMS="${RANGE_NUMS:+"$RANGE_NUMS",}$START_RANGE"
        is_empty "${END_RANGE:-}" || {
            is_equal $((END_RANGE - START_RANGE)) 1 &&
            RANGE_NUMS="$RANGE_NUMS,$END_RANGE" ||
            RANGE_NUMS="$RANGE_NUMS-$END_RANGE"
        }
    }
}

report ()
{
    is_not_empty "${NO_REPORT:-}" || {
        is_empty ${!FAIL[@]} || {
            printf "$RED%15s$CLR_RESET: $BOLD$RED%s$CLR_RESET\n" "${FAIL[@]}"
            get_range_nums
            printf "$RED%15s$CLR_RESET: [$BOLD$RED%s$CLR_RESET]\n" "failed tests" "$RANGE_NUMS"
        }
        printf "$RED%15s$CLR_RESET: [$BOLD$RED%s$CLR_RESET]\n" "failed" "$FAILED"
        printf "$GREEN%15s$CLR_RESET: [$BOLD$GREEN%s$CLR_RESET]\n" "passed" "$PASSED"
        is_empty "${SPECIFIC_TEST:-}" || TOTAL_TEST_NUMBER="$SPECIFIC_TEST"
        printf "$YELLOW%15s$CLR_RESET: [$BOLD$YELLOW%s$CLR_RESET]\n" "total tests" "$TOTAL_TEST_NUMBER"
        echo "$H1"
    }
}

run_test ()
{
    is_diff "${!TEST_SAMPLES[@]}" &&
    for TEST_SAMPLE in "${TEST_SAMPLES[@]}"
    do
        is_exists "$TEST_SAMPLE" || {
            is_exists   "$TEST_SAMPLES_DIR/$TEST_SAMPLE" &&
            TEST_SAMPLE="$TEST_SAMPLES_DIR/$TEST_SAMPLE"
        } || die 2 "no such file: -- '$TEST_SAMPLE'" 2>&3
        run_test_sample || break
    done ||
    for TEST_SAMPLE in "$TEST_SAMPLES_DIR"/*
    do
        if is_file "$TEST_SAMPLE"
        then
            grep "^[[:blank:]]*${TEST_SAMPLE##*/}" "$TEST_SAMPLES_DIR/.testignor" &>/dev/null || {
                TEST_SAMPLE_DIR="${TEST_SAMPLE%/*}"
                false
            }
        elif is_file "$TEST_SAMPLE/test.yaml"
        then
            grep "^[[:blank:]]*${TEST_SAMPLE##*/}" "$TEST_SAMPLES_DIR/.testignor" &>/dev/null || {
                TEST_SAMPLE_DIR="$TEST_SAMPLE"
                TEST_SAMPLE="$TEST_SAMPLE/test.yaml"
                false
            }
        fi || run_test_sample || break
    done
    report >&3
}

is_not_key ()
{
    for KEY in "${ARGS[@]}"
    do
        is_diff "$1" "--$KEY" || return
    done
}

argparse ()
{
    ARGS=(
        "all-streams" "args"
        "clear"
        "no-headings" "no-report" "no-streams"
        "save-results" "show-stdout" "show-stderr" "show-retcode"
        "test-file" "test-num" "timeout"
        "workdir" "workdir-clean" "workdir-chmod"
    )
    while is_diff $# 0
    do
        case "${1:-}" in
            --all-streams)
                ALL_STREAMS="yes"
                NO_STREAMS=""
                ;;
            --args)
                while is_diff $# 0
                do
                    is_not_empty "${2:-}" && is_not_key "$2" || break
                    GLOBAL_ARGS+=( "${2:-}" )
                    shift
                done
                ;;
            --clear)
                CLEAR_RESULTS="yes"
                ;;
            --no-headings)
                NO_HEADINGS="yes"
                ;;
            --no-report)
                NO_REPORT="yes"
                ;;
            --no-streams)
                ALL_STREAMS=""
                NO_STREAMS="yes"
                ;;
            --save-results)
                SAVE_RESULTS="yes"
                ;;
            --show-stdout)
                SHOW_STDOUT="yes"
                ;;
            --show-stderr)
                SHOW_STDERR="yes"
                ;;
            --show-retcode)
                SHOW_RETCODE="yes"
                ;;
            --test-file)
                while is_diff $# 0
                do
                    is_not_empty "${2:-}" && is_not_key "$2" || break
                    TEST_SAMPLES+=( "${2:-}" )
                    shift
                done
                ;;
            --test-num)
                while is_diff $# 0
                do
                    is_not_empty "${2:-}" && is_not_key "$2" || break
                    TEST_NUM+=( "${2:-}" )
                    shift
                done
                ;;
            --timeout)
                is_not_empty "${2:-}" && is_not_key "$2" && {
                    TIMEOUT="${2:-}"
                    shift
                } || true
                ;;
            --workdir)
                is_not_empty "${2:-}" && is_not_key "$2" && {
                    WORKDIR="${2:-}"
                    shift
                } || true
                ;;
            --workdir-clean)
                WORKDIR_CLEAN="yes"
                ;;
            --workdir-chmod)
                is_not_empty "${2:-}" && is_not_key "$2" && {
                    WORKDIR_CHMOD="${2:-}"
                    shift
                } || true
                ;;
            *[!0-9,-]*)
                GLOBAL_ARGS+=( "${1:-}" )
                ;;
            *)
                TEST_NUM+=( "${1:-}" )
        esac
        shift
    done
}

main ()
{
    exec 3>&1
    get_pkg_vars
    set_color

    can_read_file "$PKG_DIR/${PKG%.sh}.conf" &&
           source "$PKG_DIR/${PKG%.sh}.conf" || die

    INDENT="                 |"
    H1="================"
    H2="----------------"
    GLOBAL_ARGS=()
    CLEAR_RESULTS="no"
    SAVE_RESULTS="no"
    TEST_NUM=()
    TEST_SAMPLES=()
    FUNC_NAME="[${TESTED_PKG##*/}]"
    PASSED=0
    FAILED=0
    FAIL=()
    TOTAL_TEST_NUMBER=0
    LOAD_TEST="no"
    TEST_NUMBER=0
    STRING_NUM=0
    TEST_RETURN_CODE=0
    LF=$'\n'

    GLOBAL_TIMEOUT="${TIMEOUT:-}" TIMEOUT=
    GLOBAL_WORKDIR="${WORKDIR:-}" WORKDIR=
    GLOBAL_WORKDIR_CLEAN="${WORKDIR_CLEAN:-}"
    GLOBAL_WORKDIR_CHMOD="${WORKDIR_CHMOD:-}"

    CURRENT_DIR="$PWD"
    TEMP_DIR="$PKG_DIR/tmp"
    TEST_PASSED="${TEST_PASSED:-"$PKG_DIR/test_passed"}"
    TEST_FAILED="${TEST_FAILED:-"$PKG_DIR/test_failed"}"

    TEST_SAMPLES_DIR="${TEST_SAMPLES_DIR:-"$PKG_DIR/samples"}"

    is_dir "$TEMP_DIR"    || make_dir "$TEMP_DIR"
    is_dir "$TEST_PASSED" || make_dir "$TEST_PASSED"
    is_dir "$TEST_FAILED" || make_dir "$TEST_FAILED"

    get_app_path "$TESTED_PKG"
    TESTED_PKG="$TESTED_APP"
    TESTED_PKG_DIR="$TESTED_APP_DIR"
    has_space "$TESTED_PKG"
    SHOW_TESTED_PKG="$STRING"

    argparse "$@"
    is_empty "${!TEST_NUM[@]}" || {
        get_test_nums
        SPECIFIC_TEST="${#TEST_NUM[@]}"
    }

    is_equal "$CLEAR_RESULTS" "no" || remove "$TEST_PASSED"/* "$TEST_FAILED"/*
    say "starting testing"
    puts_h 1
    run_test
    remove "$TEMP_DIR"
    return "$TEST_RETURN_CODE"
}

out ()
{
    echo
    CHILD_PIDS=( $(ps aux | grep -v grep | grep "${TESTED_PKG##*/}" | awk '{print $2}') )
    # https://stackoverflow.com/questions/1570262/get-exit-code-of-a-background-process#1570356
    kill -9 "${CHILD_PIDS[@]}"
       wait "${CHILD_PIDS[@]}" 2>/dev/null
    get_result
    report >&3
    exit 1
}

trap 'out' INT

main "$@"
