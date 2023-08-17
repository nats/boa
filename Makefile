all: check format test

check:
	shellcheck boa
format:
	shfmt --diff --indent 4 boa
test:
	@bats tests/
