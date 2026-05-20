# Stable Nextcloud versions

As described in the [overview](overview.md) there are multiple Nextcloud containers available. The main `nextcloud` container is targeting the main workspace directly (usually for running the master/main branch of Nextcloud server and apps) of the latest development version. In addition, there are stable containers for running the stable major version branches in parallel.

## Prepare your git checkouts for running a stable version

In order to run a stable version you need to have the corresponding git checkouts available. Using [git worktree](https://blog.juliushaertl.de/index.php/2018/01/24/how-to-checkout-multiple-git-branches-at-the-same-time/) makes it easy to have different branches checked out in parallel in separate directories and is the recommended way to work with stable branches in parallel.

Assuming you have already cloned the repository into `~/nextcloud-docker-dev/workspace/server` you can run the following commands to create a new worktree for the stable28 branch:

```bash
cd ~/nextcloud-docker-dev/workspace/server
# make sure the stable version is fetched
git fetch origin stable28:stable28
# create a new worktree for the stable28 branch
git worktree add ../stable28 stable28
cd ~/nextcloud-docker-dev/workspace/stable28
# make sure submodules are installed in the stable server root directory
git submodule update --init
```

### Add worktree for additional apps

This will be required for every app that you need on the stable branches, so run this for viewer but also for any other app you need.

```bash
cd ~/nextcloud-docker-dev/workspace/server/apps/viewer
git worktree add ../../../stable28/apps/viewer stable28
```

## Start the stable28 container

```bash
docker compose up -d stable28
```
You can now access the stable Nextcloud instance at [http://stable28.local](http://stable28.local).

## Apps without stable branches

Some apps do not have stable branches or cover multiple Nextcloud version. 
You can clone the apps you need in the stable versions to the path set in `ADDITIONAL_APPS_PATH`.
By default, this path set to `./data/apps-extra` and then mounted to `/var/www/html/apps-shared` in `docker-compose.yml`:

```
'${ADDITIONAL_APPS_PATH:-./data/apps-extra}:/var/www/html/apps-shared'
```

You can change the default value in the `.env` file:

```
ADDITIONAL_APPS_PATH=/path-to-your-app/
```

#### 🤓 How to check if the ADDITIONAL_APPS_PATH mounting worked as expected
1. Check if your app is listed at [http://stable28.local/index.php/settings/apps/disabled](http://stable28.local/index.php/settings/apps/disabled)
2. Alternatively, login into the container created from the image `nextcloud-dev-php<PHP version>` and run `occ app:list`:
```bash
  docker exec -it <container name or ID> /bin/bash
  occ app:list
```
Your app should be listed under the `Disabled` list.

- https://docs.docker.com/engine/reference/commandline/container_exec/
- https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/occ_command.html#apps-commands-label


