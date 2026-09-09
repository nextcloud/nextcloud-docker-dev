#!/usr/bin/env bash

set -e
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=example.env
source "${SCRIPT_DIR}/../.env"
# shellcheck source=scripts/functions.sh
source "${SCRIPT_DIR}/functions.sh"

# Default container name to operate on
container=${CONTAINER:-nextcloud}
# container_set=

show_help() {
    cat << EOF
$0: Run OCC commands in containers
Usage:
    $0 [CONTAINER] [PARAMS] [--] {OCC_PARAMS}

In CONTAINER you can specify the name of the container to work on. It must be the very first parameter.

With PARAMS you can provide additional information to the script. The possible options are documented below.
The params in OCC_PARAMS are forwarded to the OCC script literally.

With double dash -- you can separate the params from the OCC params. This might be required if the names are recognized by both scripts.

Possible options for PARAMS:
  --help/-h      Print this help and exit

If the container is not given explicitly, the env variable CONTAINER will be checked. If this is not given, the default value is nextcloud.
Examples:

    $0 stable25 -- status
        Run the occ command "status" in the stable25 container
    
    $0 stable25 status
        The same as above with guessing that status is the occ command in question

    $0 app:list
        List the apps in the default container (nextcloud)
EOF
}

run_occ() {
    docker_compose exec --user www-data "$container" ./occ "$@"
    exit $?
}

is_valid_container_name() {
    if [[ ( $1 =~ ^nextcloud[2,3]?$ ) || ( $1 =~ ^stable[0-9]*$ ) ]]
    then
        # The param $1 is a valid container name
        return 0
    else
        return 1
    fi
}

# Guess if the first entry is a container name
if is_valid_container_name "$1"
then
    echo "Using $1 as the container to work on."
    container=$1
    # container_set=1
    shift
fi

while [ $# -gt 0 ]
do
    case "$1" in
        --help|-h)
            show_help
            exit
            ;;
        --)
            shift
            run_occ "$@"
            ;;
        *)
            echo "Parameter $1 is not recognized. I assume this is for occ."
            run_occ "$@"
            ;;
    esac

    # Shift to the next parameter
    # shellcheck disable=SC2317
    shift
done

run_occ
