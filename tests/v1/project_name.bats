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
  export HC_SKIP_PROJECT_INJECT="1"

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
  export HC_SKIP_PROJECT_INJECT="1"

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"
  unset COMPOSE_PROJECT_NAME

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  run grep -E '^COMPOSE_PROJECT_NAME=explicitname$' "$INPUT_PROJECT_NAME_ENV_FILE"
  assert_success
}

@test "auto-apply false does not write project name" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_COMPOSE_FILES="docker/docker-compose.profiles.yml"
  export INPUT_COMPOSE_PROFILES="default extra"
  export INPUT_ADDITIONAL_COMPOSE_ARGS="--quiet-pull"
  export INPUT_AUTO_APPLY_PROJECT_NAME="false"
  export HC_SKIP_PROJECT_INJECT="1"

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"
  unset COMPOSE_PROJECT_NAME

  run_healthcheck_action_inputs

  assert_success
  [[ ! -f "$INPUT_PROJECT_NAME_ENV_FILE" ]]
}

@test "fallback prefers compose-project-name when no containers" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_COMPOSE_FILES="docker/docker-compose.profiles.yml"
  export INPUT_COMPOSE_PROFILES="default extra"
  export INPUT_ADDITIONAL_COMPOSE_ARGS="--scale web=0 --scale worker=0 --scale sidecar=0"
  export INPUT_TIMEOUT="0"
  export INPUT_COMPOSE_SERVICES="web"
  export INPUT_COMPOSE_PROJECT_NAME="explicitname"
  export INPUT_AUTO_APPLY_PROJECT_NAME="true"
  export COMPOSE_PROJECT_NAME="envname"
  export HC_SKIP_PROJECT_INJECT="1"

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"

  run_healthcheck_action_inputs

  assert_failure
  run grep -E '^COMPOSE_PROJECT_NAME=explicitname$' "$INPUT_PROJECT_NAME_ENV_FILE"
  assert_success
}

@test "fallback uses COMPOSE_PROJECT_NAME when no containers and no input" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_COMPOSE_FILES="docker/docker-compose.profiles.yml"
  export INPUT_COMPOSE_PROFILES="default extra"
  export INPUT_ADDITIONAL_COMPOSE_ARGS="--scale web=0 --scale worker=0 --scale sidecar=0"
  export INPUT_TIMEOUT="0"
  export INPUT_COMPOSE_SERVICES="web"
  export INPUT_AUTO_APPLY_PROJECT_NAME="true"
  export COMPOSE_PROJECT_NAME="envname"
  export HC_SKIP_PROJECT_INJECT="1"
  unset INPUT_COMPOSE_PROJECT_NAME

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"

  run_healthcheck_action_inputs

  assert_failure
  run grep -E '^COMPOSE_PROJECT_NAME=envname$' "$INPUT_PROJECT_NAME_ENV_FILE"
  assert_success
}

@test "fallback uses repo basename when no containers and no explicit names" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_COMPOSE_FILES="docker/docker-compose.profiles.yml"
  export INPUT_COMPOSE_PROFILES="default extra"
  export INPUT_ADDITIONAL_COMPOSE_ARGS="--scale web=0 --scale worker=0 --scale sidecar=0"
  export INPUT_TIMEOUT="0"
  export INPUT_COMPOSE_SERVICES="web"
  export INPUT_AUTO_APPLY_PROJECT_NAME="true"
  export GITHUB_REPOSITORY="ylazakovich/compose-health-check-action"
  export HC_SKIP_PROJECT_INJECT="1"
  unset INPUT_COMPOSE_PROJECT_NAME
  unset COMPOSE_PROJECT_NAME

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"

  run_healthcheck_action_inputs

  assert_failure
  expected_repo="compose-health-check-action"
  expected_alt="$(basename "$HC_REPO_ROOT")"
  run grep -E "^COMPOSE_PROJECT_NAME=(${expected_repo}|${expected_alt})$" "$INPUT_PROJECT_NAME_ENV_FILE"
  assert_success
}

@test "auto-apply uses compose file name field" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_COMPOSE_FILES="docker/docker-compose.named.yml"
  export INPUT_AUTO_APPLY_PROJECT_NAME="true"
  export HC_SKIP_PROJECT_INJECT="1"

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"
  unset COMPOSE_PROJECT_NAME
  unset INPUT_COMPOSE_PROJECT_NAME

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  run grep -E '^COMPOSE_PROJECT_NAME=customproject$' "$INPUT_PROJECT_NAME_ENV_FILE"
  assert_success
}

@test "auto-apply false does not write explicit compose-project-name" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_COMPOSE_FILES="docker/docker-compose.named.yml"
  export INPUT_COMPOSE_PROJECT_NAME="explicitname"
  export INPUT_AUTO_APPLY_PROJECT_NAME="false"
  export HC_SKIP_PROJECT_INJECT="1"

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"
  unset COMPOSE_PROJECT_NAME

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  [[ ! -f "$INPUT_PROJECT_NAME_ENV_FILE" ]]
}

@test "auto-apply false does not write COMPOSE_PROJECT_NAME env" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_COMPOSE_FILES="docker/docker-compose.named.yml"
  export INPUT_AUTO_APPLY_PROJECT_NAME="false"
  export COMPOSE_PROJECT_NAME="envname"
  export HC_SKIP_PROJECT_INJECT="1"

  tmpdir="$(mktemp -d)"
  export INPUT_PROJECT_NAME_ENV_FILE="${tmpdir}/system.env"
  unset INPUT_COMPOSE_PROJECT_NAME

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  [[ ! -f "$INPUT_PROJECT_NAME_ENV_FILE" ]]
}
