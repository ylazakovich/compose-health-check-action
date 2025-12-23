#!/usr/bin/env bats

load "helpers.bash"

@test "unhealthy: overall failed, slow-broken unhealthy, diagnostics present" {
  # Equivalent to workflow:
  # docker compose -f docker-compose.yml up -d slow-broken
  run_healthcheck_action_sh docker compose -f docker-compose.yml up -d slow-broken

  # Workflow uses continue-on-error: true -> here we explicitly expect failure
  [ "$HC_RC" -ne 0 ]

  # JSON assertions
  assert_json '.overall.status == "failed"'
  assert_json '.services["slow-broken"] == "unhealthy"'

  # Diagnostics assertions (still from text, until you add diagnostics into JSON)
  assert_stdout_contains "Last 25 health probe outputs"
  assert_stdout_contains "connect to remote host: Connection refused"
  assert_stdout_contains "Last 25 container log lines"
  assert_stdout_contains "Starting slow service..."
}
