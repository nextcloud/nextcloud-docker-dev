#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

APPS_TO_INSTALL=(viewer recommendations files_pdfviewer profiler hmr_enabler circles globalsiteselector)
NEXTCLOUD_AUTOINSTALL_APPS=(viewer profiler hmr_enabler)
SERVER_CLONE=squashed
APPS_CLONE_FILTER=

print_help() {
	cat << EOF
  bootstrap.sh [--full-clone|--clone-no-blobs] [--clone-all-apps-filtered] [--] APPS

This command will initialize the debug environment for app developers.

The following options can be provided:

  --full-clone      Clone the server repository with the complete history included
  --clone-no-blobs  Clone the server repository with the history but omitting the
                    file contents. A network connection might be required if checking
                    out commits is done.
                    --full-clone and --clone-no-blobs is mutually exclusive.
  --clone-all-apps-filtered
                    Do not only reduce the history of the server repository but also
                    the cloned apps.

  APPS              The apps to add to the development setup on top of the default apps

The default apps to be installed: ${APPS_TO_INSTALL[@]}
EOF
}

while [ $# -gt 0 ]
do
	case "$1" in
		--full-clone)
			SERVER_CLONE=full
			;;
		--clone-no-blobs)
			SERVER_CLONE=filter-blobs
			;;
		--clone-all-apps-filtered)
			APPS_CLONE_FILTER=y
			;;
		--help|-h)
			print_help
			exit 0
			;;
		--)
			shift
			break
			;;
		*)
			APPS_TO_INSTALL+=("$1")
			NEXTCLOUD_AUTOINSTALL_APPS+=("$1")
			;;
	esac
	shift
done

# You can specify additional apps to install on the command line.
APPS_TO_INSTALL+=( "$@" )
NEXTCLOUD_AUTOINSTALL_APPS+=( "$@" )

# Already executed
if [ -f ".env" ]; then
	echo "⏩ .env file found, so assuming you already ran this script."
	echo " Validating the setup"
	# shellcheck disable=SC1091
	source .env

	set +o errexit
	echo "Server master repository path: ${REPO_PATH_SERVER}"
	REPO_VERSION=$(grep "OC_VersionString" "${REPO_PATH_SERVER}/version.php" | cut -d "'" -f 2)
	if [ -d "$REPO_PATH_SERVER" ] && [ -n "$REPO_VERSION" ]; then
		echo "✅ $REPO_VERSION"
	elif [ -z "$REPO_VERSION" ]; then
		echo "❌ Repository version.php cannot be detected"
	else
		echo "❌ Repository path does not exist"
	fi

	for i in stable29 stable30 stable31 stable32 stable33
	do
		echo "Stable $i repository path: ${STABLE_ROOT_PATH}/${i}"
		STABLE_VERSION=$(grep "OC_VersionString" "${STABLE_ROOT_PATH}/${i}/version.php" | cut -d "'" -f 2)
		if [ -d "${STABLE_ROOT_PATH}/${i}" ] && [ -n "$STABLE_VERSION" ]; then
			echo "✅ $STABLE_VERSION"
		elif [ -z "$REPO_VERSION" ]; then
			echo "❌ $i version.php cannot be detected"
		else
			echo "❌ $i repository path does not exist"
		fi
	done

	exit 0
fi

case $SERVER_CLONE in
	squashed)
		CLONE_PARAMS=(--depth 1)
		;;
	filter-blobs)
		CLONE_PARAMS=(--filter blob:none)
		;;
	full)
		CLONE_PARAMS=()
		;;
	*)
		echo "Unknown cloning parameter $SERVER_CLONE was found. Please report this."
		exit 1
esac

if [ -n "$APPS_CLONE_FILTER" ]
then
	APPS_CLONE_PARAMS=("${CLONE_PARAMS[@]}")
else
	APPS_CLONE_PARAMS=()
fi

indent() {
	sed 's/^/    /'
}

indent_cli() {
	if [[ "$OSTYPE" == "darwin"* ]]; then
		sed -l 's/^/   > /'
	else
		sed -u 's/^/   > /'
	fi
}

function install_server() {
	if [ -d workspace/server/.git ]; then
		echo "🆗 Server is already installed." | indent
		return
	fi
	mkdir -p workspace/
	(
		(
			echo "🌏 Fetching server (this might take a while to finish)" &&
				git clone ${CLONE_PARAMS[@]+"${CLONE_PARAMS[@]}"} https://github.com/nextcloud/server.git workspace/server --progress 2>&1 &&
				cd workspace/server && git submodule update --init --progress 2>&1
		) || echo "❌ Failed to clone Nextcloud server code"
	) | indent
}

function install_app() {
	TARGET=workspace/server/apps-extra/"$1"
	if [ -d "$TARGET"/.git ]; then
		echo "🆗 App $1 is already installed." | indent
		return
	fi
	(
		echo "🌏 Fetching $1"
		(git clone ${APPS_CLONE_PARAMS[@]+"${APPS_CLONE_PARAMS[@]}"} https://github.com/nextcloud/"$1".git "$TARGET" 2>&1 | indent_cli &&
			echo "✅ $1 installed") ||
			echo "❌ Failed to install $1"
	) | indent
}

function is_installed() {
	(
		if [ -x "$(command -v "$1")" ]; then
			echo "✅ $1 is properly installed"
		else
			echo "❌ Install $1 before running this script"
			exit 1
		fi
	) | indent
}

echo
echo "⏩ Performing system checks"

is_installed docker
is_installed git

DCC=
docker-compose version >/dev/null 2>/dev/null && DCC='docker-compose'
docker compose version >/dev/null 2>/dev/null && DCC='docker compose'

if [ -z "$DCC" ]; then
	echo "❌ Install docker-compose before running this script"
	exit 1
fi

(
	(docker ps 2>&1 >/dev/null && echo "✅ Docker is properly executable") ||
		(echo "❌ Cannot run docker ps, you might need to check that your user is able to use docker properly" && exit 1)
) | indent


echo
echo
echo "⏩ Setup your environment in an .env file"
if [ ! -f ".env" ]; then
cat <<EOT >.env
COMPOSE_PROJECT_NAME=master
PROTOCOL=http
DOMAIN_SUFFIX=.local
REPO_PATH_SERVER="$PWD/workspace/server"
STABLE_ROOT_PATH="$PWD/workspace"
NEXTCLOUD_AUTOINSTALL_APPS="${NEXTCLOUD_AUTOINSTALL_APPS[@]}"
DOCKER_SUBNET=192.168.21.0/24
PORTBASE=821
PHP_XDEBUG_MODE=develop
# SQL variant to use, possible values: sqlite, mysql, pgsql
SQL=mysql
PRIMARY=local
# other values: "database-pgsql"
EOT
fi

./scripts/update-hosts

if [[ $(uname -m) == 'arm64' ]]; then
	echo "Setting custom containers for arm platform"

	echo "CONTAINER_ONLYOFFICE=onlyoffice/documentserver:latest-arm64" >> .env
	echo "CONTAINER_KEYCLOAK=mihaibob/keycloak:15.0.1" >> .env
fi

echo
echo "⏩ Setting up folder structure and fetching repositories"
install_server
mkdir -p workspace/server/apps-extra
for app in "${APPS_TO_INSTALL[@]}"
do
	install_app "$app"
done

cat <<EOF


 ╔═════════════════════════════════════════╗
 ║ oOo Ready to start developing 🎉        ║
 ╚═════════════════════════════════════════╝

 🚀  Start the Nextcloud server by running

	$ $DCC up -d nextcloud


 💤  Stop it with

	$ $DCC stop nextcloud


 🗑  Fresh install and wipe all data

	$ $DCC down -v
EOF

case $SERVER_CLONE in
	squashed)
		cat <<EOF

	Note that for performance reasons the server repository has been cloned with
	--depth=1. To get the full history it is highly recommended to run:

	$ cd workspace/server
	$ git fetch --unshallow
	$ git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
	$ git fetch origin

	This may take some time depending on your internet connection speed.

	You might as well use the script in scripts/download-full-history.sh.
EOF
		;;
	clone-no-blobs)
		cat <<EOF

	Note that for performance reasons the server repository has been cloned with
	--filter=blob:none. You have a complete history in the server repository.
	If you checkout older commits, git will eventually download missing blobs on
	the fly if they are not present locally.

	You should be prepared to have a live internet connection when browsing the
	history of the server repository.

	You might as well use the script in scripts/download-full-history.sh.
EOF
		;;
	full)
		;;
esac



cat <<EOF

For more details about the individual setup options see
the README.md file or checkout the repo at
https://github.com/juliusknorr/nextcloud-docker-dev
EOF
