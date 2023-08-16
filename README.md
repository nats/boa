# boa: bash transpiler for modular 

Boa is intended as a minimal bash transpiler for developing *structured* Bash programs while avoiding the typical pitfalls when consuming first- and third- party Bash libraries.

## Features / TODO
- Integrate with existing scripts via either:
  * [X] Add `source <(boa enable)` at top of script; or
  * [X] Change shebang to `#!/usr/bin/env boa`
- [X] New bash command `import` to provide name resolution
- [X] Namespaced module functions
- [ ] Optional aliasing of imported modules
- [ ] Optional aliasing of imported functions
- [ ] Transpile program + imported modules to single-file pure Bash script
- [ ] Unused function elimination

## Installation

Copy the `boa` bash script to a directory in `$PATH` and ensure it is
executable. For example assuming you already have ~/.local/bin in `$PATH`:

```
curl -s https://raw.githubusercontent.com/nats/boa/main/boa -o ~/.local/bin/boa
chmod +x ~/.local/bin/boa
```

For system wide installation:

```
sudo bash <<'EOF'
curl -s https://raw.githubusercontent.com/nats/boa/main/boa -o /usr/local/bin/boa
chmod +x /usr/local/bin/boa
EOF
```

## Quick Start

This tutorial demonstrate the core `import `*`module`* functionality of Boa,
and how per-module namespaces are utilised.

Create a new directory for your Boa project:

```bash
mkdir boa-test-project
cd boa-test-project
```

Boa modules are regular Bash scripts, placed into a particular directory
structure.  Boa searches for modules in `$BOAPATH`, which defaults to `./lib`.

We will start by creating an unrealistically simple logging module:

```bash
mkdir lib
cat >lib/logging.bash <<'EOF'

.write() {
    local level="$1" msg="${*:2}"
    printf "%(%X)T [%s] %s\n" -1 "${level}" "${msg}"
}

.debug() {
    .write DEBUG "$@"
}

EOF
```

The logging module is standard Bash script. The only thing that may stand out
is the leading period in the function name:  `.debug` instead of `debug`. This
is valid Bash syntax used by Boa functions.

To utilise the logging module, we create a Bash script that imports the
`logging` module and call its `debug` function:

```
cat >test_script <<'EOF'
#!/usr/bin/env boa
import logging

logging.debug "Hello world!"
EOF

chmod +x test_script
./test_script
```

The output of `./test_script` is:

```
00:59:47 [DEBUG] Hello world!
```

Notice that we called the `.debug` function defined in `lib/logging.bash` by
combining the module name and function name into `logging.debug`. By
comparison, the `.debug` function when calling function within the same module
does so without the module name:  `.write DEBUG "$@"`. 

Within Boa modules, it is useful to think of the leading period as indicating
*this module*: `.debug() { ... }` defines `debug` in *this module*, and
`.write DEBUG "$@"` calls `write` in *this module*.

### Module namespaces

Because each Boa module has its own function namespace, other modules may also
define their own `.debug` function.

We will create a second module named `yell`, which writes its output in caps:

```
cat >lib/yell.bash <<'EOF'

.write() {
    local level="$1" msg="${*:2}"
    printf "%s!! %s\n" "${level}" "${msg^^}"
}

.debug() {
    .write debug "$@" 
}

EOF
```

Along with a second test script that imports both modules:

```
cat >test_script2 <<'EOF'
#!/usr/bin/env boa
import logging
import yell

logging.debug "Hello world!"
yell.debug "Hello again."
EOF

chmod +x test_script2
./test_script2
```

The output of `./test_script2` is:

```
01:05:53 [DEBUG] Hello world!
DEBUG!! HELLO AGAIN.
```

Each module has its own function namespace, and can pick short, clear names for
each function without being concerned with overwriting a function defined
elsewhere.

## Usage

There are a few different ways to integrate `boa` with an existing Bash script:

1. Place the following line at the top of the script - immediately after the
shebang line, if there is one.

```bash
source <(boa enable)
```

2. Place `boa` into script shebang - the very first line of file - instead of `bash`:

```bash
#!/usr/bin/env boa
```

3. Run the script directly from command line:

```bash
boa run my_script.bash
```

## Writing modules

Boa modules are written in standard Bash, but require a few conventions to be
followed:

1. A module's filename may contain lowercase letters, numbers, and underscore.
The first character may not be a number.  The file extension must be `.bash`.

2. The only commands that should appear in a Boa module are a) `import
`*`module`*, and b) function definitions. This maximises the re-usability of
the module by allowing the importing script to determine if and when to invoke
module functionality.

3. Boa requires each function in a module to begin with a leading period. Due
to the dynamicness of Bash, this "dot-function" naming convention is used to
disambiguate between function calls and unrelated string values.

4. Conversely, the dot-function name must not appear in the module except when a) defining the
function and b) calling the function from another function in the same module.
Error messages, debug log entries and the like must use the "dotless"
function name. For example output a string:  `echo "get_foobar() failed"`
instead of `echo ".get_foobar() failed"`.

5. Modules may import other modules and should do so when makes sense to do so.


## FAQ

## What's wrong with plain bash?

Bash as a language has a variety of pitfalls, but a combination of experience
and judicious use of shellcheck can avoid many problems. The typical advice for
when a Bash program belongs overly long is to rewrite in a "real" language, and
while that is often good advice there are problem domains where Bash (and
shells in general) thrive as few other languages have such direct and concise
facilities for interacting with processes.

When working in such a problem domain, rather than rewrite existing code the
polyglot programmer will reach for the obvious solution - refactor their
program into multiple files that are imported via the `source` builtin.
Unfortunately `source` is rather limited in what it can do: see
[PROBLEMS.md](PROBLEMS.md) for an overview of the various problems that Boa
seeks to address.
