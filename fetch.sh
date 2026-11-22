#!/usr/bin/env bash
# Pulls the latest BoM radar frames + map layers from BoM's public FTP into ./site
set -euo pipefail
ID="${RADAR_ID:-IDR023}"          # Melbourne 128 km. IDR022 = 256 km, IDR024 = 64 km
FRAMES="${FRAMES:-6}"
EMAIL="${BOM_EMAIL:-anonymous@example.com}"
FTP="ftp://ftp.bom.gov.au/anon/gen"
C="curl -sS --fail --retry 3 --user anonymous:${EMAIL}"

mkdir -p site
LIST=$($C --list-only "$FTP/radar/" | grep -E "^${ID}\.T\.[0-9]{12}\.png$" | sort | tail -n "$FRAMES")
[ -n "$LIST" ] || { echo "No frames found for $ID"; exit 1; }

JSON_FRAMES=""
for f in $LIST; do
  $C -o "site/$f" "$FTP/radar/$f"
  ts="${f:${#ID}+3:12}"   # yyyymmddHHMM in UTC
  iso="${ts:0:4}-${ts:4:2}-${ts:6:2}T${ts:8:2}:${ts:10:2}:00Z"
  JSON_FRAMES="${JSON_FRAMES}${JSON_FRAMES:+,}{\"file\":\"$f\",\"time\":\"$iso\"}"
done

UNDER=""; OVER=""
for L in background topography; do
  if $C -o "site/$ID.$L.png" "$FTP/radar_transparencies/$ID.$L.png"; then UNDER="${UNDER}${UNDER:+,}\"$ID.$L.png\""; fi
done
for L in range locations; do
  if $C -o "site/$ID.$L.png" "$FTP/radar_transparencies/$ID.$L.png"; then OVER="${OVER}${OVER:+,}\"$ID.$L.png\""; fi
done

echo "window.kbRadar && kbRadar({\"frames\":[${JSON_FRAMES}],\"under\":[${UNDER}],\"over\":[${OVER}]});" > site/frames.js
echo "<!doctype html><title>radar</title><p>Kitchen board radar frames for $ID.</p>" > site/index.html
ls -la site
