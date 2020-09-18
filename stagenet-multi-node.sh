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
#    stagenet --create-wallets
#    stagenet --start-nodes
#    stagenet --open-wallet=1

set -u # Undefined variables are errors


# Configuration options
root_dir="$HOME/monero"
net_type="stagenet"
difficulty=1
flag_verbose=false
log_level=0

main() {
    if [ ! -d "$root_dir" ]; then
        err "root directory $ROOT_DIR does not exist"
    fi

    assert_cmds

    if [ $# -eq 0 ]; then
        echo "Monero local stagenet network setup tool."
        print_help
        exit 1
    fi

    handle_command_line_args "$@"
}


handle_command_line_args() {
    local _help=false
    local _create=false
    local _start=false
    local _stop=false
    local _mine=false
    local _open_wallet=""

    local _arg
    for _arg in "$@"; do
        case "${_arg%%=*}" in
            --create-wallets )
                _create=true
                ;;

            --start-nodes )
                _start=true
                ;;

            --stop-nodes )
                _stop=true
                ;;

            --open-wallet )
                if is_value_arg "$_arg" "open-wallet"; then
                    _open_wallet="$(get_value_arg "$_arg")"
                fi
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
    elif [ "$_start" = true ]; then
        start_nodes
        if [ $? != 0 ]; then
            _succeeded=false
        fi
    elif [ "$_stop" = true ]; then
        stop_nodes
        if [ $? != 0 ]; then
            _succeeded=false
        fi
    elif [ -n "$_open_wallet" ]; then
        open_wallet "$_open_wallet"
        if [ $? != 0 ]; then
            _succeeded=false
        fi
    fi

    if [ "$_succeeded" = false ]; then
        exit 1
    fi
}

is_value_arg() {
    local _arg="$1"
    local _name="$2"

    echo "$_arg" | grep -q -- "--$_name="
    return $?
}

get_value_arg() {
    local _arg="$1"

    echo "$_arg" | cut -f2 -d=
}

# Creates 4 wallets.
function create_wallets() {
    local dir="$root_dir/$net_type"
    if [ ! -d "$dir" ]; then
        verbose_say "Creating directory: $dir"
        mkdir "$dir"
    fi

    verbose_say "creating wallets, expect daemon connection errors."

    # 56bCoEmLPT8XS82k2ovp5EUYLzBt9pYNW2LXUFsZiv8S3Mt21FZ5qQaAroko1enzw3eGr9qC7X1D7Geoo2RrAotYPx1iovY
    echo "" | monero-wallet-cli --$net_type --generate-new-wallet $dir/wallet_01  --restore-deterministic-wallet --electrum-seed="sequence atlas unveil summon pebbles tuesday beer rudely snake rockets different fuselage woven tagged bested dented vegan hover rapid fawns obvious muppet randomly seasons randomly" --password "" --log-file $dir/wallet_01.log;

    # 56VbjczrFCVZiLn66S3Qzv8QfmtcwkdXgM5cWGsXAPxoQeMQ79md51PLPCijvzk1iHbuHi91pws5B7iajTX9KTtJ4Z6HAo6
    echo "" | monero-wallet-cli --$net_type --generate-new-wallet $dir/wallet_02  --restore-deterministic-wallet --electrum-seed="deftly large tirade gumball android leech sidekick opened iguana voice gels focus poaching itches network espionage much jailed vaults winter oatmeal eleven science siren winter" --password "" --log-file $dir/wallet_02.log;

    # 5BXAsDboVYEQcxEUsi761WbnJWsFRCwh1PkiGtGnUUcJTGenfCr5WEtdoXezutmPiQMsaM4zJbpdH5PMjkCt7QrXAbj3Qrc
    echo "" | monero-wallet-cli --$net_type --generate-new-wallet $dir/wallet_03  --restore-deterministic-wallet --electrum-seed="upstairs arsenic adjust emulate karate efficient demonstrate weekday kangaroo yoga huts seventh goes heron sleepless fungal tweezers zigzags maps hedgehog hoax foyer jury knife karate" --password "" --log-file $dir/wallet_03.log;


    if [ "$flag_verbose" = true ]; then
        say  "created wallets in $dir"
	ls $dir
    fi
}

# Starts 3 Monero nodes.
start_nodes() {
    verbose_say "Starting 3 private $net_type nodes ..."
    local dir="$root_dir/$net_type"
    if [ ! -d "$dir" ]; then
        err "$dir does not exist, create wallets before starting private nodes"
    fi

    # FIXME: Mining works, wallet_01 has a bunch of coins in it but when connecting to node_01 we get an error that mining never started?

    # Start the first node and start mining to wallet_01
    # Listens on ports 38080, 38081, 38082
    monerod --$net_type  --no-igd --hide-my-port --data-dir ~/$dir/node_01 --p2p-bind-ip 127.0.0.1 --log-level 0 --add-exclusive-node 127.0.0.1:48080 --add-exclusive-node 127.0.0.1:58080  --fixed-difficulty $difficulty --detach --start-mining 56bCoEmLPT8XS82k2ovp5EUYLzBt9pYNW2LXUFsZiv8S3Mt21FZ5qQaAroko1enzw3eGr9qC7X1D7Geoo2RrAotYPx1iovY

    monerod --$net_type --p2p-bind-port 48080 --rpc-bind-port 48081 --zmq-rpc-bind-port 48082 --no-igd --hide-my-port  --log-level $log_level --data-dir $dir/node_02 --p2p-bind-ip 127.0.0.1 --add-exclusive-node 127.0.0.1:38080 --add-exclusive-node 127.0.0.1:58080 --fixed-difficulty $difficulty --detach

    monerod --$net_type --p2p-bind-port 58080 --rpc-bind-port 58081 --zmq-rpc-bind-port 58082 --no-igd --hide-my-port  --log-level $log_level --data-dir $dir/node_03 --p2p-bind-ip 127.0.0.1 --add-exclusive-node 127.0.0.1:38080 --add-exclusive-node 127.0.0.1:48080 --fixed-difficulty $difficulty --detach
}

# Undoes start_nodes()
stop_nodes() {
    monerod --rpc-bind-port 38081 exit
    monerod --rpc-bind-port 48081 exit
    monerod --rpc-bind-port 58081 exit
}

# Opens wallet_0X where X is in the set: [1, 3]
open_wallet() {
    local idx=$1

    local dir="$root_dir/$net_type"
    if [ ! -d "$dir" ]; then
        err "wallet directory does not exist, try --create-wallets"
    fi

    local _wallet="wallet_0$idx"

    say "opening wallet: $_wallet"

    # wallet_01: 56bCoEmLPT8XS82k2ovp5EUYLzBt9pYNW2LXUFsZiv8S3Mt21FZ5qQaAroko1enzw3eGr9qC7X1D7Geoo2RrAotYPx1iovY
    # wallet_02: 56VbjczrFCVZiLn66S3Qzv8QfmtcwkdXgM5cWGsXAPxoQeMQ79md51PLPCijvzk1iHbuHi91pws5B7iajTX9KTtJ4Z6HAo6
    # wallet_03: 5BXAsDboVYEQcxEUsi761WbnJWsFRCwh1PkiGtGnUUcJTGenfCr5WEtdoXezutmPiQMsaM4zJbpdH5PMjkCt7QrXAbj3Qrc

    # By default this connects to node_01
    monero-wallet-cli --$net_type --trusted-daemon --wallet-file $dir/$_wallet --password '' --log-file $dir/$_wallet.log
}

print_help() {
echo '
Usage: stagenet.sh [--verbose]

Options:

     --start-nodes              Start the 3 network nodes
     --stop-nodes               Stop the nodes
     --create-wallets           Create the 3 wallets
     --open-wallet=X            Open wallet X
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

