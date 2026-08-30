# Aliases for simpler development under Linux

To simplify the development and managment of the containers and various scripts, it is possible to define aliases for convinience.

The aliases depend on your local development setup.
Thus, there is a script in this repo that help with creating an aliases file.
To enable the aliases file, you have to include it in your shell (see below).

If installed in your users bash, the aliases are present in every folder.
You do not have to navigate to the development folder but can directly call the aliases.

## Aliases defined in the aliases file

The following aliases are defined by default:

### nc-docker - Access the docker compose

The `nc-docker` alias allows you to quickly issue commands to the Docker daemon (from the development environment).
For example, you can do the followin to start a container:

```
nc-docker up -d nextcloud
```

In fact the interface is the same as `docker compose` (or `docker-compose`).
So, any valid docker compose command can be used here.

### nc-cd - Switch to folders of containers

With `nc-cd` you can directly switch to the development environment from any location in your machine.
Without any parameter, it brings you to the `wordspace` folder of the development environment.
You can give it a relative path (like `nextcloud/apps-extra/fancy`) to get there as well.

### nc-occ - Call OCC quickly

It is convinient to call OCC of the developemnt environment.
This can be done with `nc-occ`.
Note however, that you have to provide the name of the instance unless you want to affect the `nextcloud` container.
To select the instance, it is the first parameter to `nc-occ`.
See also the `scripts/occ.sh` script.

You can use the `--help` command line parameter for more details.

### nc-mysql - Direct access to the MariaDB server

The alias `nc-mysql` is an alias to `scripts/mysql.sh`.
It allows you interact with the DB in a live session.

For more details, see the output of `nc-mysql --help`.

## Automatic alias file generation

By default, the aliases file is located in `scripts/aliases` in this repository.
The file is not checked in or exists by default and must be created.
To simplify this, you can use the script `scripts/create-aliases.sh`.

Please note, however, that the `bootstrap.sh` script already calls the `scripts/create-aliases.sh`.
After bootstrapping (as suggested by the README) the aliases file therefore is automatically generated with the default settings.

You can simply call the script in your shell.
This will create the aliases file for in the default location.
Note, that this script will (for security reasons) not install the alias file in your system.

To use/install the file, you have to make your bash to read (_source_) the alias file.
Typically, this is done by adding a section to your `.bashrc` in the home folder of your main development user.
The `create-aliases.sh` script outputs the section that could be inserted into your `.bashrc` file.

For example, such an entry could be

```shell
# NC docker aliases
if [ -f "/home/USER/Documents/nextcloud-docker-dev/scripts/aliases" ]
then
    source "/home/USER/Documents/nextcloud-docker-dev/scripts/aliases"
fi
```

If you want to get rid of the aliases, you have to remove the entry again from the `.bashrc` file and restart the bash or terminal.

## Modifications of the aliases

By default, the implementation automatically checks if the aliases file is still up-to-date.
If there are changes to be made (as new aliases have been defined), your bash will issue a message upon starting a new shell.

In case you want to customize the aliases, this check will bail out and trigger this warning in each shell invocation.
To avoid this, you can disable the automatic update checks of the aliases file:
On creating the aliases file, you can call `create-aliases.sh --no-selftest`.
The `--no-selftest` parameter build a version of the alias file that will skip the selftest.
Note, however, that this implies that you are responsible to keep the file up-to-date.
