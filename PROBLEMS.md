# Problems with Bash program development

The obvious approach to take when developing a Bash program that 
1. is in a problem domain well suited to Bash, but
2. can no longer be comfortably developed within a single script file
is to group functions by purpose into separate files that are utilised via the
`source` builtin.

The obvious next step from there when developing unrelated Bash programs is to
extract common functionality and reuse it across multiple programs.

This approach in the context of Bash has a number of problems detailed here.

## `source` filename resolution

Unlike similar constructs in other languages, `source` does not have its own
resolution process. To quote bash manual: 

> "`source filename [arguments]`: If filename does not contain a slash,
> filenames in PATH are used to find the directory containing filename. The
> file searched for in PATH need not be executable."

Since PATH is otherwise used to find executable programs, it would generally be
poor form to place our module at `/usr/local/bin/my_module.bash`. One may be
tempted to add the current directory with `PATH=.:$PATH`, but that only works
if the working directory is set correctly. Many programmers will end up with
something like:

```bash
declare SCRIPT_DIR
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"  # "$0" is wrong, see next section

# Modules then loaded via either mutating PATH:
PATH="${SCRIPT_DIR}:${PATH}"
source my_module.bash

# Or using SCRIPT_DIR to create absolute references:
source "${SCRIPT_DIR}"/my_module.bash
```

The mutated PATH approach only works for a single directory: third-party Bash
modules need to be either placed in the same directory as the script, or
additional entries added to PATH. While that somewhat works, since the modules
are all "flattened" into a single resolution namespace one needs to ensure
module names in one directory do not shadow the other.

### Use of nested `source`

If a `source`ed module needs  to `source` its own submodule then the problem
reoccurs, and if that submodule is in a different directory the above solution
does not work because `"$0"` is the name of the invoked script, not the module.
The end result is that every module that needs to source another module must
determine its own location in the filesystm, so after consulting the manual
perhaps one tries:

```bash
declare SCRIPT_DIR
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"  # also wrong...
source "${SCRIPT_DIR}"/submodule.bash
```

While `"${BASH_SOURCE[0]}"` will indeed provide the name passed to `source
FILENAME`, there's a new problem: the commands executed by `source` run in the
same scope. In general that is good and necessary - if `source` had its own
scope like function calls do, then variables created via `declare` would
immediately go out of scope at completion of the `source` builtin.

The problem is that if the script loading this module also uses name
`SCRIPT_DIR` per the earlier example, its value has now been changed and later
`source` attempts by the first script will fail.

This makes creating a Bash library package intended for third-party use,
rather difficult to get right. The only robust solution is to try and use
a unique variable name for each module.

If developing a Bash library intended for third-party consumption, the robust
approach is to avoid using "global" variables whenever possible; and instead
source its own modules verbosely via:

```bash
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/submodule1.bash
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/submodule2.bash
```

## Function namespace collisions

Variables in bash share a single namespace, but not a single scope. Variables
created by the `local` or `declare` (without `-g`) builtin are dynamically
scoped to the currently executing function.

This allows third party libraries to use whatever variables names they like, as
long as variable usage is restricted to within functions:

```bash
# --- third-party/library.bash
do_thing() {
    local value
    value=2
    echo "library: ${value}"  # prints '2' to stdout
}

# --- my_script
value=1
source third-party/library.bash  # ignoring name resolution for clarity
do_thing
echo "script: ${value}"  # prints '1' to stdout
```

The same is not true of Bash functions. Function definitions are implicitly
"global", and never go out of scope - even if defined within some other function:

```bash
# --- third-party/library.bash
library_setup() {
    # ... do some initialization
    foo() {
        echo "clobbered"
    }

# --- my_script
foo() {
    echo "foo"
}

library_setup
foo  # prints 'clobbered" to stdout
```

Redefining `foo()` is not an error unless it was previously protected via the
relatively unknown `readonly -f foo` which package authors cannot rely on
consuming programs to use. Even if the caller did mark their functions
readonly, there is no simple solution available at runtime.

Given that all functions within the Bash program must co-exist in a single
namespace, the obvious solution for third-party Bash packages is to prepend all
function names with some package identifier. For example, if `foobar` package
provides a `string` module containing various functions, they may be named:

```bash
foobar_string_trim() {
  ...
}

foobar_string_trim_all() {
  ...
}

foobar_string_split() {
  ...
}
```

Unfortunately this just trades one problem - namespace collisions - for
another. The functions provided by the `foobar` package are not likely to
have same name as any others, but the verbose names are difficult to remember
for intended consumers of the package.

### Execution time

Bash does not utilise any form of bytecode or caching of the code provided to
it. For any sort of Bash program intended for frequent or interactive use, this
poses a serious roadblock for potential consumers of feature-filled Bash
packages: every line of Bash code executed by `source` requires processor time,
every time the Bash program is executed, even if many of those functions are
never used.

For example, consider if Bash package `foobar` wanted to provide an
full-featured "standard library". The standard library of many languages
contains hundreds of functions and tens-of-thousands of lines of code. `foobar`
want their package to be easy to use, so they direct consumers to just add one
line to their program:

```bash
--- my_script
source foobar.bash
```

Now `my_script` has access to all 300 functions created by `foobar`.. but
`my_script` only needs to use 5. Unfortunately, all 300 will be parsed by Bash
- every time `my_script` is executed - just so those 5 functions can be called.

Library provider `foobar` recognises this problem and breaks their package up
into 10 modules categorised by function purpose, with average of 30 functions
per module. Consumers are directed to source only the module(s) they use, with
`foobar` correctly asserting that majority of consumers will not require all
10 of their modules.

Our fictious `my_script` only needs 3 of the modules, but unfortunately they
are 3 of the biggest modules resulting in 140 functions being parsed on each
execution.

The problem has been reduced somewhat, but cant easily be eliminated: `foobar`
of course could provide an individual module for each of their 300 functions,
but that is rather unwieldy for their consumers.
