# 🐳 Compose Health Check Action

![Compose](https://img.shields.io/badge/Docker-Compose-blue?logo=docker&logoColor=white)
[![Renovate enabled](https://img.shields.io/badge/Renovate-enabled-brightgreen.svg?logo=renovate&style=flat)](https://renovatebot.com/)

![Local Compose Health](https://github.com/ylazakovich/compose-health-check-action/actions/workflows/local-compose-health.yml/badge.svg)

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

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost"]
      interval: 5s
      timeout: 2s
      retries: 10
```

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

### Example:

```yaml
- name: Validate docker services
  uses: ylazakovich/compose-health-check-action@v1
  with:
    compose-project-directory: "."
    compose-files: |
      docker-compose.yml
      docker-compose.override.yml
    services: "web db redis"
    timeout: "120"
```

---

## 💻 Local usage with act

Run the action locally with a modern GitHub Actions runner image:

```bash
act push \
  -W .github/workflows/local-compose-health.yml \
  -a linux/amd64 \
  -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest
```

Or execute the checker directly:

```bash
./docker_health_check.sh docker compose up -d web
```

---
