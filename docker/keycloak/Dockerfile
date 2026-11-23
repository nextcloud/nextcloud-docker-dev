FROM quay.io/keycloak/keycloak:26.6

RUN mkdir -p /opt/keycloak/data/import

ADD keycloak/Example-realm.json /opt/keycloak/data/import/Example-realm.json

ADD keycloak/prepare.sh /opt/keycloak/bin/custom-kc.sh

ENTRYPOINT ["/opt/keycloak/bin/custom-kc.sh"]