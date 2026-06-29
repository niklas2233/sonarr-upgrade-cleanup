# sonarr-upgrade-cleanup

Automatically deletes the old torrent (and its files) from qBittorrent when Sonarr upgrades an episode to a better quality.

## How it works

When Sonarr upgrades an episode, it calls this script. The script queries Sonarr's history API to find the previous torrent hash for that episode, then deletes it from qBittorrent.

## Requirements

- Sonarr running in Docker
- qBittorrent with Web UI enabled
- `curl` and `jq` available in the Sonarr container

## Setup

**1. Place the script inside a volume mounted to the Sonarr container.**

For example, if your compose has:
```yaml
volumes:
  - /mnt/tank/media:/media
```
Copy the script to `/mnt/tank/media/sonarr-upgrade-cleanup.sh` on the host.

**2. Make it executable:**
```bash
chmod +x /mnt/tank/media/sonarr-upgrade-cleanup.sh
```

**3. Run it once to generate the env file, then edit it:**
```bash
bash /mnt/tank/media/sonarr-upgrade-cleanup.sh
nano /mnt/tank/media/sonarr-upgrade-cleanup.env
```

```env
QB_URL="http://<qbittorrent-ip>:8080"
QB_USER="admin"
QB_PASS="your-password"
SONARR_URL="http://localhost:8989"
SONARR_API_KEY="your-api-key"
LOG="/media/sonarr-upgrade-cleanup.log"
```

> `SONARR_URL` uses `localhost` because the script runs inside the Sonarr container.  
> `LOG` uses the container-internal path.

**4. Add a Custom Script connection in Sonarr:**

Settings → Connect → + Custom Script
- **Path:** `/media/sonarr-upgrade-cleanup.sh` (container path)
- **Notification Triggers:** enable **On File Import** and **On Upgrade**

The script exits immediately for non-upgrade imports, so enabling both is required but harmless.
