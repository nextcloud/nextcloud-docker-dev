# ONLYOFFICE

ONLYOFFICE is a self-hosted office suite that can be used with Nextcloud.

## Automatic setup

Make sure to clone <https://github.com/ONLYOFFICE/onlyoffice-nextcloud> into your apps directory:

```bash
cd ~/nextcloud-docker-dev/workspace/server/apps-extra
git clone https://github.com/ONLYOFFICE/onlyoffice-nextcloud onlyoffice
```

A script is available to automatically setup ONLYOFFICE for you combined with an already running Nextcloud container.

It requires to have the onlyoffice integration app cloned into your apps directory.

```bash
./scripts/enable-onlyoffice <container-name>
```

## Stable Nextcloud versions

1. Make sure to clone <https://github.com/ONLYOFFICE/onlyoffice-nextcloud> as explained above.
2. Create a `worktree` pointing to the stable version you want e.g. `stable32` to run `onlyoffice` with.
   The second parameter in the command can be a existing tag or branch from their repo e.g. `tags/v9.12.0`.

  ```bash
  cd ~/nextcloud-docker-dev/workspace/server/apps-extra/onlyoffice
  git worktree add ../../../<stablexy>/apps-extra/onlyoffice <tag | branch name>
  ```

3. Set up onlyoffice as partially explained in <https://github.com/ONLYOFFICE/onlyoffice-nextcloud?tab=readme-ov-file#installing-onlyoffice-app-for-nextcloud->
  
   3.1. Initiate the submodules:
   ```bash
   git submodule update --init --recursive
   ```
   3.2. Build webpack:
   ```bash
   npm install 
   npm run build
   ```
   3.3. Install Composer dependencies 
   ```bash
   composer install
   ```

4. After starting your stable branch container, run:
   ```bash
   ./scripts/enable-onlyoffice <container-name>
   ```
   
!!! note You can check if everything is set up correctly by accessing the settings page in your stable container at <http://stablexy.local/index.php/settings/admin/onlyoffice> or by logging into the container and running the occ command: `occ onlyoffice:documentserver --check`.

## Manual steps

- Make sure to have the ONLYOFFICE hostname setup in your `/etc/hosts` file: `127.0.0.1 onlyoffice.local`
- Start the ONLYOFFICE server in addition to your other containers `docker compose up -d onlyoffice`
- Clone <https://github.com/ONLYOFFICE/onlyoffice-nextcloud> into your apps directory
- Enable the app and configure `onlyoffice.local` in the ONLYOFFICE settings inside of Nextcloud
