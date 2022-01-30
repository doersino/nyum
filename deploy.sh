#!/usr/bin/env bash

# exit on errors
set -euxo

# parse arguments
QUIET=false
DRYRUN=false
while [[ $# -gt 0 ]]; do
    if [ "$1" = "-q" ] || [ "$1" = "--quiet" ]; then
        QUIET=true
        shift
    elif [ "$1" = "-n" ] || [ "$1" = "--dry-run" ]; then
        DRYRUN=true
        shift
    elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Usage: bash deploy.sh [-q | --quiet] [-n | --dry-run]"
        echo "  Deploys the contents of _site/ to the remote location specified in config.yaml using rsync."
        exit
    else
        shift
    fi
done

function status {
    $QUIET && return
    BOLD=$(tput bold)
    NORMAL=$(tput sgr0)
    echo "${BOLD}$*${NORMAL}"
}

function x {
    _IFS="$IFS"
    IFS=" "
    $QUIET || echo "↪" "$*" >&2
    IFS="$_IFS"
    "$@"
}

status "Reading remote configuration..."
x pandoc _templates/technical/empty.md --metadata title="dummy" --metadata-file config.yaml --template _templates/technical/deploy_remote_server.template.txt -t html -o _temp/deploy_remote_server.txt
REMOTE_SERVER="$(cat _temp/deploy_remote_server.txt)"
x pandoc _templates/technical/empty.md --metadata title="dummy" --metadata-file config.yaml --template _templates/technical/deploy_remote_path.template.txt -t html -o _temp/deploy_remote_path.txt
REMOTE_PATH="$(cat _temp/deploy_remote_path.txt)"
if [ -z "$REMOTE_SERVER" ]; then
    status "Can't deploy - it seems like you haven't specified a remote."
    exit 1
fi

status "Deploying..."
FLAGS="--verbose"
$QUIET && FLAGS="--quiet"
$DRYRUN && FLAGS="$FLAGS --dry-run"
#x rsync -a --delete "$FLAGS" "_site/" "$REMOTE

lftp -e "mirror -eRv _site/ $REMOTE_PATH; quit;" -u 5118117,${UPLOAD} $REMOTE_SERVER

status "Success!"
