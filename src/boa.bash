#!/bin/bash
: "${BOAPATH:=lib}"
: "${BOASEP:=::}"

.help() {
    cat <<'EOT'
boa COMMAND

Available commands:
    build PKG.MODULE FILENAME   Write PKG.MODULE as a single-file Bash script to FILENAME
    enable                      Output bash shim to stdout
    import PKG.MODULE           Output specified module to stdout
    run FILENAME                Run FILENAME with bash shim applied automatically
EOT
}

.main() {
    if ! (($#)); then
        .help
    fi

    local cmd="$1"
    shift

    # FIXME: ambiguous behaviour when $1 is a readable file, and also a supported command
    # e.g. touch import && boa import will run the empty 'import' script and do nothing
    if [[ -r "${cmd}" ]]; then
        set -- "${cmd}" "$@"
        cmd="run"
    fi

    case "${cmd}" in
    build | enable | import | run)
        # Handle built or not:
        if type -t "boa::${cmd}" &>/dev/null; then
            "boa::${cmd}" "$@"
        else
            ".${cmd}" "$@"
        fi
        ;;
    *)
        .help
        exit 1
        ;;
    esac
}

# boa::build_module PKG.MODULE OUTPUT_FILENAME
# Approximately the same as running `boa import PKG.MODULE`, but produces
# a file for distribution.
.build_module() {
    local module="$1" output="$2"

    local path
    if ! path=$(.get_module_path "${module}"); then
        return 1
    fi

    if ! echo "" >"${output}"; then
        return 2
    fi

    .import_module "${module}" >"${output}"
}

.build() {
    local rc
    .build_module "$1" "$2"
    rc="$?"

    case "$rc" in
    0) return ;;
    1) printf "Could not find module '%s'" "$1" ;;
    2) printf "Could not write to '%s" "$2" ;;
    *) printf "Unknown error %s" "$rc" ;;
    esac

    return $rc
}

.enable() {
    # The obvious implementation for import would be as a bash function like:
    # import() {
    #    local modules="$@"
    #    source <(boa import "${modules[@]}")
    # }
    #
    # However, the bash 'source FILENAME' statement executes in the calling scope. If the imported module
    # contains any locally scoped variables, for example 'declare -r CONSTANT_NAME=value' (default scope of 'declare'
    # is local), the variables would go out of scope as soon as the import() function returned.
    #
    # Aliases do not have that problem, but do have the problem you cannot "do" anything with the arguments;
    # unlike functions the word tokens placed after the alias name are not assigned to $1 or anything.
    #
    # After a few failed attempts, I came up with the following. It utilises following behaviours:
    # 1. If a DEBUG trap exists, it is called *before* each command is executed, and receives special variable
    #    $BASH_COMMAND which contains the to-be-executed command  as a string. We use this to obtain the arguments
    #    to the 'import' alias.
    # 2. From my testing I found that  using `source` from within a DEBUG trap acts weirdly, in particular when
    #    trying to import a module that itself, contained an import.
    # 3. My key finding was that when using eval with DEBUG trap, the trap executes once on the full "eval ..." command,
    #    and then the resulting command of the eval is executed. This allows us to reference a variable in "eval"
    #    that is undefined until the DEBUG trap sees the eval about to run and stores the alias arguments.
    # 4. When the eval executes the resulting command, it thus contains the values extracted from the alias invocation.
    # 5. Final problem was that having the final part of the alias command as 'eval source <(boa import log) log'
    #    will subtly change the invocation behaviour again. The bash command is actually 'source FILENAME [args...]' and
    #    supplying args will change the values of $#, $*, "$@" within the scope of the sourced file.
    #    By adding "#" immediately after the redirected input, eval will parse the remainder of the line as a comment
    #    and 'import log' will ultimately execute as 'source <(boa import log)'
    cat <<'EOF'
shopt -s expand_aliases

alias @import='__boa_trap="$(trap -p DEBUG)" &&
    trap '\''__boa_import="${BASH_COMMAND##*-- }" &&
    if [[ -n "${__boa_trap}" ]]; then eval $__boa_trap; else trap - DEBUG; fi'\'' DEBUG &&
    eval source <(boa import "${__boa_import}") "#" -- '
EOF

    if [[ "$1" == "main" ]]; then
        cat <<'EOF'
trap 'if declare -Fp @main &>/dev/null; then @main "$@"; fi' EXIT
EOF
    fi
}

.get_function_names() {
    local path="$1"

    while read -ra decl; do
        printf "%s\n" "${decl[2]}"
    done < <(
        env -i bash <<EOT
        # shopt -s extdebug: "If the command run by the DEBUG trap returns a non-zero value, the next command is
        # skipped and not executed" . We use this feature of extdebug to skip execution of all commands in \$path
        shopt -s extdebug

        # Disable command execution while we pass contents of \$path through Bash interpreter
        trap '[[ "\${BASH_COMMAND}" == "trap :\ BOA_END_NOEXEC_TRAP DEBUG" ]]' DEBUG
        $(<"${path}")

        # Re-enable command execution. Rather than 'trap - DEBUG' we match on a specific string
        # to avoid having command execution enabled if module happens to contain 'trap - DEBUG'.
        trap :\ BOA_END_NOEXEC_TRAP DEBUG

        # Function definitions are not commands and thus not skipped by the trap, so we can now list them all:
        declare -Fp
EOT
    ) | sort
}

# boa::get_module_path PKG.MODULE
# Search BOAPATH for specified module. Module path is written to stdout.
# Returns success when module was found, otherwise false.
.get_module_path() {
    local module="$1" path

    # Determine potential file locations
    local boapaths
    IFS=: read -ra boapaths <<<"${BOAPATH}"

    local entry bash_path sh_path relative_path="${module//${BOASEP}//}"
    for entry in "${boapaths[@]}"; do
        bash_path="${entry}/${relative_path}.bash"
        sh_path="${entry}/${relative_path}.sh"

        # Prefer using .bash file, but fallback to .sh if it exists
        if [[ -r "${bash_path}" ]]; then
            path="${bash_path}"
            break
        elif [[ -r "${sh_path}" ]]; then
            path="${sh_path}"
            break
        fi
    done

    if [[ -z "${path}" ]]; then
        printf "%s\n" "$BOAPATH/${relative_path}.bash"
        return 1
    fi

    printf "%s\n" "${path}"
    return 0
}

.import_module() {
    # Argument may be of form 'import module' or 'import alias=module'
    # The former is processed like 'import module=module'
    local alias_="$1" module="$1"
    if [[ "${module}" =~ = ]]; then
        IFS='=' read -r alias_ module <<<"${module}"
    fi

    # Resolve module path
    local path
    if ! path=$(.get_module_path "${module}"); then
        # Requested module does not exist; emit script block that will report standard Bash error
        cat <<EOT
set -e
source '${path}'
EOT
        return 1
    fi

    # Rewrite function names in imported module with requested alias and separator
    local functions
    readarray -t functions < <(.get_function_names "${path}")
    sed -E "${path}" -f <(
        local func prefix
        for func in "${functions[@]}"; do
            # We treat leading punctutation in function name as a disambiguation prefix of functions and strings
            prefix=""
            if [[ "${func}" =~ ^[[:punct:]]+ ]]; then
                # period need to be escaped in regex
                prefix="${BASH_REMATCH[0]}"
                func="${func:${#prefix}}"
                # FIXME: what else needs escaping?
                prefix="${prefix//./\\.}"
            fi

            # sed does not have non-capturing groups
            # Its rather hard with regex to determine  when ".foo" is referring to our function vs embedded in
            # some unrelated piece of text. Current rules:
            # 1. function name preceded by whitespace, "$(", "<(" (command/process substitution) or start-of-line
            # 2. function name followed by "()" (as in a function definition), whitespace, or end-of-line
            printf 's/(\\s|[$<]\(|^)(%s)(%s)(\(\)|\s|$)/\\1%s\\3\\4/g\n' "${prefix}" "${func}" "${alias_}${BOASEP}"
        done
    )
}

.import() {
    for module; do
        if ! .import_module "${module}"; then
            return 1
        fi
    done

}

.run() {
    local script="$1"
    shift
    BASH_ENV=<(.enable main) bash "${script}" "$@"
}

if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    .main "$@"
fi
