
# SSO/SAML/OpenID Connect

## [Keycloak](https://www.keycloak.org/)

- Keycloak is using LDAP as a user backend (make sure the LDAP container is also running)
- If you have ssl enabled please modify the example realm config accordingly in `docker/configs/keycloak/Example-realm.json`
- `occ user_oidc:provider Keycloak -c nextcloud -s 09e3c268-d8bc-42f1-b7c6-74d307ef5fde -d http://keycloak.local/auth/realms/Example/.well-known/openid-configuration`
- <http://keycloak.local/auth/realms/Example/.well-known/openid-configuration>
- nextcloud
- 09e3c268-d8bc-42f1-b7c6-74d307ef5fde

## Authentik

```
docker compose up -d proxy nextcloud authentik
```

The server will be available on [http://authentik.local](http://authentik.local). It will be automatically configured but you still need to enable the admin account [using the initial setup flow](http://authentik.local/if/flow/initial-setup/).

## SAML

```
docker compose up -d proxy nextcloud saml
```

- uid mapping: `urn:oid:0.9.2342.19200300.100.1.1`
- idp entity id: `https://sso.local/simplesaml/saml2/idp/metadata.php`
- Single Sign-On (SSO) service url: `https://sso.local/simplesaml/saml2/idp/SSOService.php`
- single log out service url: `https://sso.local/simplesaml/saml2/idp/SingleLogoutService.php`
- use certificate from `docker/configs/var-simplesamlphp/cert/example.org.crt`

  ```
  -----BEGIN CERTIFICATE-----
  MIICrDCCAhWgAwIBAgIUNtfnC2jE/rLdxHCs2th3WaYLryAwDQYJKoZIhvcNAQEL
  BQAwaDELMAkGA1UEBhMCREUxCzAJBgNVBAgMAkJZMRIwEAYDVQQHDAlXdWVyemJ1
  cmcxFDASBgNVBAoMC0V4YW1wbGUgb3JnMSIwIAYDVQQDDBlzc28ubG9jYWwuZGV2
  LmJpdGdyaWQubmV0MB4XDTE5MDcwMzE0MjkzOFoXDTI5MDcwMjE0MjkzOFowaDEL
  MAkGA1UEBhMCREUxCzAJBgNVBAgMAkJZMRIwEAYDVQQHDAlXdWVyemJ1cmcxFDAS
  BgNVBAoMC0V4YW1wbGUgb3JnMSIwIAYDVQQDDBlzc28ubG9jYWwuZGV2LmJpdGdy
  aWQubmV0MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDHPZwU+dAc76yB6bOq
  0AkP1y9g7aAi1vRtJ9GD4AEAsA3zjW1P60BYs92mvZwNWK6NxlJYw51xPak9QMk5
  qRHaTdBkmq0a2mWYqh1AZNNgCII6/VnLcbEIgyoXB0CCfY+2vaavAmFsRwOMdeR9
  HmtQQPlbTA4m5Y8jWGVs1qPtDQIDAQABo1MwUTAdBgNVHQ4EFgQUeZSoGKeN5uu5
  K+n98o3wcitFYJ0wHwYDVR0jBBgwFoAUeZSoGKeN5uu5K+n98o3wcitFYJ0wDwYD
  VR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOBgQA25X/Ke+5dw7up8gcF2BNQ
  ggBcJs+SVKBmPwRcPQ8plgX4D/K8JJNT13HNlxTGDmb9elXEkzSjdJ+6Oa8n3IMe
  vUUejXDXUBvlmmm+ImJVwwCn27cSfIYb/RoZPeKtned4SCzpbEO9H/75z3XSqAZS
  Z1tiHzYOVtEs4UNGOtz1Jg==
  -----END CERTIFICATE-----
  ```

- cn `urn:oid:2.5.4.3`
- email `urn:oid:0.9.2342.19200300.100.1.3`

## Environment-based SSO

A simple approach to test environment-based SSO with the `user_saml` app is to use Apache's basic auth with the following configuration:

```

<Location /login>
 AuthType Basic
 AuthName "SAML"
 AuthUserFile /var/www/html/.htpasswd
 Require valid-user
</Location>
<Location /index.php/login>
 AuthType Basic
 AuthName "SAML"
 AuthUserFile /var/www/html/.htpasswd
 Require valid-user
</Location>
<Location /index.php/apps/user_saml/saml/login>
 AuthType Basic
 AuthName "SAML"
 AuthUserFile /var/www/html/.htpasswd
 Require valid-user
</Location>
<Location /apps/user_saml/saml/login>
 AuthType Basic
 AuthName "SAML"
 AuthUserFile /var/www/html/.htpasswd
 Require valid-user
</Location>
```
