#!/bin/bash
# Configure the user_ldap app against the bundled `ldap` service.
#
# Reused in two places:
#   - docker/bin/bootstrap.sh, during the install/bootstrap phase
#   - on demand against a running container:
#       docker compose exec <container> configure-ldap.sh
#
# Relies on the in-container `occ` wrapper (/usr/local/bin/occ) and the
# WEBROOT env var, both provided by the image.

# Wait for the ldap server to accept connections before configuring.
timeout 5 bash -c 'until echo > /dev/tcp/ldap/389; do sleep 0.5; done' 2>/dev/null
if [ $? -ne 0 ]; then
	echo "LDAP server (ldap:389) not available; skipping LDAP configuration"
	exit 0
fi

echo "LDAP server available"
LDAP_USER_FILTER="(|(objectclass=inetOrgPerson))"

occ app:enable user_ldap
occ ldap:create-empty-config
occ ldap:set-config s01 ldapAgentName "cn=admin,dc=planetexpress,dc=com"
occ ldap:set-config s01 ldapAgentPassword "admin"
occ ldap:set-config s01 ldapAttributesForUserSearch "sn;givenname"
occ ldap:set-config s01 ldapBase "dc=planetexpress,dc=com"
occ ldap:set-config s01 ldapEmailAttribute "mail"
occ ldap:set-config s01 ldapExpertUsernameAttr "uid"
occ ldap:set-config s01 ldapGroupDisplayName "description"
occ ldap:set-config s01 ldapGroupFilter '(|(objectclass=groupOfNames))'
occ ldap:set-config s01 ldapGroupFilterObjectclass 'groupOfNames'
occ ldap:set-config s01 ldapGroupMemberAssocAttr 'member'
occ ldap:set-config s01 ldapHost 'ldap'
occ ldap:set-config s01 ldapLoginFilter "(&$LDAP_USER_FILTER(uid=%uid))"
occ ldap:set-config s01 ldapLoginFilterMode '1'
occ ldap:set-config s01 ldapLoginFilterUsername '1'
occ ldap:set-config s01 ldapPort '389'
occ ldap:set-config s01 ldapTLS '0'
occ ldap:set-config s01 ldapUserDisplayName 'cn'
occ ldap:set-config s01 ldapUserFilter "$LDAP_USER_FILTER"
occ ldap:set-config s01 ldapUserFilterMode "1"
occ ldap:set-config s01 ldapConfigurationActive "1"
