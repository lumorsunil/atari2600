run_test() {
    set +e
    test_name="$1"
    printf "Running test $test_name... "
    if ! (cd tests && bash "$1.test.sh" &>test.log); then
        printf "failed.\n"
        return 1
    else
        printf "passed.\n"
    fi
}

if ! (
    set -e
    run_test "decoder-regression"
    #run_test "failing"
); then
    echo ""
    echo "Test output:"
    echo ""
    tail tests/test.log -n 10
    echo ""
    echo "Failed."
else
    echo "All tests passed."
fi
