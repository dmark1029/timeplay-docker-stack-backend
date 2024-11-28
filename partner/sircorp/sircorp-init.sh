#!/bin/bash

docker cp "assets/sircorp-regform.json" "web-client-service:/reg.json"
docker exec -i web-client-service sh -c "npm run setup /reg.json"
