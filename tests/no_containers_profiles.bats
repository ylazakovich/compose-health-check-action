#!/usr/bin/env bats

load '/usr/lib/bats-support/load'
load '/usr/lib/bats-assert/load'
load './helpers.bash'

@test "no_containers: profiled target service is not started and reported as no_containers (action fails)" {
  export DOCKER_HEALTH_TIMEOUT="20"
  export DOCKER_HEALTH_REPORT_FORMAT="json"

  # Target the profiled service, but do NOT enable the profile.
  export DOCKER_SERVICES_LIST="optional"

  run_healthcheck_action_sh docker compose -f docker/docker-compose.profiles.yml up -d --quiet-pull optional

  # The target service has no container -> must be treated as failure for the target
  assert_failure

  # Depending on implementation, overall status may be "failed" (healthcheck failure)
  # or "compose_failed" if compose refuses to start it. Accept both but require no_containers evidence.
  assert_json '(.overall.status == "failed") or (.overall.status == "compose_failed")'

  # If compose did run and action produced a report, we should see no_containers in summary and services.
  # (If compose failed hard before containers exist, services map might be empty; in that case compose_failed is enough.)
  if jq -e '.services' <<<"$HC_JSON" >/dev/null 2>&1; then
    assert_json '(.summary.no_containers >= 1) or (.services.optional == "no_containers")'
  fi
}
