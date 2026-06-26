# Zabbix 7.0 — Docker Compose

Local playground setup for Zabbix 7.0 using PostgreSQL as the backend database.

## Services

| Service | Image | Port |
|---|---|---|
| PostgreSQL 16 | `postgres:16-alpine` | — |
| Zabbix Server | `zabbix/zabbix-server-pgsql:7.0-alpine-latest` | 10051 |
| Zabbix Web (Nginx) | `zabbix/zabbix-web-nginx-pgsql:7.0-alpine-latest` | 8080 |
| Zabbix Agent 2 | `zabbix/zabbix-agent2:7.0-alpine-latest` | — |

## Quick start

Use the setup script for your platform. It starts all containers, waits until Zabbix is ready, and creates the `fake-pager.sh` alert script automatically.

**Linux / macOS**
```bash
chmod +x setup.sh
./setup.sh
```

**Windows (PowerShell)**
```powershell
# Allow local script execution if not already set
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

.\setup.ps1
```

Once the script completes, open the web UI:

```
http://localhost:8080
```

Default credentials: `Admin` / `zabbix`

> **Note for Windows users:** Docker Desktop must be running before executing the setup script. The script writes the alert script into the Docker volume via an Alpine container — no direct filesystem access to the Docker VM is needed.

## Manual start (without setup script)

```bash
docker compose up -d
docker compose logs -f zabbix-server
```

## First-time host configuration

After the first startup, the Zabbix Agent interface needs to be pointed to the correct container name. In the web UI:

*Data collection → Hosts → Zabbix server → Interfaces*

| Field | Value |
|---|---|
| DNS name | `zabbix-agent` |
| Connect to | DNS |
| Port | `10050` |
| IP address | `0.0.0.0` |

Zabbix 7.x requires a non-empty IP address field even when connecting via DNS — use `0.0.0.0` as a placeholder.

## Configuration

| Variable | Value |
|---|---|
| Database | `zabbix` |
| DB user | `zabbix` |
| DB password | `zabbix_pw` |
| Timezone | `Europe/Zurich` |

To change the timezone, edit the `PHP_TZ` environment variable in the `zabbix-web` service.

## Volumes

| Volume | Purpose |
|---|---|
| `zabbix-db` | PostgreSQL data |
| `zabbix-alertscripts` | Custom alert scripts for Media Types |
| `zabbix-externalscripts` | External check scripts |

## Fake Pager alert script

The setup script creates `fake-pager.sh` in the `alertscripts` volume. It simulates a pager notification by writing to a log file inside the container.

To watch alerts in real time:

```bash
docker exec zabbix-server tail -f /usr/lib/zabbix/alertscripts/pager.log
```

To configure it as a Media Type in Zabbix:

*Alerts → Media types → Create media type*

| Field | Value |
|---|---|
| Name | `Fake Pager` |
| Type | `Script` |
| Script name | `fake-pager.sh` |
| Parameter 1 | `{ALERT.SENDTO}` |
| Parameter 2 | `{ALERT.SUBJECT}` |
| Parameter 3 | `{ALERT.MESSAGE}` |

Then assign it to a user under *Users → Users → Admin → Media*.

## Zabbix Agent

The included Agent 2 monitors the Docker host itself and is pre-configured to report to the Zabbix server. It runs with `privileged: true` and mounts the Docker socket, enabling Docker-specific metrics out of the box.

In the Zabbix web UI, the agent is registered as host `zabbix-server`.

## Stopping and cleanup

Stop all containers:

```bash
docker compose down
```

Stop and remove all data (full reset):

```bash
docker compose down -v
```