source boa

setup() {
    BOAPATH="$BATS_TEST_TMPDIR"
    test_module="${BOAPATH}/test.bash"
    cat > "${test_module}" <<'EOT'
.get() { true; }
EOT
}

add() {
    echo "$*" >> "${test_module}"
}

@test "function name" {
    run boa::import_module test
    [ "$output" = 'test.get() { true; }' ]
}

@test "function call" {
    add '.get value'
    run boa::import_module test
    [ "${lines[1]}" = 'test.get value' ]
}

@test "unrelated function call" {
    add 'other.get value'
    run boa::import_module test
    [ "${lines[1]}" = 'other.get value' ]
}

@test "command substitution" {
    add 'echo "$(.get value)"'
    run boa::import_module test
    [ "${lines[1]}" = 'echo "$(test.get value)"' ]
}

@test "alternate disambiguation" {
    add '@get2() { true; }'
    run boa::import_module test
    [ "${lines[1]}" = 'test.get2() { true; }' ]
}

@test "multibyte disambiguation" {
    add '.::get2() { true; }'
    run boa::import_module test
    [ "${lines[1]}" = 'test.get2() { true; }' ]
}

@test "alternate separator" {
    BOASEP=:: run boa::import_module test
    [ "$output" = 'test::get() { true; }' ]
}

@test "namespace import" {
    mkdir "${BOAPATH}/testns"
    mv "${test_module}" "${BOAPATH}/testns"

    run boa::import_module testns.test
    [ "$output" = 'testns.test.get() { true; }' ]
}

@test "alias import" {
    BOASEP=:: run boa::import_module foobar=test
    [ "$output" = 'foobar::get() { true; }' ]
}

@test "alias namespace import" {
    mkdir "${BOAPATH}/testns"
    mv "${test_module}" "${BOAPATH}/testns"

    run boa::import_module froz=testns.test
    [ "$output" = 'froz.get() { true; }' ]
}