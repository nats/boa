# Add the options we support
cli::add_option "quiet" "Only display warnings and errors" false
cli::add_option "verbose" "Provide detailed information on performed tasks" false

# ANSI colours used in log output
declare -A ANSI=(
    [blk]=$'\e[1;30m'
    [red]=$'\e[1;31m'
    [grn]=$'\e[1;32m'
    [yel]=$'\e[1;33m'
    [blu]=$'\e[1;34m'
    [mag]=$'\e[1;35m'
    [cyn]=$'\e[1;36m'
    [gry]=$'\e[1;37m'
    [drk]=$'\e[1;90m'
    [lre]=$'\e[1;91m'
    [lgr]=$'\e[1;92m'
    [lye]=$'\e[1;93m'
    [lbl]=$'\e[1;94m'
    [lma]=$'\e[1;95m'
    [lcy]=$'\e[1;96m'
    [wht]=$'\e[1;97m'
    [nor]=$'\e[0m'
    [bld]=$'\e[1m'
)

# If output is not a tty, do not use ANSI codes
if ! [[ -t 1 ]]; then
    for key in "${!ANSI[@]}"; do
        ANSI["${key}"]=''
    done
fi
declare -r ANSI

.pass() {
    local format="$1"; shift
    ._timestamp grn PASS "${format}" "$@" >&2
}

.fail() {
    local format="$1"; shift
    ._timestamp red FAIL "${format}" "$@" >&2
}


.crit() {
    local format="$1"; shift
    ._timestamp lre CRIT "${format}" "$@" >&2
    exit 1
}

.warn() {
    local format="$1"; shift
    ._timestamp yel WARN "${format}" "$@" >&2
}

.note() {
    cli::flag quiet && return 0
    local format="$1"; shift
    ._timestamp wht NOTE "${format}" "$@"
}

.info() {
    cli::flag quiet && return 0
    local format="$1"; shift
    ._timestamp nor INFO "${format}" "$@"
}

.debug() {
    cli::flag verbose || return 0
    local format="$1"; shift
    ._timestamp blu DEBUG "${format}" "$@"
}

# Print the command passed as parameters, and then execute it
.trace() {
    if cli::flag verbose; then
        ._timestamp cyn TRACE "%s" "$(printf "%q " "$@")"
    fi
    "$@"
}

._timestamp() {
    local col="$1"; shift
    local severity="$1"; shift
    local format="$1"; shift
    ._print "${col}" "$(printf "%(%Y-%m-%d %H:%M:%S)T") $(printf "%7s" "[${severity}]") ${format}" "$@"
}

._print() {
    local col="$1"; shift
    local format="$1"; shift
    #format="${format//%q/\'%s\'}"
    # shellcheck disable=SC2059
    printf "%s${format}%s\n" "${ANSI[${col}]}" "$@" "${ANSI[nor]}"
}

._stdin() {
    local line col="$1"
    while read -r line; do
        ._print "${col}" "%s" "${line}"
    done
}


# Run a command and conditionally display its output
.trap() {
    local cmd=("$@")
    local rc=0
    local out; out="$(mktemp)"

    # Run command and redirect stdout+stderr through a formatter (both of which write to stdout)
    # Capture the combined output (in the original order) to a temporary file
    if ! { "${cmd[@]}" 2> >(._stdin mag) > >(._stdin drk); } > "${out}"; then
        rc="${PIPESTATUS[0]}"
        .warn "${cmd[*]} rc=${rc}"
    fi

    # If command failed OR verbose is enabled, display output
    if (( rc != 0 )) || cli::flag verbose; then
        # Check file has non-zezo size to avoid printing just a blank line
        [[ -s "${out}" ]] && cat "${out}"
    fi

    # Cleanup and return result
    rm -f "${out}"
    return "${rc}"
}
