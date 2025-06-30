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
    STATUS="$STATUS:sample: |$NEW_STRING${SAMPLE:+$SAMPLE$NEW_STRING}:run:$NEW_STRING$NEW_STRING"
    STATUS="$STATUS:stdout: |$NEW_STRING${STDOUT_RESULT:+$STDOUT_RESULT$NEW_STRING}"
    STATUS="$STATUS:stderr: |$NEW_STRING${STDERR_RESULT:+$STDERR_RESULT$NEW_STRING}:end:"
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
            echo "         stdout: $(success_out "$STDOUT_RESULT")"
            SUCCESS="$((SUCCESS+1))"
            is_equal "$SAVE_RESULTS" "yes" || rm -f "$STDOUT"
        else
            echo "  expect-stdout: $(expect_out "$EXPECT")"
            echo "         stdout: $(failed_out "$STDOUT_RESULT")"
            FAIL+=( "$(sed 's/[[:blank:]]\+/ /g' <<< "${PREFIX//$NEW_STRING/}: stdout" )" )
            RETURN=1
        fi
    }

    is_empty "${COMPARE_STDERR:-}" && {
        if is_empty "${COMPARE_STDOUT:-}"
        then
            echo "         stdout: $(info_out "$STDOUT_RESULT")"
            echo "         stderr: $(info_out "$STDERR_RESULT")"
        else
            is_equal "$RETURN" 0 ||
            echo "         stderr: $(info_out "$STDERR_RESULT")"
        fi
    } || {
        if is_equal "${STDERR_RESULT:-}" "$EXPECT_ERR"
        then
            echo "         stderr: $(success_out "$STDOUT_RESULT")"
            SUCCESS="$((SUCCESS+1))"
            is_equal "$SAVE_RESULTS" "yes" || rm -f "$STDERR"
        else
            is_not_empty "${COMPARE_STDOUT:-}" ||
            echo "         stdout: $(info_out "$STDOUT_RESULT")"
            echo "  expect-stderr: $(expect_out "$EXPECT_ERR")"
            echo "         stderr: $(success_out "$STDERR_RESULT")"
            FAIL+=( "$(sed 's/[[:blank:]]\+/ /g' <<< "${PREFIX//$NEW_STRING/}: stderr" )" )
            RETURN=1
        fi
    }
    return "$RETURN"
}

check_test_num ()
{
    grep "\<$TOTAL_TEST_NUMBER\>" <<< "${TEST_NUM[@]}" &>/dev/null
}

trim_white_space ()
{
    STRING="${1#"${1%%[![:blank:]]*}"}"
    STRING="${STRING%"${STRING##*[![:blank:]]}"}"
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
                LOAD_TEST="no"
                TEST_NUMBER="$((TEST_NUMBER + 1))"
                TOTAL_TEST_NUMBER="$((TOTAL_TEST_NUMBER + 1))"
                continue
                ;;
            :test:*)
                TEST_NUMBER="$((TEST_NUMBER + 1))"
                TOTAL_TEST_NUMBER="$((TOTAL_TEST_NUMBER + 1))"
                is_equal "${#TEST_NUM[@]}" 0 || check_test_num || continue
                LOAD_TEST="yes"
                STRING_NUM_TEST="$STRING_NUM"
                TEST_NAME="${LINE#:test:}"
                TEST_NAME="${TEST_NAME:-noname}"
                trim_white_space "$TEST_NAME"
                TEST_NAME="$STRING"
                ;;
            :test)
                LOAD_TEST="yes"
                TEST_NUMBER="$((TEST_NUMBER + 1))"
                STRING_NUM_TEST="$STRING_NUM"
                TEST_NAME="${TEST_NAME:-noname}"
                ;;
            :expect|:expect-out|:expect-stdout|:expect:*|:expect-out:*|:expect-stdout:*)
                NEXT_LINE="expect-stdout"
                COMPARE_STDOUT="yes"
                ;;
            :expect-err|:expect-stderr|:expect-err:*|:expect-stderr:*)
                NEXT_LINE="expect-stderr"
                COMPARE_STDERR="yes"
                ;;
            :args)
                ;;
            :args:*)
                is_equal "$LOAD_TEST" "yes" || continue
                set -- ${LINE#:args:} "${GLOBAL_ARGS[@]}"
                TESTED_ARGS=( "$@" )
                ;;
            :sample|:sample:*)
                is_equal "$LOAD_TEST" "yes" || continue
                NEXT_LINE="sample"
                ;;
            :run|:run:*)
                is_equal "$LOAD_TEST" "yes" || continue
                PREFIX="      test file: [$TESTED_FILE]$NEW_STRING     string num: [$STRING_NUM_TEST]$NEW_STRING      test name: [$TEST_NAME]$NEW_STRING       test num: [$TEST_NUMBER]"
                is_diff "${#TESTED_FILES[@]}" 0 || PREFIX="$PREFIX${NEW_STRING} total test num: [$TOTAL_TEST_NUMBER]"
                NAME_TESTED_FILE="${TESTED_FILE##*/}"
                NAME_TESTED_FILE="${NAME_TESTED_FILE%.txt}"
                STDOUT="$PKG_DIR/${NAME_TESTED_FILE}_$STRING_NUM_TEST.out"
                STDERR="$PKG_DIR/${NAME_TESTED_FILE}_$STRING_NUM_TEST.err"
                is_diff "${#TESTED_ARGS[@]}" 0 || TESTED_ARGS=( "${GLOBAL_ARGS[@]}" )
                ${TESTED_SHELL:+"$TESTED_SHELL"} "$TESTED_SCRIPT" "${TESTED_ARGS[@]}" <<< "$SAMPLE" > "$STDOUT" 2> "$STDERR"
                echo "================$NEW_STRING$PREFIX$NEW_STRING----------------$NEW_STRING         sample: |${SAMPLE//$NEW_STRING/|$NEW_STRING$INDENT}|$NEW_STRING----------------"
                if cmp_results
                then
                    is_equal "$SAVE_RESULTS" "no" || save_result "$TEST_OK"
                else
                    save_result "$TEST_FAILURE"
                fi
                COMPARE_STDOUT= COMPARE_STDERR= EXPECT= EXPECT_ERR= SAMPLE= LOAD_TEST="no" TESTED_ARGS=()
                ;;
            :break|:break:*)
                break
                ;;
            :exit|:exit:*)
                return 1
                ;;
            *)
                is_equal "$LOAD_TEST" "yes" || continue
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
    done < "$TESTED_FILE"
}

report ()
{
    echo "================"
        for FAIL in "${FAIL[@]}"
        do
            echo -e "     \033[0;31m$FAIL\033[0;30m"
        done
    echo -e "
         \033[0;31mfailed\033[0m: [\033[1;31m${#FAIL[@]}\033[0m]
     \033[0;32msuccessful\033[0m: [\033[1;32m$SUCCESS\033[0m]"
    is_empty "${!TEST_NUM[@]}" || TOTAL_TEST_NUMBER="${#TEST_NUM[@]}"
    echo -e "    \033[0;33mtotal tests\033[0m: [\033[1;33m$TOTAL_TEST_NUMBER\033[0m]
================"
}

main ()
{
    exec 3>&1
    get_pkg_vars
    INDENT="                 |"
    GLOBAL_ARGS=()
    CLEAR_RESULTS="no"
    SAVE_RESULTS="no"
    TEST_NUM=()
    TEST_OK="$PKG_DIR/test_ok"
    TEST_FAILURE="$PKG_DIR/test_failure"
    TESTED_FILES=()
    TESTED_SHELL="/bin/bash"
    TESTED_SCRIPT="$PKG_DIR/../mdweb.sh"
    is_exists "$TESTED_SCRIPT" || die 2 "no such file: -- '$TESTED_SCRIPT'" 2>&3
    while is_diff $# 0
    do
        case "${1:-}" in
            --args)
                while is_diff $# 0
                do
                    is_not_empty "${2:-}"             &&
                    is_diff "${2:-}" "--args"         &&
                    is_diff "${2:-}" "--clear"        &&
                    is_diff "${2:-}" "--save-results" &&
                    is_diff "${2:-}" "--test-file"    &&
                    is_diff "${2:-}" "--test-num"     || break
                    GLOBAL_ARGS+=( "${2:-}" )
                    shift
                done
                ;;
            --clear)
                CLEAR_RESULTS="yes"
                ;;
            --save-results)
                SAVE_RESULTS="yes"
                ;;
            --test-file)
                while is_diff $# 0
                do
                    is_not_empty "${2:-}"             &&
                    is_diff "${2:-}" "--args"         &&
                    is_diff "${2:-}" "--clear"        &&
                    is_diff "${2:-}" "--save-results" &&
                    is_diff "${2:-}" "--test-file"    &&
                    is_diff "${2:-}" "--test-num"     || break
                    TESTED_FILES+=( "${2:-}" )
                    shift
                done
                ;;
            --test-num)
                while is_diff $# 0
                do
                    is_not_empty "${2:-}"             &&
                    is_diff "${2:-}" "--args"         &&
                    is_diff "${2:-}" "--clear"        &&
                    is_diff "${2:-}" "--save-results" &&
                    is_diff "${2:-}" "--test-file"    &&
                    is_diff "${2:-}" "--test-num"     || break
                    TEST_NUM+=( "${2:-}" )
                    shift
                done
                ;;
            *[!0-9,-]*)
                GLOBAL_ARGS+=( "${1:-}" )
                ;;
            *)
                TEST_NUM+=( "${1:-}" )
        esac
        shift
    done

    is_equal "${#TEST_NUM[@]}" 0 || get_test_nums

    FUNC_NAME="[${TESTED_SCRIPT##*/}]"
    SUCCESS=0
    FAIL=()
    TOTAL_TEST_NUMBER=0
    LOAD_TEST="no"
    TEST_NUMBER=0
    STRING_NUM=0
    NEW_STRING='
'
    is_equal "$CLEAR_RESULTS" "no" || {
        rm -rf "$TEST_OK"/*.txt &&
        rm -rf "$TEST_FAILURE"/*.txt || die
    }

    is_diff "${#TESTED_FILES[@]}" 0 &&
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

main "$@"
