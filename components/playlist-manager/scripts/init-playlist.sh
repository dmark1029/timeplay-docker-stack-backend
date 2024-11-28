#!/bin/bash

ARG="$1"

docker cp "./$ARG" "asset-manager:/"
docker exec -i asset-manager sh -c "npm run setup /$ARG/assets.manifest.json /$ARG/assets"

docker cp "./$ARG" "playlist-manager:/"
docker exec -i playlist-manager sh -c "npm run setup /$ARG/$ARG.json"
