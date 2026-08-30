#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# localPath="${SCRIPT_DIR}/.."
basePath="${SCRIPT_DIR}/.."
aliasesFile="${SCRIPT_DIR}/aliases"

# Configuration from CLI -- here comes the defaults
selftest_alias_update=y
command=create

get_alias_content () {

    if [ "$selftest_alias_update" = "y" ]
    then
        cat <<EOF
# Test if aliases file is up to date
if [ ! -f "$aliasesFile" ]
then
    echo "The file $aliasesFile does not exist."
    echo "This is strange as I (the apparent alias script) am running at the moment."
    echo "Please check your setup and verify the correct alias file is configured."
fi

"${SCRIPT_DIR}/create-aliases.sh" --check-alias-file

EOF
    fi

    cat <<EOF
nc-docker() {
    local DCC=\$(
        source "${SCRIPT_DIR}/../.env"
        source "${SCRIPT_DIR}/functions.sh"
        echo "\$(get_docker_compose_command)"
    )

    if [ -z "\$DCC" ]
    then
        echo "❌ Install docker-compose before running this script"
        return
    fi

    (cd "$basePath" && \$DCC "\$@")
}

nc-occ () {
    "${SCRIPT_DIR}/occ.sh" "\$@"
}

nc-mysql () {
    "${SCRIPT_DIR}/mysql.sh" "\$@"
}

nc-cd () {
    if [ \$# -eq 1 ]
    then
        cd "$basePath/workspace/\$1"
    else
        cd "$basePath/workspace"
    fi
}
EOF
}

check_alias_content () {
    if ! diff "$aliasesFile" <(get_alias_content) > /dev/null
    then
        echo "The aliases file $aliasesFile of the NC docker development environment is not up to date."
        echo "Please upgrade using ${SCRIPT_DIR}/create-aliases.sh"
    fi
}

update_alias_file () {
    echo "Writign new aliases file to ${aliasesFile}"
    get_alias_content > "$aliasesFile"
    cat <<EOF
The file $aliasesFile has been created.

You can now source this file in your shell:
    source "$aliasesFile"
Then, the aliases will be available in your shell.

You can as well put this source command in your .bashrc. That way, the aliases are available in all shells.
To do so, the following snippet can be appended to your .bashrc:

    # NC docker aliases
    if [ -f "$aliasesFile" ]
    then
        source "$aliasesFile"
    fi
EOF
}

print_help() {
    cat <<EOF
Create aliases for the NC docker development environment.

Usage:
    ${SCRIPT_DIR}/create-aliases.sh [OPTIONS]

Options:
    --no-selftest
        Do not check if the aliases file is up to date while evaluating the aliases.
        If you want to customize the aliases, this prevents the alias self-test from throwing errors at you.
        If you want to change this setting, you have to recreate the aliases file.
    --stdout
        Print the aliases content to stdout instead of creating the aliases file.
    --check-alias-file
        Check if the aliases file is up to date.
        This is only needed internally and should not be used by end users.
    --help | -h
        Print this help.
EOF
}

while [ $# -gt 0 ]
do
    case "$1" in
        -h|--help)
            print_help
            exit 0
            ;;
        --check-alias-file)
            command=check
            ;;
        --no-selftest)
            selftest_alias_update=n
            ;;
        --stdout)
            command=stdout
            ;;
        *)
            echo "Parameter $1 is not recognized."
            echo "Cannot create aliases file."
            exit 1
            ;;
    esac
    shift
done

case "$command" in
    check)
        check_alias_content
        exit 0
        ;;
    create)
        update_alias_file
        ;;
    stdout)
        get_alias_content
        ;;
esac
