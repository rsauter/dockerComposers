# Zabbix 7.0 — Docker Compose

Local playground setup for Zabbix 7.0 using PostgreSQL as the backend database.

## Services

| Service | Image | Port |
|---|---|---|
| PostgreSQL 16 | `postgres:16-alpine` | — |
| Zabbix Server | `zabbix/zabbix-server-pgsql:7.0-alpine-latest` | 10051 |
| Zabbix Web (Nginx) | `zabbix/zabbix-web-nginx-pgsql:7.0-alpine-latest` | 8080 |
| Zabbix Agent 2 | `zabbix/zabbix-agent2:7.0-alpine-latest` | — |

## Getting started

```bash
docker compose up -d
```

The first startup takes about 60 seconds while the database schema is initialized. You can follow the progress with:

```bash
docker compose logs -f zabbix-server
```

Once the server is ready, open the web UI:

```
http://localhost:8080
```

Default credentials: `Admin` / `zabbix`

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

The `alertscripts` volume is particularly useful for this playground: you can drop custom scripts there (e.g. a simulated pager notification) without rebuilding the container.

To find the volume path on disk:

```bash
docker volume inspect zabbix_zabbix-alertscripts
```

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