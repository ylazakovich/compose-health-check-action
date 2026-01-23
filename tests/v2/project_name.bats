#!/usr/bin/env bats

load '../bats-support/load'
load '../bats-assert/load'
load '../helpers.bash'

@test "auto-apply uses -p from docker-command" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.profiles.yml -p shortproj up -d"
  export INPUT_AUTO_APPLY_PROJECT_NAME="true"

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"
  unset COMPOSE_PROJECT_NAME

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  run grep -E '^COMPOSE_PROJECT_NAME=shortproj$' "$INPUT_PROJECT_NAME_ENV_FILE"
  assert_success
}
