run_test() {
    set +e
    test_name="$1"
    printf "Running test $test_name... "
    if ! (cd tests && bash "$1.test.sh" &>/dev/null); then
        echo "failed."
        return 1
    else
        echo "passed."
    fi
}

if ! (
    set -e
    run_test "decoder-regression"
    #run_test "failing"
); then
    echo "Test failed."
else
    echo "All tests passed."
fi
