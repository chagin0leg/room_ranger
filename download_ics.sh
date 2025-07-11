#!/usr/bin/env bash

set -e

if [ ! -f .env ]; then
  echo "❌ .env file not found!" >&2
  exit 2
fi

OUT_DIR="assets/data"
if ! mkdir -p "$OUT_DIR"; then
  echo "❌ Failed to create directory $OUT_DIR" >&2
  exit 3
fi

MAX_RETRIES=10
SLEEP_BETWEEN=1
TIMEOUT=2

ics_count=$(grep -c '\.ics' .env || true)
if [ "$ics_count" -eq 0 ]; then
  echo "❌ No .ics links found in .env" >&2
  exit 4
fi

grep '\.ics' .env | cut -d= -f2- | tr -d '\r' | while read -r url; do
  url=$(echo "$url" | xargs)
  [ -z "$url" ] && continue
  echo "url='$url'"
  if [[ "$url" =~ /ical/([0-9a-zA-Z]+) ]]; then
    filename="${BASH_REMATCH[1]}.ics"
  else
    filename=$(basename "$url")
  fi
  dest="$OUT_DIR/$filename"

  success=0
  for attempt in $(seq 1 $MAX_RETRIES); do
    echo "Attempt $attempt: downloading $url -> $dest"
    curl --ssl-no-revoke -fsSL --max-time $TIMEOUT \
      -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
      -H "Accept: text/calendar, text/plain, */*" \
      -H "Accept-Language: ru-RU,ru;q=0.9,en;q=0.8" \
      -H "Referer: https://chagin0leg.github.io/" \
      -H "Origin: https://chagin0leg.github.io" \
      "$url" -o "$dest" && success=1 && break
    echo "Failed to download $url (attempt $attempt)"
    sleep $SLEEP_BETWEEN
  done

  if [ $success -eq 1 ] && [ -s "$dest" ]; then
    echo "✅ Successfully downloaded: $dest"
    if grep -q '^DTSTAMP' "$dest"; then
      sed -i '/^DTSTAMP/d' "$dest"
      echo "🧹 DTSTAMP lines cleaned in: $dest"
    fi
  else
    echo "❌ Failed to download $url after $MAX_RETRIES attempts"
    [ -f "$dest" ] && rm -f "$dest"
  fi

done
