# 🐳 Compose Health Check Action

> Fail your CI early if Docker Compose services are not healthy.

✅ Runs Docker Compose  
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
| One-shot service failed    | ❌ Fail |
| No healthcheck defined     | ⚠️ Skip |
| Docker Compose error       | ❌ Fail |

---

## ⚙️ Configuration

| Input           | Required | Description                                  |
| --------------- | -------- | -------------------------------------------- |
| `compose-files` | yes      | One or more docker-compose files             |
| `services`      | no       | Services to check (default: all)             |
| `timeout`       | no       | Timeout per service in seconds (default: 60) |

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
Service 'web' is healthy.

Overall result: OK
Healthy: 1
Unhealthy: 0

Application started successfully!
```

</details>

<details>
<summary>🔴 Unhealthy service</summary>

```text
Overall result: FAILED
Unhealthy services:
  - slow-broken (Health=unhealthy)

Last health logs:
  Connection refused
```

</details>

<details>
<summary>⚠️ No services specified</summary>

```text
No services specified.
Pass services explicitly or via DOCKER_SERVICES_LIST.
```

</details>

<details>
<summary>❌ Docker Compose failed</summary>

```text
docker compose up failed:
docker-compose-NOT-FOUND.yml: no such file
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
act push   --rm   -W .github/workflows/healthy.yml   -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest
```

Or execute directly:

```bash
./action.sh docker compose up -d web
```

---

## 🤝 Contributing

Issues and pull requests are welcome.  
Tests are written using **bats**.

---

## 📄 License

MIT
