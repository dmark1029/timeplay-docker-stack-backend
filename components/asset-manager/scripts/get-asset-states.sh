#!/bin/bash
#
# This script will query the mongodb database, and list the number of assets
# in each of the known states
#
# Usage:
#   ./show-asset-states.sh
#
################################################################################

set -o nounset
set -o errexit
set -o pipefail

assetsPending=$(docker exec -i mongodb mongo asset-manager --eval 'db.assets.count({"status": "pending"})' | tail -n 1)
assetsError=$(docker exec -i mongodb mongo asset-manager --eval 'db.assets.count({"status": "error"})' | tail -n 1)
assetsDownloading=$(docker exec -i mongodb mongo asset-manager --eval 'db.assets.count({"status": "downloading"})' | tail -n 1)
assetsDone=$(docker exec -i mongodb mongo asset-manager --eval 'db.assets.count({"status": "done"})' | tail -n 1)

echo "Asset summary"
echo "============="
echo "pending: ${assetsPending}"
echo "error: ${assetsError}"
echo "downloading: ${assetsDownloading}"
echo "done: ${assetsDone}"
echo ""
