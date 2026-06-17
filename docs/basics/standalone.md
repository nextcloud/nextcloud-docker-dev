# Standalone containers

There is a standalone version of the Nextcloud containers available that can be used to run Nextcloud without the other services. This is useful if you are just wanting to get started with app development against a specific server version, or to just have a quick way to develop, test or debug.

These containers support automatic fetching of the server source code and use SQLite as the database. The server source code is fetched from the official Nextcloud server repository and the version can be specified using the `NEXTCLOUD_VERSION` environment variable. The default version is `master`.

Running the containers does not need this repository to be cloned.

Example for running a Nextcloud server from the master branch of server:

```bash
docker run --rm -p 8080:80 ghcr.io/nextcloud/nextcloud-dev-php80:latest
```

For app development you can mount your app directly into the container:

```bash
docker run --rm -p 8080:80 \
    -v ~/path/to/appid:/var/www/html/apps-extra/appid \
    ghcr.io/nextcloud/nextcloud-dev-php81:latest
```

The `SERVER_BRANCH` environment variable can be used to run different versions of Nextcloud by specifying either a server branch or git tag.

```bash
docker run --rm -p 8080:80 -e SERVER_BRANCH=v32.0.1 ghcr.io/nextcloud/nextcloud-dev-php81:latest
```

You can also mount your local server source code into the container to run a local version of Nextcloud:

```bash
docker run --rm -p 8080:80 -e SERVER_BRANCH=v32.0.1 -v /tmp/server:/var/www/html ghcr.io/nextcloud/nextcloud-dev-php81:latest
```
