#!/bin/bash
set -e

APPLICATION_USERNAME="${MONGO_APP_USERNAME}"
APPLICATION_PASSWORD="${MONGO_APP_PASSWORD}"
READONLY_USERNAME="${MONGO_RO_USERNAME}"
READONLY_PASSWORD="${MONGO_RO_PASSWORD}"

mongo <<EOF
use admin

db.createUser({
  user: "${APPLICATION_USERNAME}",
  pwd: "${APPLICATION_PASSWORD}",
  roles: [
    { role: "root", db: "admin" },
    { role: "dbAdminAnyDatabase", db: "admin" }
  ]
})

db.createUser({
  user: "${READONLY_USERNAME}",
  pwd: "${READONLY_PASSWORD}",
  roles: [{ role: "readAnyDatabase", db: "admin" }]
})
EOF
