#!/bin/bash

ENV_FILE="${BASH_SOURCE[0]%.sh}.env"

if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" <<EOF
QB_URL="http://localhost:8080"
QB_USER="admin"
QB_PASS="adminadmin"
SONARR_URL="http://localhost:8989"
SONARR_API_KEY="your-api-key-here"
LOG="${ENV_FILE%.env}.log"
EOF
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

# Only act on upgrade events
[ "${sonarr_eventtype:-}" = "Download" ] || exit 0
[ "${sonarr_isupgrade:-}" = "True" ] || exit 0
[ -n "${sonarr_episodefile_episodeids:-}" ] || { log "No episode IDs in event"; exit 0; }
[ -n "${sonarr_download_id:-}" ] || { log "No download ID in event"; exit 0; }

EPISODE_ID=$(echo "$sonarr_episodefile_episodeids" | cut -d',' -f1)
NEW_HASH=$(echo "$sonarr_download_id" | tr '[:upper:]' '[:lower:]')

log "Upgrade detected — episode: $EPISODE_ID, new hash: $NEW_HASH"

# Find old torrent hash from Sonarr history
HISTORY=$(curl -sf \
    -H "X-Api-Key: $SONARR_API_KEY" \
    "$SONARR_URL/api/v3/history?episodeId=$EPISODE_ID&pageSize=20&sortKey=date&sortDir=desc")

OLD_HASH=$(echo "$HISTORY" | jq -r --arg new "$NEW_HASH" '
    .records
    | map(select(.eventType == "grabbed" and .downloadId != null))
    | map(.downloadId |= ascii_downcase)
    | map(select(.downloadId != $new))
    | first
    | .downloadId // empty')

if [ -z "$OLD_HASH" ]; then
    log "No previous grab found in Sonarr history for episode $EPISODE_ID"
    exit 0
fi

log "Old torrent hash: $OLD_HASH — deleting from qBittorrent"

# Login to qBittorrent
COOKIEJAR=$(mktemp)
trap 'rm -f "$COOKIEJAR"' EXIT

if ! curl -sf -c "$COOKIEJAR" \
    --data-urlencode "username=$QB_USER" \
    --data-urlencode "password=$QB_PASS" \
    "$QB_URL/api/v2/auth/login" > /dev/null; then
    log "ERROR: qBittorrent login failed"
    exit 1
fi

curl -sf -b "$COOKIEJAR" \
    --data "hashes=$OLD_HASH&deleteFiles=true" \
    "$QB_URL/api/v2/torrents/delete" > /dev/null

log "Deleted torrent $OLD_HASH (with files)"
