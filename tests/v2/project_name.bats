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

@test "auto-apply false does not write project name (docker-command)" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.profiles.yml --profile default --profile extra up -d"
  export INPUT_AUTO_APPLY_PROJECT_NAME="false"

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"
  unset COMPOSE_PROJECT_NAME

  run_healthcheck_action_inputs

  assert_success
  [[ ! -f "$INPUT_PROJECT_NAME_ENV_FILE" ]]
}

@test "fallback prefers compose-project-name when no containers (docker-command)" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.profiles.yml --profile default --profile extra up -d --scale web=0 --scale worker=0 --scale sidecar=0 web"
  export INPUT_TIMEOUT="0"
  export INPUT_COMPOSE_PROJECT_NAME="explicitname"
  export INPUT_AUTO_APPLY_PROJECT_NAME="true"
  export COMPOSE_PROJECT_NAME="envname"

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"

  run_healthcheck_action_inputs

  assert_failure
  run grep -E '^COMPOSE_PROJECT_NAME=explicitname$' "$INPUT_PROJECT_NAME_ENV_FILE"
  assert_success
}

@test "fallback uses COMPOSE_PROJECT_NAME when no containers and no input (docker-command)" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.profiles.yml --profile default --profile extra up -d --scale web=0 --scale worker=0 --scale sidecar=0 web"
  export INPUT_TIMEOUT="0"
  export INPUT_AUTO_APPLY_PROJECT_NAME="true"
  export COMPOSE_PROJECT_NAME="envname"
  unset INPUT_COMPOSE_PROJECT_NAME

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"

  run_healthcheck_action_inputs

  assert_failure
  run grep -E '^COMPOSE_PROJECT_NAME=envname$' "$INPUT_PROJECT_NAME_ENV_FILE"
  assert_success
}

@test "fallback uses repo basename when no containers and no explicit names (docker-command)" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.profiles.yml --profile default --profile extra up -d --scale web=0 --scale worker=0 --scale sidecar=0 web"
  export INPUT_TIMEOUT="0"
  export INPUT_AUTO_APPLY_PROJECT_NAME="true"
  unset INPUT_COMPOSE_PROJECT_NAME
  unset COMPOSE_PROJECT_NAME

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"

  run_healthcheck_action_inputs

  assert_failure
  expected_repo="$(basename "$HC_REPO_ROOT")"
  run grep -E "^COMPOSE_PROJECT_NAME=${expected_repo}$" "$INPUT_PROJECT_NAME_ENV_FILE"
  assert_success
}
