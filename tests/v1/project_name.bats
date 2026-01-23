#!/usr/bin/env bats

load '../bats-support/load'
load '../bats-assert/load'
load '../helpers.bash'

@test "auto-apply project name from compose file directory" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_COMPOSE_FILES="docker/docker-compose.profiles.yml"
  export INPUT_COMPOSE_PROFILES="default extra"
  export INPUT_ADDITIONAL_COMPOSE_ARGS="--quiet-pull"
  export INPUT_AUTO_APPLY_PROJECT_NAME="true"

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"
  unset COMPOSE_PROJECT_NAME

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  run grep -E '^COMPOSE_PROJECT_NAME=docker$' "$INPUT_PROJECT_NAME_ENV_FILE"
  assert_success
}

@test "compose-project-name input is used when provided" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_COMPOSE_FILES="docker/docker-compose.profiles.yml"
  export INPUT_COMPOSE_PROFILES="default extra"
  export INPUT_ADDITIONAL_COMPOSE_ARGS="--quiet-pull"
  export INPUT_COMPOSE_PROJECT_NAME="explicitname"
  export INPUT_AUTO_APPLY_PROJECT_NAME="true"

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"
  unset COMPOSE_PROJECT_NAME

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  run grep -E '^COMPOSE_PROJECT_NAME=explicitname$' "$INPUT_PROJECT_NAME_ENV_FILE"
  assert_success
}
