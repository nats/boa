all:
	shellcheck boa
	shfmt --diff --indent 4 boa
	@bats tests/
