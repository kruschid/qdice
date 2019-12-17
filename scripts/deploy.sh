#!/bin/bash

set -e

rsync -az --force --delete --progress --exclude-from=rsync_exclude.txt -e "ssh -p22 " ./ gipsy@qdice.wtf:/home/gipsy/nodice || exit 1

ssh -tt gipsy@qdice.wtf <<'ENDSSH'
cd nodice
docker-compose pull nodice
./scripts/restart.sh
exit 0
ENDSSH
