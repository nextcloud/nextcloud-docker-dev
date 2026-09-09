#!/usr/bin/env bash

function get_docker_compose_command() {
    docker-compose version >/dev/null 2>/dev/null && DCC='docker-compose'
    docker compose version >/dev/null 2>/dev/null && DCC='docker compose'
    if [ -z "$DCC" ]; then
        return
    fi
    echo "$DCC"
}

function docker_compose() {
    DCC=$(get_docker_compose_command)
    if [ -z "$DCC" ]; then
        echo "❌ Install docker-compose before running this script"
        exit 1
    fi
    $DCC "$@"
}
