#!/usr/bin/env bats

load "helpers.bash"

@test "healthy: overall ok, web healthy, expected summary counters" {
  # Equivalent to workflow:
  # docker compose -f docker-compose.yml up -d --quiet-pull web
  run_healthcheck_action_sh docker compose -f docker-compose.yml up -d --quiet-pull web

  # Expect action success (workflow doesn't use continue-on-error here)
  [ "$HC_RC" -eq 0 ]

  # JSON assertions (stable)
  assert_json '.overall.status == "ok"'
  assert_json '.summary.unhealthy == 0'
  assert_json '.services.web == "healthy"'

  # Keep a couple of human-readable checks if you still want them
  assert_stdout_matches_regex '^  Overall result:[[:space:]]*OK'
  assert_stdout_matches_regex '^  Global timeout:[[:space:]]*60s \(per service\)$'
}
