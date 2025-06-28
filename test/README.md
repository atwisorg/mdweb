**Description**

- Test files are located in the `tests` directory and have the `txt` extension.\
- To disable a specific test file, add its name to the file: `tests/.testignor`.\
- The results of each test are stored in the `test_ok` and `test_failure` directories.
- The name of the file with test results is created based on the name of the test file with the addition of the line number in which the completed test is located.
- By default, the `test_ok` directory is cleared automatically, but the `test_failure` directory is not.

**Run all tests**

```
./test.sh
```

**Run a specific test file**

```
./test.sh --test-file test_tag_p.txt ...
```

> file `.testignor` is not used

**Pass arguments to the script under test**

```
./test.sh --args -c -f
```

**Saving test results, including successful**

```
./test.sh --save-results
```

**Clear the test_ok and test_failure directories from previous testing**

```
./test.sh --clear
```
