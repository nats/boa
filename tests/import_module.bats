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