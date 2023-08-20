setup_suite() {
    BOADIR="$( dirname "$(readlink -f "$BATS_TEST_FILENAME")" )/.."
    PATH="$BOADIR:$BOADIR/src:$PATH"
    export BOADIR PATH
    export BOAPATH="$BOADIR/src:$BATS_TEST_DIRNAME/samples"
}
