#!/usr/bin/env bats

load "helpers.bash"

@test "compose-failed: docker compose fails, diagnostics summary present" {
  # Workflow passes services: "empty" but compose file not found -> compose should fail.
  run_healthcheck_action_sh docker compose -f docker-compose-NOT-FOUND.yml up -d empty

  [ "$HC_RC" -ne 0 ]

  if [[ -n "${HC_JSON:-}" ]]; then
    assert_json '.overall.status == "compose_failed"'
  fi

  assert_stdout_contains "Diagnostics summary"
  assert_stdout_matches_regex '^  Platform:[[:space:]].+'
  assert_stdout_matches_regex '^  Global timeout:[[:space:]]*10s \(per service\)$'
  assert_stdout_contains "docker-compose-NOT-FOUND.yml"
  assert_stdout_contains "docker compose output (last 25 lines)"
  assert_stdout_contains "docker compose ls (all projects)"
  assert_stdout_contains "docker ps --all (global)"
  assert_stdout_contains "no such file or directory"
}
