load boa
@import boa

setup() {
    mkdir "$BATS_TEST_TMPDIR"/bin "$BATS_TEST_TMPDIR"/src
    BOAPATH="$BATS_TEST_TMPDIR/src"
    test_module="${BOAPATH}/test.bash"
    test_output="$BATS_TEST_TMPDIR"/bin/test
}

@test "empty file" {
    touch "${test_module}"
    boa::build_module test "${test_output}"

    [ -e "${test_output}" ]
    [ "$(cat "${test_output}")" = "" ]
}

@test "executable bit is preserved" {

}
