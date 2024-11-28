#!/bin/bash

# Initializing SKUs
docker exec -i web-client-service sh -c "npm run setup ./scripts/bingo-sku.json"
docker exec -i web-client-service sh -c "npm run setup ./scripts/trivia-sku.json"
docker exec -i web-client-service sh -c "npm run setup ./scripts/wof-sku.json"
docker exec -i web-client-service sh -c "npm run setup ./scripts/ff-sku.json"

# Initializing rewards
docker exec -i reward-service sh -c "npm run setup ./scripts/bingo-reward.json"
docker exec -i reward-service sh -c "npm run setup ./scripts/trivia-reward.json"
docker exec -i reward-service sh -c "npm run setup ./scripts/wof-reward.json"
docker exec -i reward-service sh -c "npm run setup ./scripts/ff-reward.json"
