# 🐳 Compose Health Check Action

> Fail your CI early if Docker Compose services are not healthy.

✅ Runs Docker Compose  
✅ Autodetection host platform  
✅ Waits for container healthchecks  
✅ Fails on unhealthy or broken services  
✅ Shows clear diagnostics on error

![GitHub release (latest by date)](https://img.shields.io/github/v/release/ylazakovich/compose-health-check-action)
![Docker Compose](https://img.shields.io/badge/Docker-Compose-blue?logo=docker&logoColor=white)
![Bats tests](https://img.shields.io/endpoint?url=https://ylazakovich.github.io/compose-health-check-action/tests.json)

---

## ⚡ Quick start

```yaml
- uses: ylazakovich/compose-health-check-action@v1
  with:
    compose-files: docker-compose.yml
    services: service_1, service_2 ...
```

That’s it.  
If any service becomes unhealthy — **your workflow fails**.

---

## 📦 What this action does

```text
docker compose up
        ↓
wait for healthchecks
        ↓
validate exit codes
        ↓
pass or fail CI
```

| Scenario                   | Result  |
| -------------------------- | ------- |
| All services healthy       | ✅ Pass |
| Unhealthy service detected | ❌ Fail |
| Docker Compose error       | ❌ Fail |
| No healthcheck defined     | ⚠️ Skip |

---

## ⚙️ Configuration

| Input                     | Required | Description                                                           |
| ------------------------- | -------- | --------------------------------------------------------------------- |
| `compose-files`           | no       | One or more docker-compose files (default: `docker-compose.yml`)      |
| `services`                | no       | Services to check (default: all)                                      |
| `timeout`                 | no       | Timeout per service in seconds (default: 120)                         |
| `additional-compose-args` | no       | Additional args for docker compose (e.g. `--quiet-pull` or `--build`) |
| `report-format`           | no       | Healthcheck report format: `text`/`json`/`both` (default: `text`)     |

Example:

```yaml
- uses: ylazakovich/compose-health-check-action@v1
  with:
    compose-files: |
      docker-compose.yml
      docker-compose.override.yml
    services: web api
    timeout: 60
```

---

## 🧪 Examples

<details>
<summary>🟢 Healthy services</summary>

```text
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

</details>

<details>
<summary>🔴 Unhealthy service</summary>

```text
Checking health status of services (running only)...
❌ Service 'slow-broken' healthcheck failed!!!

─────────────────────────────────────────────────────────────
ℹ️  Healthcheck summary
─────────────────────────────────────────────────────────────
  Platform:              linux/x86_64
  Global timeout:        10s (per service)
  Compose command:
      docker compose -f docker-compose.yml up -d slow-broken

  Overall result:        FAILED (unhealthy services detected)
  Healthy:               0
  Completed:             0
  Unhealthy:             1
  Without healthcheck:   0
  No containers:         1


Unhealthy services:
  - slow-broken (container aa1868534bad490b4695d1e5235a187bafd23ae07653db56c1d8bb8f69f6b072)
    Health status: unhealthy
    Last 25 health probe outputs:
      wget: can't connect to remote host: Connection refused
      wget: can't connect to remote host: Connection refused
      wget: can't connect to remote host: Connection refused
      wget: can't connect to remote host: Connection refused
      wget: can't connect to remote host: Connection refused

    Last 25 container log lines:
      Starting slow service...

──────────────────────────────────────────────
ℹ️  Detected services:
──────────────────────────────────────────────
   1. slow-broken  [UNHEALTHY]
   2. web          [SKIP]
──────────────────────────────────────────────

❌ Some services failed healthcheck.
```

</details>

<details>
<summary>⚠️ No services specified</summary>

```text
❌ No services specified. Either:
    - pass services in docker compose command, e.g. 'docker compose up -d web api'
    - or set DOCKER_SERVICES_LIST environment variable (space-separated list of services).
Error: Process completed with exit code 1.
```

</details>

<details>
<summary>❌ Docker Compose failed</summary>

```text
❌ Docker compose failed to start (exit 1).

🔍  Diagnostics summary
─────────────────────────────────────────────────────────────
  Platform:              linux/x86_64
  Global timeout:        10s (per service)
  Compose command:
      docker compose -f docker-compose-NOT-FOUND.yml up -d empty

ℹ️  --- docker compose output (last 25 lines) ---
─────────────────────────────────────────────────────────────
open /home/runner/work/compose-health-check-action/compose-health-check-action/docker-compose-NOT-FOUND.yml: no such file or directory

ℹ️  --- docker compose ps --all ---
─────────────────────────────────────────────────────────────
NAME      IMAGE     COMMAND   SERVICE   CREATED   STATUS    PORTS

ℹ️  --- docker compose ls (all projects) ---
─────────────────────────────────────────────────────────────
NAME                STATUS              CONFIG FILES

ℹ️  --- docker ps --all (global) ---
─────────────────────────────────────────────────────────────
NAMES     STATUS    IMAGE

─────────────────────────────────────────────────────────────
❌ Some services failed to start (docker compose error).
```

</details>

---

## 🧠 Healthcheck logic

- Only **running containers** are checked
- Services without `healthcheck` → **SKIP**
- One-shot containers → validated by **exit code**
- First failure → workflow **fails immediately**

---

## 💻 Local usage with act

```bash
act push   --rm   -W .github/workflows/bats.yml   -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest
```

Or execute directly:

```bash
./action.sh docker compose up -f docker/docker-compose.healthy.yml -d web
```

---

## 🤝 Contributing

Issues and pull requests are welcome.  
Tests are written using **bats**.

---

## 📄 License

MIT
