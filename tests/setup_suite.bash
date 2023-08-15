setup_suite() {
    BOADIR="$( dirname "$(readlink -f "$BATS_TEST_FILENAME")" )/.."
    PATH="$BOADIR:$PATH"
    export BOADIR PATH
    export BOAPATH="$BATS_TEST_DIRNAME/samples"
}
