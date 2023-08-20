all: check format build test

check:
	shellcheck src/*.bash src/**/*.bash
format:
	shfmt --diff --indent 4 src/*.bash src/**/*.bash
build:
	BOAPATH=src bash src/boa.bash build boa bin/boa.new
	shellcheck bin/boa.new
	mv bin/boa.new bin/boa
	chmod +x bin/boa
test:
	@bats --print-output-on-failure tests/
