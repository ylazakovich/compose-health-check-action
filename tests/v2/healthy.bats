#!/usr/bin/env bats

load '../bats-support/load'
load '../bats-assert/load'
load '../helpers.bash'

@test "docker-command: services taken from command" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.healthy.yml up -d --quiet-pull web"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
  assert_json '.summary.unhealthy == 0'
}

@test "docker-command: supports quoted compose file path" {
  export INPUT_REPORT_FORMAT="json"
  unset INPUT_SERVICES

  local repo_root tmp_dir compose_path
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  tmp_dir="${BATS_TEST_TMPDIR}/project dir"
  mkdir -p "$tmp_dir"
  compose_path="${tmp_dir}/compose file.yml"
  cp "$repo_root/docker/docker-compose.healthy.yml" "$compose_path"

  export INPUT_DOCKER_COMMAND="docker compose -f \"${compose_path}\" up -d --quiet-pull web"

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
  assert_json '.summary.unhealthy == 0'
}

@test "docker-command: uses all services when not provided" {
  export INPUT_REPORT_FORMAT="json"
  export INPUT_DOCKER_COMMAND="docker compose -f docker/docker-compose.healthy.yml up -d --quiet-pull"
  unset INPUT_SERVICES

  run_healthcheck_action_inputs

  assert_success
  assert_json '.overall.status == "ok"'
  assert_json '.services.web == "healthy"'
  assert_json '.summary.unhealthy == 0'
}
