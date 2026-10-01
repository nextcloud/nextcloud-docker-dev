#!/usr/bin/env bash -e

isShallow() {
    # Reference: https://stackoverflow.com/a/37533086
    local isShallow
    isShallow="$(git rev-parse --is-shallow-repository)"
    if [ "$isShallow" = 'true' ]
    then
        return 0
    else
        return 1
    fi
}

unshallow() {
    echo "Unshallowing installation as it is needed"
    git fetch --unshallow
}

isPartialClone() {
    git config --get "remote.$1.partialclonefilter" &> /dev/null && return 0 || return 1
}

unpartial () {
    git config --unset "remote.$1.partialclonefilter"
    git fetch --refetch
}

UNSHALLOW=1
UNPARTIAL=1
REPOSITORY=workspace/server
ORIGIN=origin

while [ $# -gt 0 ]
do
    case "$1" in
        --no-unshallow)
            UNSHALLOW=0
            ;;
        --unshallow)
            UNSHALLOW=1
            ;;
        --no-unpartial)
            UNPARTIAL=0
            ;;
        --unpartial)
            UNPARTIAL=1
            ;;
        --repository)
            REPOSITORY="$2"
            shift
            ;;
        --origin)
            ORIGIN="$2"
            shift
            ;;
        *)
            echo "Unknown parameter '$1' found. Exiting."
            exit 1
            ;;
    esac
    shift
done

cd "$REPOSITORY"

if [ "$UNSHALLOW" = 1 ]
then
    if isShallow
    then
        unshallow
    else
        echo 'The repository is already unshallowed'
    fi
fi

if [ "$UNPARTIAL" = 1 ]
then
    if isPartialClone "$ORIGIN"
    then
        echo 'Partial clone found'
        unpartial "$ORIGIN"
    else
        echo 'Repository does not contain partial clones'
    fi
fi
