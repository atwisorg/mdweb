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

save_result ()
{
    STATUS=":test:$TEST_NAME$NEW_STRING"
    is_equal "${#TESTED_ARGS[@]}" 0 ||
    STATUS="$STATUS:args:${TESTED_ARGS[@]}$NEW_STRING"
    STATUS="$STATUS${EXPECT:+:expect$NEW_STRING$EXPECT$NEW_STRING}"
    STATUS="$STATUS${EXPECT_ERR:+:expect-err$NEW_STRING$EXPECT_ERR$NEW_STRING}"
    STATUS="$STATUS:sample$NEW_STRING$SAMPLE$NEW_STRING:run$NEW_STRING$NEW_STRING"
    STATUS="$STATUS:stdout$NEW_STRING${STDOUT_RESULT:-}$NEW_STRING"
    STATUS="$STATUS:stderr$NEW_STRING${STDERR_RESULT:-}$NEW_STRING-------"
    echo "$STATUS" > "$1/${NAME_TESTED_FILE}_$STRING_NUM_TEST.txt"
}

cmp_results ()
{
    RETURN=0 STDOUT_RESULT= STDERR_RESULT=
    is_empty "${EXPECT:-}" || {
        STDOUT_RESULT="$(cat "$STDOUT")"
        if is_equal "${STDOUT_RESULT:-}" "$EXPECT"
        then
            echo -e "       stdout: |\033[1;32m${STDOUT_RESULT//$NEW_STRING/\\033\[0m|$NEW_STRING$INDENT\\033\[1;32m}\033[0m|"
            SUCCESS="$((SUCCESS+1))"
            is_equal "$SAVE_RESULTS" "yes" || rm -f "$STDOUT"
        else
            echo -e "       expect: |\033[0;33m${EXPECT//$NEW_STRING/\\033\[0m|$NEW_STRING$INDENT\\033\[0;33m}\033[0m|"
            echo -e "       stdout: |\033[1;31m${STDOUT_RESULT//$NEW_STRING/\\033\[0m|$NEW_STRING$INDENT\\033\[1;31m}\033[0m|"
            FAIL+=( "$(sed 's/[[:blank:]]\+/ /g' <<< "${PREFIX//$NEW_STRING/}: stdout" )" )
            RETURN=1
        fi
    }
    is_empty "${EXPECT_ERR:-}" || {
        STDERR_RESULT="$(cat "$STDERR")"
        if is_equal "${STDERR_RESULT:-}" "$EXPECT_ERR"
        then
            echo -e "       stderr: |\033[1;32m${STDERR_RESULT//$NEW_STRING/\\033\[0m|$NEW_STRING$INDENT\\033\[1;32m}\033[0m|"
            SUCCESS="$((SUCCESS+1))"
            is_equal "$SAVE_RESULTS" "yes" || rm -f "$STDERR"
        else
            echo -e "expect-stderr: |\033[0;33m${EXPECT_ERR//$NEW_STRING/\\033\[0m|$NEW_STRING$INDENT\\033\[0;33m}\033[0m|"
            echo -e "       stderr: |\033[1;31m${STDERR_RESULT//$NEW_STRING/\\033\[0m|$NEW_STRING$INDENT\\033\[1;31m}\033[0m|"
            FAIL+=( "$(sed 's/[[:blank:]]\+/ /g' <<< "${PREFIX//$NEW_STRING/}: stderr" )" )
            RETURN=1
        fi
    }
    rm -f "$STDOUT" "$STDERR"
    return "$RETURN"
}

run_test_file ()
{
    while IFS= read -r LINE || is_not_empty "${LINE:-}"
    do
        STRING_NUM="$((STRING_NUM + 1))"
        case "${LINE:-}" in
            \#:test|\#:test:*)
                LOAD_TEST="no"
                continue
                ;;
            :test:*)
                LOAD_TEST="yes"
                TEST_NUMBER="$((TEST_NUMBER + 1))"
                STRING_NUM_TEST="$STRING_NUM"
                TEST_NAME="${LINE#:test:}"
                TEST_NAME="${TEST_NAME:-noname}"
                ;;
            :test)
                LOAD_TEST="yes"
                TEST_NUMBER="$((TEST_NUMBER + 1))"
                STRING_NUM_TEST="$STRING_NUM"
                TEST_NAME="${TEST_NAME:-noname}"
                ;;
            :expect|:expect-out|:expect-stdout|:expect:*|:expect-out:*|:expect-stdout:*)
                NEXT_LINE="expect-stdout"
                ;;
            :expect-err|:expect-stderr|:expect-err:*|:expect-stderr:*)
                NEXT_LINE="expect-stderr"
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
                PREFIX="    test file: [$TESTED_FILE]$NEW_STRING         test: [$TEST_NAME] num: [$TEST_NUMBER]$NEW_STRING       string: [$STRING_NUM_TEST]"
                NAME_TESTED_FILE="${TESTED_FILE##*/}"
                NAME_TESTED_FILE="${NAME_TESTED_FILE%.txt}"
                STDOUT="$PKG_DIR/${NAME_TESTED_FILE}_$STRING_NUM_TEST.out"
                STDERR="$PKG_DIR/${NAME_TESTED_FILE}_$STRING_NUM_TEST.err"
                is_diff "${#TESTED_ARGS[@]}" 0 || TESTED_ARGS=( "${GLOBAL_ARGS[@]}" )
                ${TESTED_SHELL:+"$TESTED_SHELL"} "$TESTED_SCRIPT" "${TESTED_ARGS[@]}" <<< "$SAMPLE" > "$STDOUT" 2> "$STDERR"
                echo "=============$NEW_STRING$PREFIX$NEW_STRING-------------$NEW_STRING       sample: |${SAMPLE//$NEW_STRING/|$NEW_STRING$INDENT}|$NEW_STRING-------------"
                if cmp_results
                then
                    is_equal "$SAVE_RESULTS" "no" || save_result "$TEST_OK"
                else
                    save_result "$TEST_FAILURE"
                fi
                EXPECT= EXPECT_ERR= SAMPLE= LOAD_TEST="no" TESTED_ARGS=()
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
    echo "============="
    echo "   successful: [$SUCCESS]"
    echo "       failed: [${#FAIL[@]}]"
        for FAIL in "${FAIL[@]}"
        do
            echo "   $FAIL"
        done
    echo "============="
}

main ()
{
    exec 3>&1
    get_pkg_vars
    INDENT="               |"
    GLOBAL_ARGS=()
    CLEAR_RESULTS="no"
    SAVE_RESULTS="no"
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
                shift
                while is_diff $# 0
                do
                    is_diff "${1:-}" "--args"         &&
                    is_diff "${1:-}" "--clear"        &&
                    is_diff "${1:-}" "--save-results" &&
                    is_diff "${1:-}" "--test-file"    || break
                    GLOBAL_ARGS+=( "${1:-}" )
                    shift
                done
                ;;
            --test-file)
                shift
                while is_diff $# 0
                do
                    is_diff "${1:-}" "--args"         &&
                    is_diff "${1:-}" "--clear"        &&
                    is_diff "${1:-}" "--save-results" &&
                    is_diff "${1:-}" "--test-file"    || break
                    TESTED_FILES+=( "${1:-}" )
                    shift
                done
                ;;
            --clear)
                CLEAR_RESULTS="yes"
                shift
                ;;
            --save-results)
                SAVE_RESULTS="yes"
                shift
                ;;
            *)
                GLOBAL_ARGS+=( "${1:-}" )
                shift
        esac
    done
    FUNC_NAME="[${TESTED_SCRIPT##*/}]"
    SUCCESS=0
    FAIL=()
    TOTAL_TESTS=0
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
        is_exists "$TESTED_FILE" || die 2 "no such file: -- '$TESTED_FILE'" 2>&3
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
