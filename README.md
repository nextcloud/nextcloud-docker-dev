# Nextcloud development environment on Docker Compose

[Documentation](https://nextcloud.github.io/nextcloud-docker-dev/) | [Nextcloud Developer Portal](https://nextcloud.com/developer/)

Nextcloud's development environment using Docker Compose providing a large variety of services for Nextcloud server and app development and testing.

⚠ **DO NOT USE THIS IN PRODUCTION** Various settings in this setup are considered insecure and default passwords and secrets are used all over the place

- ☁ Nextcloud containers for running multiple versions
- 🐘 Multiple PHP versions
- 🔒 Nginx proxy with optional SSL termination
- 🛢️ MySQL/PostgreSQL/MariaDB/SQLite/MaxScale, Redis cache
- 💾 Local or S3 primary storage
- 👥 LDAP with example user data, Keycloak
- ✉ Mailhog for testing mail sending
- 🚀 Blackfire, Xdebug for profiling and debugging
- 📄 Lots of integrating service containers: Collabora Online, Onlyoffice, Elasticsearch, ...

## Tutorial

You can find a step-by-step tutorial on how to use this setup in the [Nextcloud Developer Portal](https://nextcloud.com/developer/). It will guide you through the setup and show you how to use it for app development: https://cloud.nextcloud.com/s/iyNGp8ryWxc7Efa?path=%2F1%20Setting%20up%20a%20development%20environment

In detail explanation of the setup and its features and configuration options can be found in the [nextcloud-docker-dev documentation](https://nextcloud.github.io/nextcloud-docker-dev/).

## Quickstart

### Persistent development setup

> [!TIP]
> This is the recommended way to run the setup for development. You will have a local clone of all required source code.

To start the setup run the following commands to clone the repository and bootstrap the setup. This will prepare your setup and clone the Nextcloud server repository and required apps into the `workspace` folder.
```bash
git clone https://github.com/nextcloud/nextcloud-docker-dev
cd nextcloud-docker-dev
./bootstrap.sh
```

Depending on your docker version you will need to use `docker-compose` instead of `docker compose` in the following commands.

This may take some time depending on your internet connection speed.

Once done you can start the Nextcloud container using:
```bash
docker compose up nextcloud
```

You can also start it in the background using `docker compose up -d nextcloud`.

You can then access your Nextcloud instance at [http://nextcloud.local](http://nextcloud.local). The default username is `admin` and the password is `admin`. [Other users can be found in the documentation](https://nextcloud.github.io/nextcloud-docker-dev/basics/overview/#default-users).

> [!WARN]
> Note that for performance reasons the server repository might have been cloned with `--depth=1` by default. To get the full history it is highly recommended to run:
>
> ```bash
> cd workspace/server
> git fetch --unshallow
> git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
> git fetch origin
> ```


### Standalone containers

> [!TIP]
> This is a very simple way but doesn't cover all features. If you are looking for a fully featured setup you may skip to the next section

There is a standalone version of the Nextcloud containers available that can be used to run Nextcloud without the other services. This is useful if you are just wanting to get started with app development against a specific server version, or to just have a quick way to develop, test or debug.

These containers support automatic fetching of the server source code and use SQLite as the database. The server source code is fetched from the official Nextcloud server repository and the version can be specified using the `NEXTCLOUD_VERSION` environment variable. The default version is `master`.

Running the containers does not need this repository to be cloned.

Example for running a Nextcloud server from the master branch of server:

```bash
docker run --rm -p 8080:80 ghcr.io/nextcloud/nextcloud-dev-php81:latest
```

For app development you can mount your app directly into the container:

```bash
docker run --rm -p 8080:80 -v ~/path/to/appid:/var/www/html/apps-extra/appid ghcr.io/nextcloud/nextcloud-dev-php81:latest
```

The `SERVER_BRANCH` environment variable can be used to run different versions of Nextcloud by specifying either a server branch or git tag.

```bash
docker run --rm -p 8080:80 -e SERVER_BRANCH=v24.0.1 ghcr.io/nextcloud/nextcloud-dev-php81:latest
```

You can also mount your local server source code into the container to run a local version of Nextcloud:

```bash
docker run --rm -p 8080:80 -e SERVER_BRANCH=v24.0.1 -v /tmp/server:/var/www/html ghcr.io/nextcloud/nextcloud-dev-php81:latest
```
## More features

You can find documentation for more advanced features in [nextcloud-docker-dev documentation](https://nextcloud.github.io/nextcloud-docker-dev/) for example:

- Running stable Nextcloud versions in parallel
- Using different database backends
- Using HTTPS
