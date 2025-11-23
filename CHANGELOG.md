## v1.0.0 - Release

## v0.1.0 — Pre-release for internal testing

This is the first pre-release of the Compose Health Check Action.

The purpose of this version is to validate functionality in real CI/CD pipelines before publishing the stable `v1.0.0` release and submitting the action to GitHub Marketplace.

### Features included in this pre-release:

- Automatic health checks for specified Docker Compose services
- Support for multiple compose files
- Configurable timeout
- Workflow failure if services do not reach a healthy state
- Simple and reproducible usage within GitHub Actions

### Example usage:

```yaml
- name: Run healthcheck
  uses: ylazakovich/compose-health-check-action@v0.1.0
  with:
    compose-files: |
      docker-compose.yml
    services: "web"
    timeout: "60"
```
