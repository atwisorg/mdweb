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

is_exists ()
{
    test -e "${1:-}"
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

save_result ()
{
    STATUS=":test:$TEST_NAME$NEW_STRING"
    is_equal "${#TESTED_ARGS[@]}" 0 ||
        STATUS="$STATUS:args:${TESTED_ARGS[@]}$NEW_STRING"
    is_empty "${COMPARE_STDOUT:-}" ||
        STATUS="$STATUS:expect: |$NEW_STRING${EXPECT:+"$EXPECT$NEW_STRING"}"
    is_empty "${COMPARE_STDERR:-}" ||
        STATUS="$STATUS:expect-err: |$NEW_STRING${EXPECT_ERR:+$EXPECT_ERR$NEW_STRING}"
    is_empty "${EXPECT_RETURN_CODE:-}" ||
        STATUS="$STATUS:return: $EXPECT_RETURN_CODE$NEW_STRING"
    STATUS="$STATUS:sample: |$NEW_STRING${SAMPLE:+$SAMPLE$NEW_STRING}:run:$NEW_STRING$NEW_STRING"
    STATUS="$STATUS:stdout: |$NEW_STRING${STDOUT_RESULT:+$STDOUT_RESULT$NEW_STRING}"
    STATUS="$STATUS:stderr: |$NEW_STRING${STDERR_RESULT:+$STDERR_RESULT$NEW_STRING}"
    STATUS="$STATUS:return: $RETURN_CODE$NEW_STRING:end:"
    echo "$STATUS" > "$1/${NAME_TESTED_FILE}_$STRING_NUM_TEST.txt"
}

expect_out ()
{
    echo -e "|\033[0;33m${1//$NEW_STRING/\\033\[0m|$NEW_STRING$INDENT\\033\[0;33m}\033[0m|"
}

success_out ()
{
    echo -e "|\033[1;32m${1//$NEW_STRING/\\033\[0m|$NEW_STRING$INDENT\\033\[1;32m}\033[0m|"
}

failed_out ()
{
    echo -e "|\033[1;31m${1//$NEW_STRING/\\033\[0m|$NEW_STRING$INDENT\\033\[1;31m}\033[0m|"
}

info_out ()
{
    echo -e "|\033[0;36m${1//$NEW_STRING/\\033\[0m|$NEW_STRING$INDENT\\033\[0;36m}\033[0m|"
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
            REPORT_STDOUT=(
                "$H2" ""
                "stdout:" "$(success_out "$STDOUT_RESULT")"
            )
            is_equal "$SAVE_RESULTS" "yes" || rm -f "$STDOUT"
        else
            REPORT_STDOUT=(
                "$H2" ""
                "expect-stdout:" "$(expect_out "$EXPECT")"
                "$H2" ""
                "stdout:" "$(failed_out "$STDOUT_RESULT")"
            )
            FAIL+=( "${PREFIX[0]%:}" "${PREFIX[*]:1}: stdout" )
            RETURN=1
        fi
    }

    is_empty "${COMPARE_STDERR:-}" || {
        if is_equal "${STDERR_RESULT:-}" "$EXPECT_ERR"
        then
            REPORT_STDERR=(
                "$H2" ""
                "stderr:" "$(success_out "$STDERR_RESULT")"
            )
            is_equal "$SAVE_RESULTS" "yes" || rm -f "$STDERR"
        else
            REPORT_STDERR=(
                "$H2" ""
                "expect-stderr:" "$(expect_out "$EXPECT_ERR")"
                "$H2" ""
                "stderr:" "$(success_out "$STDERR_RESULT")"
            )
            FAIL+=( "${PREFIX[0]%:}" "${PREFIX[*]:1}: stderr" )
            RETURN=1
        fi
    }

    is_empty "${EXPECT_RETURN_CODE:-}" || {
        if is_equal "${RETURN_CODE:-}" "${EXPECT_RETURN_CODE:-}"
        then
            REPORT_RETURN=(
                "$H2" ""
                "return:" "$(success_out "${RETURN_CODE:-}")"
            )
        else
            REPORT_RETURN=(
                "$H2" ""
                "expect-return:" "$(expect_out "$EXPECT_RETURN_CODE")"
                "$H2" ""
                "return:" "$(failed_out "$RETURN_CODE")"
            )
            FAIL+=( "${PREFIX[0]%:}" "${PREFIX[*]:1}: return" )
            RETURN=1
        fi
    }

    is_equal "$RETURN" 0 && SUCCESS="$((SUCCESS+1))" || {
                             FAILED="$((FAILED+1))"
        FAILED_TEST_NUMBERS+=( "$TOTAL_TEST_NUMBER" )
    }

    is_not_empty "${COMPARE_STDOUT:-}" || {
        is_empty "${INFO:-"${SHOW_STDOUT:-}"}" && {
            is_not_empty "${INFO_OFF:-}" || is_equal "$RETURN" 0
        } || {
            REPORT_STDOUT=(
                "$H2" ""
                "stdout:" "$(info_out "${STDOUT_RESULT:-}")"
            )
        }
    }

    is_not_empty "${COMPARE_STDERR:-}" || {
        is_empty "${INFO:-"${SHOW_STDERR:-}"}" && {
            is_not_empty "${INFO_OFF:-}" || is_equal "$RETURN" 0
        } || {
            REPORT_STDERR=(
                "$H2" ""
                "stderr:" "$(info_out "${STDERR_RESULT:-}")"
            )
        }
    }

    is_not_empty "${EXPECT_RETURN_CODE:-}" || {
        is_empty "${INFO:-"${SHOW_RETCODE:-}"}" && {
            is_not_empty "${INFO_OFF:-}" || is_equal "$RETURN" 0
        } || {
            REPORT_RETURN=(
                "$H2" ""
                "return:" "$(info_out "${RETURN_CODE:-}")"
            )
        }
    }

    printf '%16s %s\n' "${REPORT_STDOUT[@]}" "${REPORT_STDERR[@]}" "${REPORT_RETURN[@]}"

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
    COMPARE_STDOUT=
    COMPARE_STDERR=
    EXPECT=
    EXPECT_ERR=
    EXPECT_RETURN_CODE=
    LOAD_TEST="no"
    SAMPLE=
    TESTED_ARGS=()
    TIMEOUT=
    REPORT_STDOUT=()
    REPORT_STDERR=()
    REPORT_RETURN=()
}

get_result ()
{
    printf '%16s %s\n' "$H1" "" "${PREFIX[@]}" "$H2" "" "sample:" "|${SAMPLE//$NEW_STRING/|$NEW_STRING$INDENT}|"
    if cmp_results
    then
        is_equal "$SAVE_RESULTS" "no" || save_result "$TEST_OK"
    else
        save_result "$TEST_FAILURE"
    fi
    unset_vars
}

run_test_file ()
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
                TEST_NAME="${LINE#:test:}"
                TEST_NAME="${TEST_NAME:-noname}"
                trim_white_space "$TEST_NAME"
                TEST_NAME="$STRING"
                ;;
            :test)
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
                TEST_NAME="${TEST_NAME:-noname}"
                ;;
            *)
                is_equal "$LOAD_TEST" "yes" || continue
                case "${LINE:-}" in
                    :args|:return|:return-code|:timeout)
                        ;;
                    :args:*)
                        is_equal "$LOAD_TEST" "yes" || continue
                        set -- ${LINE#:args:} "${GLOBAL_ARGS[@]}"
                        TESTED_ARGS=( "$@" )
                        ;;
                    :break|:break:*)
                        break
                        ;;
                    :exit|:exit:*)
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
                    :return:*)
                        is_equal "$LOAD_TEST" "yes" || continue
                        set -- ${LINE#:return:}
                        EXPECT_RETURN_CODE="${1:-}"
                        ;;
                    :return-code:*)
                        is_equal "$LOAD_TEST" "yes" || continue
                        set -- ${LINE#:return-code:}
                        EXPECT_RETURN_CODE="${1:-}"
                        ;;
                    :run|:run:*)
                        is_equal "$LOAD_TEST" "yes" || continue
                        PREFIX=(
                            "test file:" "[$TESTED_FILE]"
                            "string num:" "[$STRING_NUM_TEST]"
                            "test name:" "[$TEST_NAME]"
                            "test num:" "[$TEST_NUMBER]"
                        )
                        is_diff "${#TESTED_FILES[@]}" 0 || PREFIX=( "${PREFIX[@]}" "total test num:" "[$TOTAL_TEST_NUMBER]" )
                        NAME_TESTED_FILE="${TESTED_FILE##*/}"
                        NAME_TESTED_FILE="${NAME_TESTED_FILE%.txt}"
                        STDOUT="$PKG_DIR/${NAME_TESTED_FILE}_$STRING_NUM_TEST.out"
                        STDERR="$PKG_DIR/${NAME_TESTED_FILE}_$STRING_NUM_TEST.err"
                        is_diff "${#TESTED_ARGS[@]}" 0 || TESTED_ARGS=( "${GLOBAL_ARGS[@]}" )
                        RETURN_CODE=0
                        timeout "${GLOBAL_TIMEOUT:-"${TIMEOUT:-3}"}" ${TESTED_SHELL:+"$TESTED_SHELL"} "$TESTED_SCRIPT" "${TESTED_ARGS[@]}" <<< "$SAMPLE" > "$STDOUT" 2> "$STDERR" &
                        CHILD_PID="$!"
                        wait "$CHILD_PID"
                        RETURN_CODE="$?"
                        get_result
                        ;;
                    :sample|:sample:*)
                        is_equal "$LOAD_TEST" "yes" || continue
                        NEXT_LINE="sample"
                        ;;
                    :timeout:*)
                        is_equal "$LOAD_TEST" "yes" || continue
                        set -- ${LINE#:args:}
                        TIMEOUT="${1:-}"
                        ;;
                    *)
                        if is_equal "$NEXT_LINE" "expect-stdout"
                        then
                            EXPECT="${EXPECT:+"$EXPECT$NEW_STRING"}${LINE:-}"
                        elif is_equal "$NEXT_LINE" "expect-stderr"
                        then
                            EXPECT_ERR="${EXPECT_ERR:+"$EXPECT_ERR$NEW_STRING"}${LINE:-}"
                        else
                            SAMPLE="${SAMPLE:+"$SAMPLE$NEW_STRING"}${LINE:-}"
                        fi
                esac
        esac
    done < "$TESTED_FILE"
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
    echo "$H1"
    is_empty ${!FAIL[@]} || {
        printf '\033[0;31m%15s\033[0m: \033[1;31m%s\033[0m\n' "${FAIL[@]}"
        get_range_nums
        printf '\033[0;31m%15s\033[0m: [\033[1;31m%s\033[0m]\n' "failed tests" "$RANGE_NUMS"
    }
    printf '\033[0;31m%15s\033[0m: [\033[1;31m%s\033[0m]\n' "failed"     "$FAILED"
    printf '\033[0;32m%15s\033[0m: [\033[1;32m%s\033[0m]\n' "successful" "$SUCCESS"
    is_empty "${SPECIFIC_TEST:-}" || TOTAL_TEST_NUMBER="$SPECIFIC_TEST"
    printf '\033[0;33m%15s\033[0m: [\033[1;33m%s\033[0m]\n' "total tests" "$TOTAL_TEST_NUMBER"
    echo "$H1"
}

run_test ()
{
    is_diff "${!TESTED_FILES[@]}" &&
    for TESTED_FILE in "${TESTED_FILES[@]}"
    do
        is_exists "$TESTED_FILE" || {
            is_exists   "$PKG_DIR/$TESTED_FILE" &&
            TESTED_FILE="$PKG_DIR/$TESTED_FILE"
        } || {
            is_exists   "$PKG_DIR/tests/$TESTED_FILE" &&
            TESTED_FILE="$PKG_DIR/tests/$TESTED_FILE"
        } || die 2 "no such file: -- '$TESTED_FILE'" 2>&3
        run_test_file || break
    done ||
    for TESTED_FILE in "$PKG_DIR"/tests/*.txt
    do
        grep "^[[:blank:]]*${TESTED_FILE##*/}" "$PKG_DIR/tests/.testignor" &>/dev/null && continue
        is_exists "$TESTED_FILE" || die 2 "no such file: -- '$TESTED_FILE'" 2>&3
        run_test_file || break
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
    ARGS=( "args" "clear" "info" "info-off" "save-results" "show-stdout" "show-stderr" "show-retcode" "test-file" "test-num" "timeout" )
    while is_diff $# 0
    do
        case "${1:-}" in
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
            --info)
                INFO="yes"
                INFO_OFF=""
                ;;
            --info-off)
                INFO=""
                INFO_OFF="yes"
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
                    TESTED_FILES+=( "${2:-}" )
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
                    GLOBAL_TIMEOUT="${2:-}"
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
    INDENT="                 |"
    H1="================"
    H2="----------------"
    GLOBAL_ARGS=()
    CLEAR_RESULTS="no"
    SAVE_RESULTS="no"
    TEST_NUM=()
    TEST_OK="$PKG_DIR/test_ok"
    TEST_FAILURE="$PKG_DIR/test_failure"
    TESTED_FILES=()
    TESTED_SHELL="/bin/bash"
    TESTED_SCRIPT="$PKG_DIR/../mdweb.sh"
    FUNC_NAME="[${TESTED_SCRIPT##*/}]"
    SUCCESS=0
    FAILED=0
    FAIL=()
    TOTAL_TEST_NUMBER=0
    LOAD_TEST="no"
    TEST_NUMBER=0
    STRING_NUM=0
    NEW_STRING=$'\n'

    is_exists "$TESTED_SCRIPT" || die 2 "no such file: -- '$TESTED_SCRIPT'" 2>&3
    argparse "$@"
    is_empty "${!TEST_NUM[@]}" || {
        get_test_nums
        SPECIFIC_TEST="${#TEST_NUM[@]}"
    }

    is_equal "$CLEAR_RESULTS" "no" || {
        rm -rf "$TEST_OK"/*.txt &&
        rm -rf "$TEST_FAILURE"/*.txt || die
    }
    run_test
}

out ()
{
    echo
    CHILD_PIDS=( $(ps aux | grep -v grep | grep "${TESTED_SCRIPT##*/}" | awk '{print $2}') )
    # https://stackoverflow.com/questions/1570262/get-exit-code-of-a-background-process#1570356
    kill -9 "${CHILD_PIDS[@]}"
       wait "${CHILD_PIDS[@]}" 2>/dev/null
    get_result
    report >&3
    exit 1
}

trap 'out' INT

main "$@"
