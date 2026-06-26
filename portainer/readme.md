# Portainer CE — Docker Compose

Standalone Portainer Community Edition setup for managing local Docker environments via a web UI.

## Services

| Service | Image | Ports |
|---|---|---|
| Portainer CE | `portainer/portainer-ce:latest` | 9000 (HTTP), 9443 (HTTPS), 8000 (Edge Agent) |

## Getting started

```bash
docker compose -f docker-compose.portainer.yml up -d
```

Then open the web UI:

```
http://localhost:9000
```

> **Important:** On first startup you must set an admin password within **5 minutes**. If you miss this window, Portainer locks itself for security reasons. To reset, restart the container:
> ```bash
> docker compose -f docker-compose.portainer.yml restart portainer
> ```

## Ports

| Port | Purpose |
|---|---|
| 9000 | HTTP web UI |
| 9443 | HTTPS web UI |
| 8000 | Edge Agent tunnel — only needed for managing remote environments |

If you are only managing a local Docker host, you can comment out port `8000` in the compose file.

## Managing the Zabbix stack from Portainer

Once Portainer is running, you can deploy the Zabbix stack directly from the UI:

1. Go to **Stacks → Add stack**
2. Choose **Upload** and select `docker-compose.yml`
3. Name the stack (e.g. `zabbix`) and click **Deploy the stack**

This gives you a visual overview of all Zabbix containers, logs, and resource usage in one place.

## Volumes

| Volume | Purpose |
|---|---|
| `portainer-data` | Portainer configuration and state |

## Stopping and cleanup

Stop Portainer:

```bash
docker compose -f docker-compose.portainer.yml down
```

Stop and remove all data (full reset):

```bash
docker compose -f docker-compose.portainer.yml down -v
```