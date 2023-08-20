load boa
@import boa

@test "single function" {
    run boa::get_function_names "$BATS_TEST_DIRNAME"/samples/single.bash
    [[ .foo == "${output}" ]]
}

@test "compat function" {
    run boa::get_function_names "$BATS_TEST_DIRNAME"/samples/single_compat.bash
    [[ foo == "${output}" ]]
}


@test "multiple functions" {
    expected=( ._print ._stdin  ._timestamp .crit .debug .fail .info .note .pass .trace .trap .warn )
    run boa::get_function_names "$BATS_TEST_DIRNAME"/samples/multiple.bash
    [[ "${expected[*]}" == "${lines[*]}" ]]
}

