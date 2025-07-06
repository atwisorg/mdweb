# Testing

**Description**

- Test files are located in the `tests` directory and have the `txt` extension.
- To disable a specific test file, add its name to the file: `tests/.testignor`.
- The results of each test are stored in the `test_ok` and `test_failure` directories.
- The name of the file with test results is created based on the name of the test file with the addition of the line number in which the completed test is located.
- By default, the `test_ok` directory is cleared automatically, but the `test_failure` directory is not.

## Run test

**Run all tests**

```
./test.sh [OPTIONS]
```

**Options**

```
  --args ARG...             pass options to the program under test
  --clear                   delete the saved results of the previous test
                            before starting testing
  --save-results            save all test results;
                            by default, only the results of failed tests are saved
  --test-file TEST_FILE...  specify the test file;
                            file `.testignor` is not used
  --test-num NUM ...        specify test numbers separated by commas/spaces
                            and/or ranges of test numbers to run
```

## Test file syntax

The test program reads the test file line by line, recognizing keywords I ignore empty lines until the test body is encountered.
Tests can be located in a single file, or each in its own file.
The body of each test must start with the keyword ***`:test`*** and end with the keyword ***`:run`***.
The order of other keywords in the body of the test does not matter.

### Keywords

***`:test`***

Start of the test body. If desired, you can specify the test name:`:test:name test`

***`:args`***

Pass options to the test program for the current test

***`:sample`***

Test data. All subsequent lines are loaded, including empty ones, until the end of the test file or until the next keyword.

***`:expect`***

Expected result received on `stdout` from the program under test

***`:expect-err`***

Expected result received on `stderr` from the program under test

***`:return`***

Expected return code of the program under test

***`:run`***

Run the test

### Control keywords

***`:break`***

Abort further execution of tests in the current test file

***`:exit`***

Abort execution of all test files
