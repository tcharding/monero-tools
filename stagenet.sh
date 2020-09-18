#!/bin/bash
#
# Create and run Monero stagenet network (nodes and wallets).
#
# Original Monero setup code copied from: https://github.com/moneroexamples/private-testnet
# Bash stdlib and coding ideas taken from the Rust project's rustup.sh (no longer exists but it was awesome).
#
# Example Usage:
#
# If this is the first time you've used `stagenet.sh` you probably want to run the following three commands
#
#    stagenet --create-wallet
#    stagenet --start-monerod
#    stagenet --open-wallet

set -u # Undefined variables are errors

main() {
    # No default action, we expect a flag.
    if [ $# -eq 0 ]; then
        echo "Monero local stagenet network setup tool."
        print_help
        exit 1
    fi

    assert_cmds
    set_globals
    assert_root_dir

    handle_command_line_args "$@"
}

set_globals() {
    # Environment sanity checks
    assert_nz "$HOME" "\$HOME is undefined"
    assert_nz "$0" "\$0 is undefined"

    # Base directory for artifacts.
    base_dir="$HOME/monero"

    # Network type i.e., mainnet, stagenet, testnet
    net="stagenet"

    # $root_dir/$net_type
    dir="$base_dir/$net"

    # Mining difficulty
    difficulty=1

    # Script verbosity level.
    flag_verbose=false

    # Monerod logging level.
    log_level=0
}

# Create artefact root directory if not found.
assert_root_dir() {
    if [ ! -d "$dir" ]; then
        say "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

handle_command_line_args() {
    local _help=false
    local _create=false
    local _start=false
    local _stop=false
    local _restart=false
    local _open=""

    local _arg
    for _arg in "$@"; do
        case "${_arg%%=*}" in
            --create-wallet )
                _create=true
                ;;

            --open-wallet )
                _open=true
                ;;

            --start )
                _start=true
                ;;

            --stop )
                _stop=true
                ;;

            --restart )
                _restart=true
                ;;

            -h | --help )
                _help=true
                ;;

            --verbose)
                # verbose is a global flag
                flag_verbose=true
                ;;

            *)
                echo "Unknown argument '$_arg', displaying usage:"
                echo ${_arg%%=*}
                _help=true
                ;;

        esac
    done

    if [ "$_help" = true ]; then
        print_help
        exit 0
    fi

    local _succeeded=true

    if [ "$_create" = true ]; then
        create_wallet
        if [ $? != 0 ]; then
            _succeeded=false
        fi
    elif [ "$_open" = true ]; then
        open_wallet
        if [ $? != 0 ]; then
            _succeeded=false
        fi
    elif [ "$_start" = true ]; then
        start
        if [ $? != 0 ]; then
            _succeeded=false
        fi
    elif [ "$_stop" = true ]; then
        stop
        if [ $? != 0 ]; then
            _succeeded=false
        fi
    elif [ "$_restart" = true ]; then
        restart
        if [ $? != 0 ]; then
            _succeeded=false
        fi
    fi

    if [ "$_succeeded" = false ]; then
        exit 1
    fi
}

# Creates a Monero wallet in artefact directory.
function create_wallet() {
    verbose_say "creating wallet, expect daemon connection errors ..."

    # 56bCoEmLPT8XS82k2ovp5EUYLzBt9pYNW2LXUFsZiv8S3Mt21FZ5qQaAroko1enzw3eGr9qC7X1D7Geoo2RrAotYPx1iovY
    echo "" | monero-wallet-cli --$net --generate-new-wallet $dir/wallet  --restore-deterministic-wallet --electrum-seed="sequence atlas unveil summon pebbles tuesday beer rudely snake rockets different fuselage woven tagged bested dented vegan hover rapid fawns obvious muppet randomly seasons randomly" --password "" --log-file $dir/wallet.log;

    if [ "$flag_verbose" = true ]; then
        say  "created wallet in $dir"
	ls $dir
    fi
}

# Open the wallet created with --create-wallet
open_wallet() {
    verbose_say "opening wallet ..."

    # address: 56bCoEmLPT8XS82k2ovp5EUYLzBt9pYNW2LXUFsZiv8S3Mt21FZ5qQaAroko1enzw3eGr9qC7X1D7Geoo2RrAotYPx1iovY
    monero-wallet-cli --$net --trusted-daemon --wallet-file $dir/wallet --password '' --log-file $dir/wallet.log
}

# Starts monerod nodes.
start() {
    verbose_say "Starting private $net monerod instances ..."

    # FIXME: Mining works, wallet has a bunch of coins in it but when connecting to node we get an error that mining never started?

    # Listens on ports 38080, 38081, 38082
    monerod --$net  --no-igd --hide-my-port --data-dir $dir/node_01 --p2p-bind-ip 127.0.0.1 --log-level $log_level --add-exclusive-node 127.0.0.1:48080  --fixed-difficulty $difficulty --detach

    monerod --$net --p2p-bind-port 48080 --rpc-bind-port 48081 --zmq-rpc-bind-port 48082 --no-igd --hide-my-port  --log-level $log_level --data-dir $dir/node_02 --p2p-bind-ip 127.0.0.1 --add-exclusive-node 127.0.0.1:38080 --fixed-difficulty $difficulty --detach


    # monerod --$net  --no-igd --hide-my-port --data-dir ~/$dir/node --p2p-bind-ip 127.0.0.1 --log-level 0  --fixed-difficulty $difficulty --detach --start-mining 56bCoEmLPT8XS82k2ovp5EUYLzBt9pYNW2LXUFsZiv8S3Mt21FZ5qQaAroko1enzw3eGr9qC7X1D7Geoo2RrAotYPx1iovY --log-file $dir/bitmonero.log
}

# Undoes start()
stop() {
    monerod --rpc-bind-port 38081 exit
    monerod --rpc-bind-port 48081 exit
}

restart() {
    stop
    start
}

print_help() {
echo '
Usage: stagenet.sh [--verbose]

Options:

     --start                    Start the monerod nodes
     --stop                     Stop the nodes
     --restart                  Start then stop the nodes
     --create-wallet            Create a wallet
     --open-wallet              Open the wallet
     --help, -h                 Display usage information
'
}

#
# Standard library for bash
#  courtesy of rustup.sh (the Rust project)
#

say() {
    echo "stagenet.sh: $1"
}

say_err() {
    say "$1" >&2
}

verbose_say() {
    if [ "$flag_verbose" = true ]; then
	say "$1"
    fi
}

err() {
    say "$1" >&2
    exit 1
}

need_cmd() {
    if ! command -v "$1" > /dev/null 2>&1
    then err "need '$1' (command not found)"
    fi
}

need_ok() {
    if [ $? != 0 ]; then err "$1"; fi
}

assert_nz() {
    if [ -z "$1" ]; then err "assert_nz $2"; fi
}

# Run a command that should never fail. If the command fails execution
# will immediately terminate with an error showing the failing
# command.
ensure() {
    "$@"
    need_ok "command failed: $*"
}

# This is just for indicating that commands' results are being
# intentionally ignored. Usually, because it's being executed
# as part of error handling.
ignore() {
    run "$@"
}

# Runs a command and prints it to stderr if it fails.
run() {
    "$@"
    local _retval=$?
    if [ $_retval != 0 ]; then
        say_err "command failed: $*"
    fi
    return $_retval
}

# Prints the absolute path of a directory to stdout
abs_path() {
    local _path="$1"
    # Unset CDPATH because it causes havok: it makes the destination unpredictable
    # and triggers 'cd' to print the path to stdout. Route `cd`'s output to /dev/null
    # for good measure.
    (unset CDPATH && cd "$_path" > /dev/null && pwd)
}

assert_cmds() {
    need_cmd mkdir
    need_cmd monero-wallet-cli
}

main "$@"
exit 0

