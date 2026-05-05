#!/usr/bin/env bash

set -e
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=example.env
source "${SCRIPT_DIR}/../.env"
# shellcheck source=scripts/functions.sh
source "${SCRIPT_DIR}/functions.sh"

# Default container name to operate on
instance=${INSTANCE:-nextcloud}

show_help() {
    cat << EOF
$0: Run commands in the database backend directly.
Usage:
    $0 [PARAMS] -- {MySQL Params}

The PARAMS are interpreted by the wrapper script while the MySQL Params are forwarded literally to the database client.
To separate the two lists, the double dash can be used.

The following parameters are recognized by the wrapper:
  --instance/-i INST     Use the database for the container INST. (Default: nextcloud)
  --help/-h              Show this help and exit.
EOF
}

run_mysql() {
    docker_compose exec database-mysql mysql -u nextcloud -pnextcloud "$instance" "$@"
    exit $?
}

while [ $# -gt 0 ]
do
    case "$1" in
        --instance|-i)
            instance="$2"
            # Additional shift
            shift
            ;;
        --help|-h)
            show_help
            exit
            ;;
        --)
            shift
            run_mysql "$@"
            ;;
        *)
            echo "Parameter $1 is not recognized. I assume this is for the mysql client."
            run_mysql "$@"
            ;;
    esac

    # Shift to the next parameter
    shift
done

# No parameters were given.
run_mysql
