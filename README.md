# 🐳 Compose DevOps Healthcheck

![GitHub release (latest by date)](https://img.shields.io/github/v/release/ylazakovich/compose-health-check-action)

[![Renovate enabled](https://img.shields.io/badge/Renovate-enabled-brightgreen.svg?logo=renovate&style=flat)](https://renovatebot.com/)
![Compose](https://img.shields.io/badge/Docker-Compose-blue?logo=docker&logoColor=white)

![Bats tests](https://img.shields.io/endpoint?url=https://ylazakovich.github.io/compose-health-check-action/tests.json)

---

## 📚 Overview

- [Features](#-features)
- [Quick start](#-quick-start)
- [Local usage with act](#-local-usage-with-act)

---

## 🚀 Features

- Full Docker Compose startup validation
- Automatic container health checks
- One-shot service exit-code verification
- Detailed diagnostics on failure
- Platform auto-detection (`DOCKER_DEFAULT_PLATFORM`)
- Multi-file compose support
- Ensures predictable, stable container startup

---

## 🖥️ Quick start

1. Define a simple `docker-compose.yml`:
2. Add workflow:

```yaml
name: "Compose Health Check"

on: [push]

jobs:
  health:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run healthcheck
        uses: ylazakovich/compose-health-check-action@v1
        with:
          compose-files: |
            docker-compose.yml
          services: "web"
          timeout: "60"
```

---

### 🟢 Healthy example

```text
Checking health status of services (running only)...
ℹ️  Service 'web' is healthy.

─────────────────────────────────────────────────────────────
ℹ️  Healthcheck summary
─────────────────────────────────────────────────────────────
  Platform:              linux/x86_64
  Global timeout:        60s (per service)
  Compose command:
      docker compose -f docker-compose.yml up -d --quiet-pull web

  Overall result:        OK (all services healthy)
  Healthy:               1
  Completed:             0
  Unhealthy:             0
  Without healthcheck:   0
  No containers:         1

──────────────────────────────────────────────
ℹ️  Detected services:
──────────────────────────────────────────────
   1. slow-broken  [SKIP]
   2. web          [HEALTHY]
──────────────────────────────────────────────

Application started successfully!
```

---

### 🔴 Unhealthy example

```text
─────────────────────────────────────────────────────────────
ℹ️  Healthcheck summary
─────────────────────────────────────────────────────────────
  Platform:              linux/amd64
  Global timeout:        10s (per service)
  Compose command:
      docker compose -f docker-compose.yml up -d slow-broken

  Overall result:        FAILED (unhealthy services detected)
  Services checked:      1
  Healthy:               0
  Unhealthy:             1
  Without healthcheck:   0
  No containers:         0

Unhealthy services:
  - slow-broken (Health=unhealthy)
─────────────────────────────────────────────────────────────

Last 50 health logs:
  wget: can't connect to remote host: Connection refused
  wget: can't connect to remote host: Connection refused
  ...
─────────────────────────────────────────────────────────────
```

---

### ⚠️ No services example

```text
❌ No services specified. Either:
    - pass services in docker compose command, e.g. 'docker compose up -d web api'
    - or set DOCKER_SERVICES_LIST environment variable (space-separated list of services).
```

---

### ❌ Compose failed example

```text
ℹ️️️ Diagnostics summary
─────────────────────────────────────────────────────────────
  Platform:              linux/amd64
  Global timeout:        10s (per service)
  Compose command:
      docker compose -f docker-compose-NOT-FOUND.yml up -d

ℹ️  --- docker compose output (last 25 lines) ---
open docker-compose-NOT-FOUND.yml: no such file or directory
─────────────────────────────────────────────────────────────

ℹ️  --- docker compose ps --all ---
NAME                                        STATUS                     IMAGE
compose-health-check-action-web-1           Up 2h (healthy)           nginx:1.29-alpine
compose-health-check-action-slow-broken-1   Up 2h (unhealthy)         python:3.12-alpine
─────────────────────────────────────────────────────────────

ℹ️  --- docker compose ls (all projects) ---
compose-health-check-action   running(2)    docker-compose.yml
─────────────────────────────────────────────────────────────

ℹ️  --- docker ps --all (global) ---
act-Workflow-when-no-services   Up 2s   ghcr.io/catthehacker/ubuntu:act-latest
─────────────────────────────────────────────────────────────
```

---

## 💻 Local usage with act

Run the action locally with a modern GitHub Actions runner image:

```bash
act push \
  --rm \
  -W .github/workflows/healthy.yml \
  -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest
```

Or execute the checker directly:

```bash
./action.sh docker compose up -d web
```

---
