#!/usr/bin/env bash
set -e

COMPOSE_FILE="docker-compose.yml"
VOLUME_NAME="zabbix-sandbox_zabbix-alertscripts"
PAGER_SCRIPT="fake-pager.sh"

echo ""
echo "=== Zabbix Sandbox Setup ==="
echo ""

# Check dependencies
for cmd in docker; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is not installed or not in PATH."
    exit 1
  fi
done

if ! docker compose version &>/dev/null; then
  echo "ERROR: 'docker compose' (v2) is not available."
  echo "       Make sure Docker Desktop or the Compose plugin is installed."
  exit 1
fi

# Start containers
echo "[1/4] Starting containers..."
docker compose -f "$COMPOSE_FILE" up -d

# Wait for Zabbix server to become healthy
echo "[2/4] Waiting for Zabbix server to be ready (this takes ~60 seconds)..."
RETRIES=30
until docker compose -f "$COMPOSE_FILE" logs zabbix-server 2>&1 | grep -q "server #0 started"; do
  RETRIES=$((RETRIES - 1))
  if [ "$RETRIES" -eq 0 ]; then
    echo ""
    echo "ERROR: Zabbix server did not start in time."
    echo "       Run 'docker compose logs zabbix-server' to investigate."
    exit 1
  fi
  printf "."
  sleep 5
done
echo ""
echo "       Zabbix server is up."

# Locate alertscripts volume mountpoint
echo "[3/4] Locating alertscripts volume..."
MOUNT=$(docker volume inspect "$VOLUME_NAME" --format '{{ .Mountpoint }}' 2>/dev/null || true)

if [ -z "$MOUNT" ]; then
  echo "ERROR: Volume '$VOLUME_NAME' not found."
  echo "       Make sure the compose project name matches 'zabbix-sandbox'."
  exit 1
fi

# Write fake-pager.sh
echo "[4/4] Creating $PAGER_SCRIPT..."
SCRIPT_PATH="$MOUNT/$PAGER_SCRIPT"
LOG_PATH="/usr/lib/zabbix/alertscripts/pager.log"

sudo tee "$SCRIPT_PATH" > /dev/null << 'SCRIPT'
#!/bin/sh
echo "$(date) | TO: $1 | SUBJECT: $2 | MSG: $3" >> /usr/lib/zabbix/alertscripts/pager.log
SCRIPT

sudo chmod +x "$SCRIPT_PATH"
echo "       Script written to: $SCRIPT_PATH"

echo ""
echo "=== Setup complete ==="
echo ""
echo "  Web UI:       http://localhost:8080"
echo "  Login:        Admin / zabbix"
echo ""
echo "  To watch incoming pager alerts:"
echo "  docker exec zabbix-server tail -f $LOG_PATH"
echo ""