#!/bin/bash
# shellcheck disable=SC2181

# set -o xtrace

DOMAIN_SUFFIX=".$(echo "$VIRTUAL_HOST" | cut -d '.' -f2-)"
IS_STANDALONE=$([ -z "$VIRTUAL_HOST" ] && echo "true" )

indent() { sed 's/^/   /'; }

# Prepare waiting page during auto installation
cp /root/installing.html /var/www/html/installing.html

tee /etc/apache2/conf-enabled/install.conf << EOF
<Directory "/var/www/html">
AllowOverride None
RewriteEngine On
RewriteBase /
RewriteCond %{REQUEST_URI} !/installing.html$
RewriteRule .* /installing.html [L]
</Directory>
EOF

pkill -USR1 apache2

output() {
	echo "$@"
	echo "$@" >> /var/www/html/installing.html
}

fatal() {
	output "======================================================================================="
	output "$@"
	output "======================================================================================="
	exit 1
}

OCC() {
	output "occ" "$@"
	# shellcheck disable=SC2068
	sudo -E -u www-data php "$WEBROOT/occ" "$@" | indent
}

is_installed() {
	STATUS=$(OCC status)
	[[ "$STATUS" = *"installed: true"* ]] 
}

is_service_running() {
	getent hosts "$1" > /dev/null 2>&1
}

update_permission() {
	chown -R www-data:www-data "$WEBROOT"/apps-writable
	chown -R www-data:www-data "$WEBROOT"/data
	chown www-data:www-data "$WEBROOT"/config
	chown www-data:www-data "$WEBROOT"/config/config.php 2>/dev/null

	if [ -f /shared/config.php ]
	then
		ln -sf /shared/config.php "$WEBROOT"/config/user.config.php
	fi
}

configure_xdebug_mode() {
	if [ -n "$PHP_XDEBUG_MODE" ]
	then
		sed -i "s/^xdebug.mode\s*=.*/xdebug.mode = ${PHP_XDEBUG_MODE//\//_}/" /usr/local/etc/php/conf.d/xdebug.ini
		unset PHP_XDEBUG_MODE
	else
		echo "⚠ No value for PHP_XDEBUG_MODE was found. Not updating the setting."
	fi
}

wait_for_other_containers() {
	output "⌛ Waiting for other containers"
	retry_with_timeout() {
		local cmd=$1
		local timeout=$2
		local error_message=$3
		local START_TIME=$SECONDS

		while ! bash -c "$cmd"; do
			if [ "$((SECONDS - START_TIME))" -ge "$timeout" ]; then
				fatal "$error_message"
			fi
			sleep 2
		done
	}

	case "$SQL" in
		"mysql" | "mariadb-replica")
			output " - MySQL"
			retry_with_timeout "(echo > /dev/tcp/database-$SQL/3306) 2>/dev/null" 30 "⚠ Unable to connect to the MySQL server"
			sleep 2
			;;
		"pgsql")
			retry_with_timeout "(echo > /dev/tcp/database-pgsql/5432) 2>/dev/null" 30 "⚠ Unable to connect to the PostgreSQL server"
			sleep 2
			;;
		"maxscale")
			for node in database-mariadb-primary database-mariadb-replica; do
				echo " - Waiting for $node"
				retry_with_timeout "(echo > /dev/tcp/$node/3306) 2>/dev/null" 30 "⚠ Unable to reach to the $node"
				retry_with_timeout "mysql -u root -pnextcloud -h $node -e 'SELECT 1' 2>/dev/null" 30 "⚠ Unable to connect to the $node"
				echo "✅"
			done
			;;
		"oci")
			output " - Oracle"
			retry_with_timeout "(echo > /dev/tcp/database-$SQL/1521) 2>/dev/null" 30 "⚠ Unable to connect to the Oracle server"
			sleep 45
			;;
		"sqlite")
			output " - SQLite"
			;;
		*)
			fatal 'Not implemented'
			;;
	esac
	[ $? -eq 0 ] && output "✅ Database server ready"
}

configure_saml() {
	if [[ "$IS_STANDALONE" = "true" ]]; then
		return 0
	fi

	if [ "$GS_MODE" = "slave" ]; then
		return 0
	fi

	if ! is_service_running "authentik-postgresql"; then
		output "⏭ Skipping SAML configuration (authentik not running)"
		return 0
	fi

	OCC app:enable user_saml --force
	OCC config:app:set user_saml type --value 'saml'

	if [ "$GS_MODE" = "master" ]; then
		OCC saml:config:set 1 --idp-singleSignOnService.url 'http://authentik.local/application/saml/portal/sso/binding/redirect/'
		OCC saml:config:set 1 --idp-singleLogoutService.url 'http://authentik.local/if/session-end/portal/'
		OCC saml:config:set 1 --idp-entityId 'https://portal.local/index.php/apps/user_saml/saml/metadata'
	else
		OCC saml:config:set 1 --idp-singleSignOnService.url 'http://authentik.local/application/saml/nextcloud/sso/binding/redirect/'
		OCC saml:config:set 1 --idp-singleLogoutService.url 'http://authentik.local/if/session-end/nextcloud/'
		OCC saml:config:set 1 --idp-entityId 'https://nextcloud.local/index.php/apps/user_saml/saml/metadata'
	fi

	OCC saml:config:set 1 --general-uid_mapping 'http://schemas.goauthentik.io/2021/02/saml/username'
	OCC saml:config:set 1 --general-idp0_display_name 'Authentik'
	OCC saml:config:set 1 --saml-attribute-mapping-email_mapping 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'
	OCC saml:config:set 1 --saml-attribute-mapping-displayName_mapping 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'
	OCC saml:config:set 1 --saml-attribute-mapping-group_mapping 'http://schemas.xmlsoap.org/claims/Group'
	OCC saml:config:set 1 --security-nameIdEncrypted 1
	OCC saml:config:set 1 --sp-name-id-format 'urn:oasis:names:tc:SAML:1.1:nameid-format:X509SubjectName'
	OCC saml:config:set 1 --sp-x509cert "'-----BEGIN CERTIFICATE-----MIIE4TCCAsmgAwIBAgIQJqHXZY3HTR67OsquzTBqmzANBgkqhkiG9w0BAQsFADAeMRwwGgYDVQQDDBNhdXRoZW50aWsgMjAyNS4xMC4yMB4XDTI2MDMwNzEyNTcwNFoXDTM2MDMwNTEyNTcwNFowOzEPMA0GA1UEAwwGUG9ydGFsMRIwEAYDVQQKDAlhdXRoZW50aWsxFDASBgNVBAsMC1NlbGYtc2lnbmVkMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAuvRuB3P2Si4QwkiARQTxx9B8MEiI6UBjyFHQlOwfi9366mG+/MYu7OqDfmFPMYBjxjGL61DSqs0EZCZF3urg8XPrfSNBpkFQ29vGBaUqodDo6xDgCKulaEMc+ROJA2/JQ2i5/rgFEpMdr89ty5AyTucdPpKAlmg5z1aIqVx6O0CPpSjPKIXYLUZATCCD4yBGcPkwwvNEx1gL4O1zTA3oPJmYXMQGEHjxL7MCjBhKp8Kz1rjPMIMY6EU6ng4P2pI0L3gyiZSff0+xHJrT5X5Z5K20A+qsy6iUzs97fvRYWAA4LYJNcdwms7a/EPv0BBIGisC76WYIKX0WwgnYbEtkN7Xn7BfQcdMJA9z4C8VrFrQClhAFswEGHLAvCZ+tCPPbPG5Z5KAe18U5JNECv1L3xbTRO6gi1+qIbfMPQZfkotzYPaIUab42LR97MMIidVCcTeXcSXi7pWJ57qDqsy+aSGclsIM/7EyyuWyX4KSbCfB+C4WATC8nI+l2aVff3A6viJx4k2bVQ0JWdPPz2RB85zjkBNPOC2e+UtXPM1s8sJVAyRUOIvHvWGmw/cCsqdb4bV6iWT+6F+i0Hb79O5ZN+s6Kej3pYPDIAHmaGqNSLyeWERPGaQZIZTCvGgmILYEwDoiVmuEi2Ks2b9kDl/wAiMYQtjh2ZUTnaaiF/zeDjIcCAwEAATANBgkqhkiG9w0BAQsFAAOCAgEAj/vF3Q2EDKb7bOLaIINe1oqvG031UzC5vAUCIutjjQc8HdE7n5+3Jd6FAH9NALmTrvLz10n07xUaoSIoB8m9vydglnKgHMOd/Jg/4VYX+pwEqInNLUd3Ep5y57KwQ3eCg2kzeEHCiacg2DgmbpW2xyGfnJbsq1IDyyY6hyDq8yvzDmetuLd3FGpNYv0NIiMrWLcy8+h2H3HCgNs1A179VvoHV+8QW9kGbTmyf/JLx4O4APD5QUX3vEgkp2yzFWIPaUuNkcpOddB7kYFcAxA620kICDw5t7yylmBZaamAK2o8tAKAhJ/KixZfj1J2t9BK4pDrPeulOTdhDA3vuao2LXmfP4PUakV7yY1W7YVftwNasY2RXCh+RkIhEABL98VdfRyxTo5pi6KoqMOYVp5/pRNZ6H2Zmpyb8pUZcBoBHFudoZ/NN5FyuUUk1leX29Ce96YudH4K/e3X+IWiwTBKpQyguYOD4Sh21NmILFKF2w+9C4heoaFTD+CBoGAilR+4N/RPHlKf6pC5r1XteG+UWtmkHA+BZVt2eOPLlaU25MeoifoFGGm6/Rn4QAbDTYPLpFH4GXc8/S1tqrVYZeeSmfVD66Y1Ew8FB6SzX1HjruX/JewD4aCTJgYBPhS+OJ93in1XYHJd8of21GuePTBHg8fgg/p2yzUB1+STlUraqIM=-----END CERTIFICATE-----'"
	OCC saml:config:set 1 --sp-privateKey "'-----BEGIN RSA PRIVATE KEY-----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-----END RSA PRIVATE KEY-----'"
	OCC saml:config:set 1 --idp-x509cert "'-----BEGIN CERTIFICATE-----MIIE5DCCAsygAwIBAgIQQwV9AoKySzWn+vejIypIhzANBgkqhkiG9w0BAQsFADAeMRwwGgYDVQQDDBNhdXRoZW50aWsgMjAyNS4xMC4yMB4XDTI2MDMwNzEyNTcyNloXDTM2MDMwNTEyNTcyNlowPjESMBAGA1UEAwwJQXV0aGVudGlrMRIwEAYDVQQKDAlhdXRoZW50aWsxFDASBgNVBAsMC1NlbGYtc2lnbmVkMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAwIeRHlF5eL7ZX11oNhR4hfztwHKdl4G6hhyDo3cxIRN8YUVk3IXfpGzR1U7IsnqenrsNzLk//Nw15lpx4Mxr4hsyCzKksKPD5+aNy3otRQbKPOL5Fh5m9M7WxiP/uA7xkk1l5tj8ae6Lu6wnK6T4NkePSoBD3tK8NY6nOm4r04r+fWjLNc24RpX+rKZL/YPDgCYaAkooBAoXL9Dcs/RHCfPIgyeGL0YxhyZKFV+kUgQpGQYCZMdvR7waBe7rAK98y47GyQjeVIG/bRu9E/iq0rqwMAgq9rLTgUg0ZieIF1aZKeoS3bLaXvFDSzr8N2fR7ktkdsyyCqNrUg80n7cY5XKeaVefW2Qub1gj9uzuoyEU2NpzF+L9cbw0kDr5UtsCLwbdKvgQkJ9ATNWUI6EO061mRm7Ty4TyZpAY2klsvDqVbpd/OBl7LWfTaDcxaXaN0mwEv31LkPWmeecVJcqOx26NwFn1WE91cKzlv1atkuDQ8f0xX/RB2GbOSNNyRBViiw5LZUZEnTznOP+orZ8XLqQh6cUYm3KaaskjF+YRCZe0GEKgw8+Oz4Hm82gEww0y9JRguxINn3L9C1WP/X3bWbHi9kiG3Z0BUGHM5Sek2NEfR4HJ6IhQAQwzcosqpiOl4Z7dp6PWJaobjdg2gC2B1ZJXQ18pXtNrvgS88pWenDUCAwEAATANBgkqhkiG9w0BAQsFAAOCAgEAlj2kVi1yKemMsWAKDmWWPXUmKthvU4i8tortBPGKf1ndLZ1doxGhb8hUjFnaupMRG9RgQbehslLVxcIHXYGBmaiiFuAOk3HNGxBZtrCjlaSYDcuKPiM7Ey+gF6Ec5giix4vL/YFPv95gngvMxDrRsGsnyHgB/Cju5IcriJ0DfoGn/VSj+nxCdj2Ju+utyMaXEYM85I5/9c5VyB401gy7FoMkPiqA4kLsr5JhO391R+1hpjcNLbRrUnHmjLsZyGc2paGSD/Rw2dAwOjuG8BuLa+TPrj4/3Y5e2jtGNAF8bHDvLaj+sCPTjm1zmrAkI7jANQ5/hywbmpoSK8Y59OpeyoJqMwLWfLXP7xFEzG7Ovdo/EXOnypcwrPF8keitl7umwAdBkob+ki5REb02Ya7bFwtnbDcsTMfAFDnZfvScUAeBKNJ4uOlS0qQJja/2YP5+9uNuAXAv5/lEEbgMctURG7LdBH5XQNI3E/TjdJhFvV1D4exmhywbdwNBrQVaMP/FXM7cciIqFnuiRX4N+QqhH9oYpFHlGRybnsfniK20UyatEVNzx7rIB9WLKOKgT8iHTj6JnMLEPlCnQNnSmd9itmPBDJspohQGIkOzQf9at5Xeg1XEn5AjSaGQYFV+G/+gjiG4sO5/o0Nwyc8PXwF42uryX88qqDJJMokbVpVDSPY=-----END CERTIFICATE-----'"
	OCC saml:config:set 1 --security-signMetadata 1
	OCC saml:config:set 1 --security-logoutResponseSigned 1
	OCC saml:config:set 1 --security-logoutRequestSigned 1
	OCC saml:config:set 1 --security-authnRequestsSigned 1
	OCC saml:config:set 1 --security-wantAssertionsSigned 1
	OCC saml:config:set 1 --security-wantNameId 1
	OCC saml:config:set 1 --security-wantXMLValidation 1
}

configure_gs() {
	OCC config:system:set lookup_server --value=""

	if [[ "$IS_STANDALONE" = "true" ]]; then
		return 0
	fi

	get_protocol
	LOOKUP_SERVER="${PROTOCOL}://lookup${DOMAIN_SUFFIX}/index.php"
	MASTER_SERVER="${PROTOCOL}://portal${DOMAIN_SUFFIX}"

	if [ "$GS_MODE" = "master" ]
	then
	  tee /var/www/mapping.json << EOF
{
  "/^user1/i": "gs1${DOMAIN_SUFFIX}",
  "/^user2/i": "gs2${DOMAIN_SUFFIX}",
  "/^user3/i": "gs3${DOMAIN_SUFFIX}"
}
EOF

		OCC app:enable globalsiteselector --force
		OCC config:system:set lookup_server --value "$LOOKUP_SERVER"
		OCC config:system:set gs.enabled --type boolean --value true
		OCC config:system:set gss.jwt.key --value 'random-key'
		OCC config:system:set gss.mode --value 'master'
		OCC config:system:set gss.master.admin 0 --value 'admin'
		OCC config:system:set gss.master.csp-allow 0 --value "*${DOMAIN_SUFFIX}"
		OCC config:system:set 'gss.user.discovery.module' --value '\OCA\GlobalSiteSelector\UserDiscoveryModules\ManualUserMapping'
		OCC config:system:set 'gss.discovery.manual.mapping.file' --value '/var/www/mapping.json'
		OCC config:system:set 'gss.discovery.manual.mapping.regex' --type boolean --value true
		OCC config:system:set 'gss.discovery.manual.mapping.parameter' --value 'http://schemas.goauthentik.io/2021/02/saml/username'
	fi

	if [ "$GS_MODE" = "slave" ]
	then
		OCC app:enable globalsiteselector --force
		OCC app:disable user_oidc
		OCC config:system:set lookup_server --value "$LOOKUP_SERVER"
		OCC config:system:set gs.enabled --type boolean --value true
		OCC config:system:set gs.federation --value 'global'
		OCC config:system:set gss.jwt.key --value 'random-key'
		OCC config:system:set gss.mode --value 'slave'
		OCC config:system:set gss.master.url --value "$MASTER_SERVER"
	fi
}

configure_ldap() {
	if [[ "$IS_STANDALONE" = "true" ]]; then
		return 0
	fi

	timeout 5 bash -c 'until echo > /dev/tcp/ldap/389; do sleep 0.5; done' 2>/dev/null
	if [ $? -eq 0 ]; then
		output "LDAP server available"
		export LDAP_USER_FILTER="(|(objectclass=inetOrgPerson))"

		OCC app:enable user_ldap
		OCC ldap:create-empty-config
		OCC ldap:set-config s01 ldapAgentName "cn=admin,dc=planetexpress,dc=com"
		OCC ldap:set-config s01 ldapAgentPassword "admin"
		OCC ldap:set-config s01 ldapAttributesForUserSearch "sn;givenname"
		OCC ldap:set-config s01 ldapBase "dc=planetexpress,dc=com"
		OCC ldap:set-config s01 ldapEmailAttribute "mail"
		OCC ldap:set-config s01 ldapExpertUsernameAttr "uid"
		OCC ldap:set-config s01 ldapGroupDisplayName "description"
		OCC ldap:set-config s01 ldapGroupFilter '(|(objectclass=groupOfNames))'
		OCC ldap:set-config s01 ldapGroupFilterObjectclass 'groupOfNames'
		OCC ldap:set-config s01 ldapGroupMemberAssocAttr 'member'
		OCC ldap:set-config s01 ldapHost 'ldap'
		OCC ldap:set-config s01 ldapLoginFilter "(&$LDAP_USER_FILTER(uid=%uid))"
		OCC ldap:set-config s01 ldapLoginFilterMode '1'
		OCC ldap:set-config s01 ldapLoginFilterUsername '1'
		OCC ldap:set-config s01 ldapPort '389'
		OCC ldap:set-config s01 ldapTLS '0'
		OCC ldap:set-config s01 ldapUserDisplayName 'cn'
		OCC ldap:set-config s01 ldapUserFilter "$LDAP_USER_FILTER"
		OCC ldap:set-config s01 ldapUserFilterMode "1"
		OCC ldap:set-config s01 ldapConfigurationActive "1"
	fi
}

configure_oidc() {
	if [[ "$IS_STANDALONE" = "true" ]]; then
		return 0
	fi
	OCC app:enable user_oidc
	get_protocol
	OCC user_oidc:provider Keycloak -c nextcloud -s 09e3c268-d8bc-42f1-b7c6-74d307ef5fde -d "$PROTOCOL://keycloak${DOMAIN_SUFFIX}/realms/Example/.well-known/openid-configuration"
}

PROTOCOL="${PROTOCOL:-http}"
get_protocol() {
	if [[ "$IS_STANDALONE" = "true" ]]; then
		PROTOCOL=http
		return 0
	fi
}

configure_ssl_proxy() {
	if [[ "$IS_STANDALONE" = "true" ]]; then
		return 0
	fi

	get_protocol
	if [[ "$PROTOCOL" == "https" ]]; then
		echo "🔑 SSL proxy available, configuring overwrite.cli.url accordingly"
		OCC config:system:set overwrite.cli.url --value "https://$VIRTUAL_HOST" &
	else
		echo "🗝 No SSL proxy, configuring overwrite.cli.url accordingly"
		OCC config:system:set overwrite.cli.url --value "http://$VIRTUAL_HOST" &
	fi
	update-ca-certificates
}


configure_add_user() {
	export OC_PASS=$1
	OCC user:add --password-from-env "$1"
}

configure_users() {
  # on globalscale, we create no one
	if [ "$GS_MODE" = "master" ] || [ "$GS_MODE" = "slave" ]
	then
	  return 0
	fi

 	configure_add_user user1 &
 	configure_add_user user2 &
 	configure_add_user user3 &
 	configure_add_user user4 &
 	configure_add_user user5 &
 	configure_add_user user6 &
 	configure_add_user jane &
 	configure_add_user john &
 	configure_add_user alice &
 	configure_add_user bob &
}


install() {
	if [ -n "$VIRTUAL_HOST" ]; then
		DBNAME=$(echo "$VIRTUAL_HOST" | cut -d '.' -f1)
	else
		DBNAME="nextcloud"
	fi
	SQLHOST="database-$SQL"
	echo "database name will be $DBNAME"

	USER="admin"
	PASSWORD="admin"

	run_hook_before_install

	output "🔧 Starting auto installation"
	if [ "$SQL" = "oci" ]; then
		OCC maintenance:install --admin-user=$USER --admin-pass=$PASSWORD --database="$SQL" --database-name=FREE --database-host="$SQLHOST" --database-port=1521 --database-user=system --database-pass=oracle
	elif [ "$SQL" = "pgsql" ]; then
		OCC maintenance:install --admin-user=$USER --admin-pass=$PASSWORD --database="$SQL" --database-name="$DBNAME" --database-host="$SQLHOST" --database-user=postgres --database-pass=postgres
	elif [ "$SQL" = "mysql" ]; then
		OCC maintenance:install --admin-user=$USER --admin-pass=$PASSWORD --database="$SQL" --database-name="$DBNAME" --database-host="$SQLHOST" --database-user=root --database-pass=nextcloud
	elif [ "$SQL" = "mariadb-replica" ]; then
		OCC maintenance:install --admin-user=$USER --admin-pass=$PASSWORD --database="mysql" --database-name="$DBNAME" --database-host="database-mariadb-primary" --database-user=root --database-pass=nextcloud
	elif [ "$SQL" = "maxscale" ]; then
		sleep 10
		# FIXME only works for main container as maxscale does not pass root along
		OCC maintenance:install --admin-user=$USER --admin-pass=$PASSWORD --database="mysql" --database-name="$DBNAME" --database-host="database-mariadb-primary" --database-user=nextcloud --database-pass=nextcloud
		OCC config:system:set dbhost --value="database-maxscale"
		OCC config:system:set dbuser --value="nextcloud"
	else
		OCC maintenance:install --admin-user=$USER --admin-pass=$PASSWORD --database="$SQL"
	fi;

	if is_installed
	then
		output "🔧 Server installed"
	else
		output "Last nextcloud.log entry:"
		output "$(tail -n 1 "$WEBROOT"/data/nextcloud.log | jq)"
		fatal "🚨 Server installation failed."
	fi

	output "🔧 Provisioning apps"
	OCC app:disable password_policy

	for app in $NEXTCLOUD_AUTOINSTALL_APPS; do
		APP_ENABLED=$(OCC app:enable "$app")
		output "$APP_ENABLED"
		WAIT_TIME=0
		until [[ $WAIT_TIME -eq ${NEXTCLOUD_AUTOINSTALL_APPS_WAIT_TIME:-0} ]] || [[ $APP_ENABLED =~ ${app}.*enabled$ ]]
		do
			# if app is not installed pause for 1 seconds and enable again
			output "🔄 retrying"
			sleep 1
			APP_ENABLED=$(OCC app:enable "$app")
			output "$APP_ENABLED"
			((WAIT_TIME++))
		done
	done
	configure_gs
	configure_ldap
	configure_oidc
	configure_saml

	output "🔧 Finetuning the configuration"
	if [ "$WITH_REDIS" != "NO" ]; then
		cp /root/redis.config.php "$WEBROOT"/config/
	else
		cp /root/apcu.config.php "$WEBROOT"/config/
	fi

	# Setup domains
	# localhost is at index 0 due to the installation
	INTERNAL_IP_ADDRESS=$(ip a show type veth | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
	NEXTCLOUD_TRUSTED_DOMAINS="${NEXTCLOUD_TRUSTED_DOMAINS:-nextcloud} ${VIRTUAL_HOST} ${INTERNAL_IP_ADDRESS} localhost"
	if [ -n "${NEXTCLOUD_TRUSTED_DOMAINS+x}" ]; then
		echo "🔧 setting trusted domains…"
		NC_TRUSTED_DOMAIN_IDX=1
		for DOMAIN in $NEXTCLOUD_TRUSTED_DOMAINS ; do
			DOMAIN=$(echo "$DOMAIN" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
			OCC config:system:set trusted_domains $NC_TRUSTED_DOMAIN_IDX --value="$DOMAIN"
			NC_TRUSTED_DOMAIN_IDX=$((NC_TRUSTED_DOMAIN_IDX + 1))
		done
	fi

	TRUSTED_PROXY=$(ip a show type veth | awk '/scope global/ {print $2}')
	OCC config:system:set trusted_proxies 0 --value="$TRUSTED_PROXY"

	configure_ssl_proxy

	output "🔧 Preparing cron job"

	OCC dav:sync-system-addressbook

	# Setup initial configuration
	OCC background:cron

	# Trigger initial cron run
	sudo -E -u www-data php cron.php &

	# run custom shell script from nc root
	# [ -e /var/www/html/nc-dev-autosetup.sh ] && bash /var/www/html/nc-dev-autosetup.sh

	output "🔧 Setting up users and LDAP in the background"
	OCC user:setting admin settings email admin@example.net &
	INSTANCENAME=$(echo "$VIRTUAL_HOST" | cut -d '.' -f1)
	configure_add_user "${INSTANCENAME:-nextcloud}" &
	configure_users
	run_hook_after_install

	output "🚀 Finished setup using $SQL database…"
}

run_hook_before_install() {
	[ -e /shared/hooks/before-install.sh ] && bash /shared/hooks/before-install.sh
}

run_hook_after_install() {
	[ -e /shared/hooks/after-install.sh ] && bash /shared/hooks/after-install.sh
}

run_hook_before_start() {
	[ -e /shared/hooks/before-start.sh ] && bash /shared/hooks/before-start.sh
}

run_hook_after_start() {
	[ -e /shared/hooks/after-start.sh ] && bash /shared/hooks/after-start.sh
}

add_hosts() {
	echo "Add the host IP as host.docker.internal to /etc/hosts ..."
	ip -4 route list match 0/0 | awk '{print $3 "   host.docker.internal"}' >> /etc/hosts
}

setup() {
	update_permission
	configure_xdebug_mode

	if is_installed || [[ ! -f $WEBROOT/config/config.php ]]
	then
		output "🚀 Nextcloud already installed ... skipping setup"

		# configuration that should be applied on each start
		configure_ssl_proxy
	else
		# We copy the default config to the container
		cp /root/default.config.php "$WEBROOT"/config/config.php
		chown -R www-data:www-data "$WEBROOT"/config/config.php

		mkdir -p "$WEBROOT/apps-extra"
		mkdir -p "$WEBROOT/apps-shared"

		update_permission

		if [ "$NEXTCLOUD_AUTOINSTALL" != "NO" ]
		then
			add_hosts
			install
		else
			touch "${WEBROOT}/config/CAN_INSTALL"
		fi
	fi
}
check_source() {
	FILE=/var/www/html/status.php
	if [ -f "$FILE" ]; then
		output "Server source is mounted, continuing"
	else
		# Only autoinstall when not running in docker compose
		if [ -n "$VIRTUAL_HOST" ] && [ ! -f "$WEBROOT"/version.php ]
		then
			output "======================================================================================="
			output " 🚨 Could not find a valid Nextcloud source in $WEBROOT                                "
			output " Double check your REPO_PATH_SERVER and STABLE_ROOT_PATH environment variables in .env "
			output "======================================================================================="

			exit 1
		fi

		output "Server source is not present, fetching ${SERVER_BRANCH:-master}"
		git clone --depth 1 --branch "${SERVER_BRANCH:-master}" https://github.com/nextcloud/server.git /tmp/server
		(cd /tmp/server && git submodule update --init)
		output "Cloning additional apps"
		git clone --depth 1 --branch "${SERVER_BRANCH:-master}" https://github.com/nextcloud/viewer.git /tmp/server/apps/viewer

		# shallow clone of submodules https://stackoverflow.com/questions/2144406/how-to-make-shallow-git-submodules
		git config -f .gitmodules submodule.3rdparty.shallow true
		(cd /tmp/server && git submodule update --init)
		rsync -a --chmod=755 --chown=www-data:www-data /tmp/server/ /var/www/html
		chown www-data: /var/www/html
		chown www-data: /var/www/html/.htaccess
	fi
	output "Nextcloud server source is ready"
}

(
	check_source
	wait_for_other_containers
	setup
	run_hook_before_start
	rm /etc/apache2/conf-enabled/install.conf
	rm -f /var/www/html/installing.html
	pkill -USR1 apache2
	run_hook_after_start
) &

touch /var/log/cron/nextcloud.log "$WEBROOT"/data/nextcloud.log /var/log/xdebug.log
chown www-data /var/log/xdebug.log

echo "📰 Watching log file"
tail --follow "$WEBROOT"/data/nextcloud.log /var/log/cron/nextcloud.log /var/log/xdebug.log &

echo "⌚ Starting cron"
/usr/sbin/cron -f &
echo "🚀 Starting apache"
exec "$@"
