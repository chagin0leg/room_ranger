#!/usr/bin/env bash

set -e

OUT_DIR="assets/data"
mkdir -p "$OUT_DIR"

MAX_RETRIES=10
SLEEP_BETWEEN=1
TIMEOUT=2

grep '\.ics' .env | cut -d= -f2- | tr -d '\r' | while read -r url; do
  url=$(echo "$url" | xargs)
  [ -z "$url" ] && continue
  echo "url='$url'"
  filename=$(basename "$url")
  dest="$OUT_DIR/$filename"

  success=0
  for attempt in $(seq 1 $MAX_RETRIES); do
    echo "Attempt $attempt: downloading $url -> $dest"
    curl -fsSL --max-time $TIMEOUT "$url" -o "$dest" && success=1 && break
    echo "Failed to download $url (attempt $attempt)"
    sleep $SLEEP_BETWEEN
  done

  if [ $success -eq 1 ] && [ -s "$dest" ]; then
    echo "✅ Successfully downloaded: $dest"
  else
    echo "❌ Failed to download $url after $MAX_RETRIES attempts"
    [ -f "$dest" ] && rm -f "$dest"
  fi

done
