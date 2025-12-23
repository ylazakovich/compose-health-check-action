## v1.0.3 [\*](https://github.com/ylazakovich/compose-health-check-action/pull/23) (23.12.2025)

- Added JSON report generation mechanism with configurable output format (text, json, or both)
- Introduced `report-format` input and `report_json_b64` output for machine-readable health check reports
- Enhanced summary statistics with aggregated counters across all service states

## v1.0.2 [\*](https://github.com/ylazakovich/compose-health-check-action/pull/18) (22.12.2025)

- Added support for one-shot containers with `depends_on` relations by detecting exit codes
- Improved service status detection to include stopped containers and categorize states (HEALTHY, COMPLETED, UNHEALTHY, FAILED, UP, NO_CONTAINERS)
- Enhanced summary statistics to reflect actual runtime states across all services

## v1.0.1 (23.11.2025)

- patch: resolve issue with additional-compose-args (#17)

## v0.1.1 (23.11.2025)

**Bugfix & Stability Release**

This release significantly improves the reliability and consistency of the action in real CI environments, especially when using multi-file Docker Compose setups and nested directory structures.

### 🚀 Improved

- Enhanced compatibility between GitHub Runners and Docker Compose.
- Removed the `--project-directory` flag to prevent incorrect path resolution on GitHub Actions.
- Ensured consistent behavior both locally (`act`) and on GitHub-hosted runners.
- The `docker compose config --services` command is now executed with the same `-f ...` flags as the main `docker compose` invocation, providing accurate service detection.
- Improved the **Detected services** section — all services from the compose configuration are now listed correctly.
- Increased stability of the healthcheck cycle for large multi-service Docker Compose stacks.

### 🐛 Fixed

- Fixed an issue where the “Detected services” table appeared empty in external projects.
- Corrected the working directory resolution inside GitHub Action runs.
- Eliminated GitHub Actions warnings:  
  _“Unexpected input(s) … valid inputs are …”_  
  caused by legacy internal action paths in CI tests.
- Internal CI now properly uses the root-level `action.yml` instead of the legacy subdirectory version.
- Resolved issues that appeared after moving `action.yml` to the repository root.

### 🔧 Internal

- Refactored `docker_health_check.sh`:
  - improved construction of the main compose command,
  - unified behavior between local shells and GitHub Runners,
  - added groundwork for future support of job-like services (`exited 0` behavior).

---

## v0.1.0 — Pre-release for internal testing (23.11.2025)

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
