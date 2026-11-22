#!/usr/bin/env bash
# Pulls the latest BoM radar frames + map layers from BoM's public FTP into ./site
# IDR023 = Melbourne 128 km range (wide view), IDR024 = Melbourne 64 km range (close-up)
set -euo pipefail
IDS="${RADAR_IDS:-IDR023 IDR024}"
FRAMES="${FRAMES:-6}"
EMAIL="${BOM_EMAIL:-anonymous@example.com}"
FTP="ftp://ftp.bom.gov.au/anon/gen"
C="curl -sS --fail --retry 3 --user anonymous:${EMAIL}"

mkdir -p site
LISTING=$($C --list-only "$FTP/radar/")
VIEWS=""

for ID in $IDS; do
  LIST=$(echo "$LISTING" | grep -E "^${ID}\.T\.[0-9]{12}\.png$" | sort | tail -n "$FRAMES" || true)
  if [ -z "$LIST" ]; then echo "No frames found for $ID"; continue; fi

  JF=""
  for f in $LIST; do
    $C -o "site/$f" "$FTP/radar/$f"
    ts="${f:${#ID}+3:12}"   # yyyymmddHHMM in UTC
    iso="${ts:0:4}-${ts:4:2}-${ts:6:2}T${ts:8:2}:${ts:10:2}:00Z"
    JF="${JF}${JF:+,}{\"file\":\"$f\",\"time\":\"$iso\"}"
  done

  UNDER=""; OVER=""
  for L in background topography; do
    if $C -o "site/$ID.$L.png" "$FTP/radar_transparencies/$ID.$L.png"; then UNDER="${UNDER}${UNDER:+,}\"$ID.$L.png\""; fi
  done
  for L in range locations; do
    if $C -o "site/$ID.$L.png" "$FTP/radar_transparencies/$ID.$L.png"; then OVER="${OVER}${OVER:+,}\"$ID.$L.png\""; fi
  done

  VIEWS="${VIEWS}${VIEWS:+,}\"$ID\":{\"frames\":[${JF}],\"under\":[${UNDER}],\"over\":[${OVER}]}"
done

[ -n "$VIEWS" ] || { echo "No radar frames at all"; exit 1; }
echo "window.kbRadar && kbRadar({\"views\":{${VIEWS}}});" > site/frames.js
echo "<!doctype html><title>radar</title><p>Kitchen board radar frames.</p>" > site/index.html
ls -la site
