# Explicitly reference Makefile build output
source <("$( dirname "$(readlink -f "$BATS_TEST_FILENAME")" )/../bin/boa" enable)
