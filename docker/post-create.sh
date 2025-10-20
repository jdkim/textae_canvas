#!/usr/bin/env bash
set -euo pipefail

ruby -v || true
bundler -v || gem install bundler
bundle config set path vendor/bundle
bundle install
cp -n .env.example .env 2>/dev/null || true
bin/rails db:setup || bundle exec rails db:setup || true
curl -s http://es:9200 >/dev/null 2>&1 || true
curl -X PUT "http://es:9200/smart_multilingual" -H "Content-Type: application/json" -d @./docker/es_index.json || true
