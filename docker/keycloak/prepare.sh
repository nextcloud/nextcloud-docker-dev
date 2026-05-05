#!/usr/bin/env bash

KEYCLOAK_REALM_CONFIG="/opt/keycloak/data/import/Example-realm.json"
PROTOCOL="${PROTOCOL:-http}"
NEXTCLOUD_URL=${PROTOCOL}://${NEXTCLOUD_URL:-nextcloud}${DOMAIN_SUFFIX}
KEYCLOAK_URL=${PROTOCOL}://${KEYCLOAK_URL:-keycloak}${DOMAIN_SUFFIX}

if [ -f "$KEYCLOAK_REALM_CONFIG" ]; then
    echo "Preparing Keycloak realm configuration..."

    echo "Using NEXTCLOUD_URL: ${NEXTCLOUD_URL}"
    echo "Using KEYCLOAK_URL: ${KEYCLOAK_URL}"

    # Replace placeholder with actual NEXTCLOUD_URL
    sed -i.bak "s|http://nextcloud\\.local|${NEXTCLOUD_URL//./\\.}|g" "$KEYCLOAK_REALM_CONFIG"
    sed -i.bak "s|http://keycloak\\.local|${KEYCLOAK_URL//./\\.}|g" "$KEYCLOAK_REALM_CONFIG"
    rm -f "${KEYCLOAK_REALM_CONFIG}.bak"

    cat "$KEYCLOAK_REALM_CONFIG"

    echo "Realm configuration prepared."
else
    echo "Realm configuration file not found: $KEYCLOAK_REALM_CONFIG"
fi

exec /opt/keycloak/bin/kc.sh "$@"