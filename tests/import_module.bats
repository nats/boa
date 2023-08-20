load boa
@import boa

setup() {
    export BOAPATH="$BATS_TEST_TMPDIR"
    test_module="${BOAPATH}/test.bash"
    cat > "${test_module}" <<'EOT'
.get() { true; }
EOT
}

add() {
    echo "$*" >> "${test_module}"
}

assert_parse() {
    add "${1}"
    run boa::import_module test
    [ "${lines[1]}" = "${2}" ]
}

@test "function name" {
    run boa::import_module test
    [ "$output" = 'test::get() { true; }' ]
}

@test "function call" {
    assert_parse '.get value' 'test::get value'
}

@test "unrelated function call" {
    assert_parse 'other.get value' 'other.get value'
}

@test "indented bare name is ignored" {
    assert_parse '    get value' '    get value'
}

@test "command substitution" {
    assert_parse 'echo "$(.get value)"' 'echo "$(test::get value)"'
}

@test "process substitution" {
    assert_parse 'cat <(.get value)' 'cat <(test::get value)'
}

@test "alternate disambiguation" {
    assert_parse '@get2() { true; }' 'test::get2() { true; }'
}

@test "multibyte disambiguation" {
    assert_parse '.::get2() { true; }' 'test::get2() { true; }'
}

@test "alternate separator" {
    BOASEP=:: run boa::import_module test
    [ "$output" = 'test::get() { true; }' ]
}

@test "namespace import" {
    mkdir "${BOAPATH}/testns"
    mv "${test_module}" "${BOAPATH}/testns"

    run boa::import_module testns::test
    [ "$output" = 'testns::test::get() { true; }' ]
}

@test "alias import" {
    BOASEP=. run boa::import_module foobar=test
    [ "$output" = 'foobar.get() { true; }' ]
}

@test "alias namespace import" {
    mkdir "${BOAPATH}/testns"
    mv "${test_module}" "${BOAPATH}/testns"

    run boa::import_module froz=testns::test
    [ "$output" = 'froz::get() { true; }' ]
}