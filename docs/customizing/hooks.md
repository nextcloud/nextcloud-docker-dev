# Setup hooks

In order to customize the behavior of the application, you can use hooks. Hooks need to be placed in the `data/shared/hooks/` directory. They will be picked up by the docker containers automatically. They can be used for automating setup specific to a developers use cases. For example, you can use them to create a user, install an app, or run a script before or after the installation of Nextcloud.

The following hooks are currently available:

- before-install.sh Runs before the installation of Nextcloud
- after-install.sh Runs after the installation of Nextcloud
- before-start.sh Runs before the start of Nextcloud webserver
- after-start.sh Runs after the start of Nextcloud webserver

## Example for after-install.sh

```bash
#!/usr/bin/env bash

echo 'Create some users'
export OC_PASS=mycustomuser
occ user:add --password-from-env mycustomuser
```

## Example for before-start.sh

```bash
#!/usr/bin/env bash

echo 'Always disable the firstrunwizard'
occ app:disable firstrunwizard
```
