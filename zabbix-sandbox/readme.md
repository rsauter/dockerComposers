# Zabbix 7.0 — Sandbox

Local playground for learning and testing Zabbix 7.0, including the tag-based alert routing concept as an alternative to PRTG-style per-sensor notification settings.

## What you will learn

- How Zabbix structures monitoring: Host → Item → Trigger → Action → Media Type
- How to route alerts to different channels (Pager, SMS, Teams) using Trigger Tags
- Why new sensors are silent by default (Opt-in model)
- How to control alerting per Trigger, per Host, and per Template

---

## Prerequisites

- Docker with Compose v2 (`docker compose version`)
- Linux or macOS: `sudo` access (needed to write into Docker volumes)
- Windows: Docker Desktop running

---

## Quick start

**Linux / macOS**
```bash
chmod +x setup.sh
./setup.sh
```

**Windows (PowerShell)**
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\setup.ps1
```

The setup script:
1. Starts all containers
2. Waits until Zabbix is ready (~60 seconds)
3. Creates the `fake-pager.sh` alert script in the alertscripts volume

Once done, open the web UI:
```
http://localhost:8080
```

Default credentials: `Admin` / `zabbix`

---

## Services

| Service | Image | Port |
|---|---|---|
| PostgreSQL 16 | `postgres:16-alpine` | — |
| Zabbix Server | `zabbix/zabbix-server-pgsql:7.0-alpine-latest` | 10051 |
| Zabbix Web (Nginx) | `zabbix/zabbix-web-nginx-pgsql:7.0-alpine-latest` | 8080 |
| Zabbix Agent 2 | `zabbix/zabbix-agent2:7.0-alpine-latest` | — |

---

## Step 1 — Fix the Agent interface

After the first startup, the host interface needs to point to the correct container name.

*Data collection → Hosts → zabbix-server → click hostname → Interfaces*

| Field | Value |
|---|---|
| IP address | `0.0.0.0` |
| DNS name | `zabbix-agent` |
| Connect to | **DNS** |
| Port | `10050` |

Click **Update**.

> Zabbix 7.x requires a non-empty IP address field even when connecting via DNS — use `0.0.0.0` as placeholder.

Also verify the Host name matches the agent's hostname exactly:

*Tab "Host" → Host name: `zabbix-server`* (lowercase, with hyphen)

---

## Step 2 — Create the Fake Pager Media Type

*Alerts → Media types → Create media type*

| Field | Value |
|---|---|
| Name | `Fake Pager` |
| Type | `Script` |
| Script name | `fake-pager.sh` |

Under **Script parameters**, click Add three times:

| # | Value |
|---|---|
| 1 | `{ALERT.SENDTO}` |
| 2 | `{ALERT.SUBJECT}` |
| 3 | `{ALERT.MESSAGE}` |

Under **Message templates**, click Add:

| Field | Value |
|---|---|
| Message type | `Problem` |
| Subject | `Problem: {EVENT.NAME}` |
| Message | `Problem started at {EVENT.TIME} on {EVENT.DATE}`<br>`Problem name: {EVENT.NAME}`<br>`Host: {HOST.NAME}`<br>`Severity: {EVENT.SEVERITY}` |

Add a second Message template for `Problem recovery` with a similar message.

Click **Add** to save.

---

## Step 3 — Assign Media Type to Admin user

*Users → Users → Admin → Tab "Media" → Add*

| Field | Value |
|---|---|
| Type | `Fake Pager` |
| Send to | `pager-test` |

Click **Add → Update**.

---

## Step 4 — Create the Action

*Alerts → Actions → Trigger actions → Create action*

**Tab "Action"**

| Field | Value |
|---|---|
| Name | `Notify: Pager` |

**Tab "Conditions" → Add**

| Field | Value |
|---|---|
| Type | `Tag value` |
| Tag | `notify` |
| Operator | `equals` |
| Value | `pager` |

**Tab "Operations" → Add**

| Field | Value |
|---|---|
| Operation type | `Send message` |
| Send to users | `Admin` |
| Send only to | `Fake Pager` |

Click **Add** to save the operation, then **Add** to save the action.

> The default action "Report problems to Zabbix administrators" should remain **Disabled** — otherwise it fires on every trigger regardless of tags.

---

## Step 5 — Tag a Trigger

Tags must be set on the **Trigger**, not on the Host or Template, to control routing per individual sensor.

*Data collection → Hosts → zabbix-server → Triggers → "Linux: Zabbix agent is not available" → Tab "Tags" → Add*

| Tag | Value |
|---|---|
| `notify` | `pager` |

Click **Update**.

> Only triggers with `notify=pager` will fire the Pager action. All other triggers remain silent — this is the Opt-in model.

---

## Step 6 — Test the full flow

Stop the agent to trigger an alert:

```bash
docker compose stop zabbix-agent
```

Wait ~3 minutes, then check *Monitoring → Problems* — the trigger should appear.

Watch the pager log in real time:

```bash
docker exec zabbix-server tail -f /usr/lib/zabbix/alertscripts/pager.log
```

You should see an entry like:
```
Fri Jun 26 14:07:26 UTC 2026 | TO: pager-test | SUBJECT: Problem: Linux: Zabbix agent is not available (for 3m)
Problem name: Linux: Zabbix agent is not available (for 3m)
Host: zabbix-server
Severity: Average
```

Restart the agent when done:

```bash
docker compose start zabbix-agent
```

Check *Reports → Action log* for a full audit trail of all sent notifications.

---

## Tag convention

This sandbox uses a tag-based Opt-in model for alert routing. No tag = no alert.

### Notify tags (set on Trigger)

| Tag | Value | Channel |
|---|---|---|
| `notify` | `pager` | Pager — critical, immediate |
| `notify` | `sms` | SMS — important, not immediate |
| `notify` | `teams` | Microsoft Teams — informational |

Tags can be combined on a single trigger for multi-channel routing.

### Scope tags (set on Template)

| Tag | Value | Meaning |
|---|---|---|
| `scope` | `availability` | Service up/down |
| `scope` | `performance` | Thresholds, latency |
| `scope` | `capacity` | Disk, memory, limits |

### Escalation model

A single Action can escalate across channels using Steps:

| Step | Channel | When |
|---|---|---|
| 1 | Teams | immediately |
| 2 | SMS | after 30 min if unresolved |
| 3 | Pager | after 1h if unresolved |

---

## Tag layers

Zabbix allows tags at three levels — from coarse to fine:

| Level | Purpose | Example |
|---|---|---|
| Template | Classify all triggers of this template | `class: os` |
| Trigger | Route this specific alert | `notify: pager` |
| Host (Override) | Exception for a specific host | Remove `notify: pager` for one host only |

New sensors added to a template are silent by default until a `notify` tag is explicitly set on their trigger.

---

## Volumes

| Volume | Purpose |
|---|---|
| `zabbix-db` | PostgreSQL data |
| `zabbix-alertscripts` | Alert scripts (fake-pager.sh lives here) |
| `zabbix-externalscripts` | External check scripts |

---

## Stopping and cleanup

Stop all containers:
```bash
docker compose down
```

Full reset including all data:
```bash
docker compose down -v
```