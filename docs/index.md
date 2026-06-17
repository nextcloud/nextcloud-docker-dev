This documentation covers a Nextcloud development environment using docker compose providing a large variety of services for Nextcloud server and app development and testing.

⚠ **DO NOT USE THIS IN PRODUCTION** 

Various settings in this setup are considered insecure and default passwords and secrets are used all over the place

- ☁ Nextcloud containers for running multiple versions
- 🐘 Multiple PHP versions
- 🔒 Nginx proxy with optional SSL termination
- 🛢️ MySQL/PostgreSQL/MariaDB/SQLite/MaxScale, Redis cache
- 💾 Local or S3 primary storage
- 👥 LDAP with example user data, Keycloak
- ✉ Mailhog for testing mail sending
- 🚀 Blackfire, Xdebug for profiling and debugging
- 📄 Lots of integrating service containers: Collabora Online, Onlyoffice, Elasticsearch, ...

Follow the [getting started guide](https://nextcloud.github.io/nextcloud-docker-dev/basics/getting-started/) or the [Nextcloud developer tutorial](https://nextcloud.com/developer/) to get started.