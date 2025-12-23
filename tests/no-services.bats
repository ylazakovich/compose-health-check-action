#!/usr/bin/env bats

load "helpers.bash"

@test "no-services: fails with guidance message" {
  # This workflow passes services: "" and a NOT FOUND compose file.
  # Your action is expected to fail with the 'No services specified...' guidance text.
  run_healthcheck_action_sh docker compose -f docker-compose-NOT-FOUND.yml up -d

  [ "$HC_RC" -ne 0 ]

  # If your JSON report is produced for this path, assert it;
  # otherwise keep text assertion only.
  if [[ -n "${HC_JSON:-}" ]]; then
    assert_json '.overall.status == "no_services"'
  fi

  assert_stdout_contains "No services specified. Either:"
  assert_stdout_contains "pass services in docker compose command"
  assert_stdout_contains "or set DOCKER_SERVICES_LIST environment variable"
}
