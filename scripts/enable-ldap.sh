#!/usr/bin/env bash

set -e
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=example.env
source "${SCRIPT_DIR}/../.env"
# shellcheck source=scripts/functions.sh
source "${SCRIPT_DIR}/functions.sh"

if [ -z "$1" ]
  then
    echo "Usage $0 CONTAINER"
	exit 1
fi

CONTAINER=$1

echo "Configuring LDAP on $CONTAINER"
docker_compose up -d ldap ldapadmin
docker_compose exec "$CONTAINER" configure-ldap.sh
