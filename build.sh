#!/usr/bin/env bash
# exit on error
set -o errexit

source '/etc/secrets/.env'

# Initial setup
mix hex.repo add oban https://getoban.pro/repo \
    --fetch-public-key $OBAN_PUBLIC_KEY \
    --auth-key $OBAN_AUTH_KEY
mix deps.get --only prod
MIX_ENV=prod mix compile

# Build the release and overwrite the existing release directory
MIX_ENV=prod mix release --overwrite

# for auto DB migration upon deploy
MIX_ENV=prod mix ecto.migrate
