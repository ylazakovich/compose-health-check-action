#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"

DOCKER_HEALTH_TIMEOUT="${DOCKER_HEALTH_TIMEOUT:-120}"
DOCKER_HEALTH_LOG_LINES="${DOCKER_HEALTH_LOG_LINES:-10}"

HOST_PLATFORM="$(docker info --format '{{.OSType}}/{{.Architecture}}' 2>/dev/null || true)"
if [[ -n "${HOST_PLATFORM}" ]]; then
  export DOCKER_DEFAULT_PLATFORM="${HOST_PLATFORM}"
fi

declare -a DOCKER_HEALTH_UNHEALTHY_TARGETS=()

docker_health_add_unhealthy_target() {
  local service="$1"
  local cid="$2"
  DOCKER_HEALTH_UNHEALTHY_TARGETS+=("${service}|${cid}")
}

print_command_pretty() {
  printf 'Running docker compose via docker_health_check.sh with command:\n  '
  local part
  for part in "$@"; do
    printf '%q ' "$part"
  done
  printf '\n'
}

wait_for_container_health() {
  local cid="$1"
  local timeout="${2:-$DOCKER_HEALTH_TIMEOUT}"

  local has_health
  has_health="$(docker inspect -f '{{if .State.Health}}yes{{end}}' "$cid" 2>/dev/null || true)"
  if [[ "$has_health" != "yes" ]]; then
    echo "NO_HEALTHCHECK"
    return 0
  fi

  local waited=0
  local interval=2
  while ((waited < timeout)); do
    local status
    status="$(docker inspect -f '{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "unknown")"
    case "$status" in
      healthy)
        echo "healthy"
        return 0
        ;;
      unhealthy)
        echo "unhealthy"
        return 0
        ;;
      starting | unknown)
        sleep "$interval"
        waited=$((waited + interval))
        ;;
      *)
        echo "$status"
        return 0
        ;;
    esac
  done

  local final
  final="$(docker inspect -f '{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "unknown")"
  echo "$final"
}

check_service_health() {
  local service="$1"
  local timeout="${2:-$DOCKER_HEALTH_TIMEOUT}"

  local failed=0
  local any=0
  local -a cids=()
  local waited_c=0
  local interval_c=2

  local -a project_filter=()
  if [[ -n "${COMPOSE_PROJECT_NAME:-}" ]]; then
    project_filter+=(--filter "label=com.docker.compose.project=${COMPOSE_PROJECT_NAME}")
  fi

  while :; do
    cids=()
    while IFS= read -r cid; do
      [[ -n "$cid" ]] && cids+=("$cid")
    done < <(docker ps --no-trunc -q \
      ${project_filter+"${project_filter[@]}"} \
      --filter "label=com.docker.compose.service=$service")

    ((${#cids[@]} > 0)) && break
    ((waited_c >= timeout)) && break
    sleep "$interval_c"
    waited_c=$((waited_c + interval_c))
  done

  local cid result
  for cid in "${cids[@]}"; do
    any=1
    result="$(wait_for_container_health "$cid" "$timeout")"

    if [[ "$result" == "NO_HEALTHCHECK" ]]; then
      warning "Healthcheck is not configured for service '$service' (container $cid)."
      continue
    fi

    if [[ "$result" == "healthy" ]]; then
      info "Service '$service' is healthy (container $cid)."
      continue
    fi

    if [[ "$result" == "starting" || "$result" == "unknown" ]]; then
      warning "Service '$service' did not reach 'healthy' in ${timeout}s (container $cid). State.Health.Status: $result"
      failed=1
      continue
    fi

    if [[ "$result" == "unhealthy" ]]; then
      warning "Service '$service' is unhealthy (container $cid)."
      docker_health_add_unhealthy_target "$service" "$cid"
      failed=1
    fi
  done

  if ((any == 0)); then
    warning "Service '$service' has no running containers yet; skipping healthcheck."
  fi

  ((failed != 0)) && return 1
  return 0
}

print_detected_services_table() {
  local all="$1"
  local up="$2"

  echo "──────────────────────────────────────────────"
  info "Detected services:"
  echo "──────────────────────────────────────────────"

  local idx=1 line maxlen=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    ((${#line} > maxlen)) && maxlen=${#line}
  done <<<"$(tr ' ' '\n' <<<"$all")"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local tag="[SKIP]"
    echo " $up " | grep -qw "$line" && tag="[UP]"
    printf "  %2d. %-*s  %s\n" "$idx" "$maxlen" "$line" "$tag"
    idx=$((idx + 1))
  done <<<"$(tr ' ' '\n' <<<"$all")"

  echo "──────────────────────────────────────────────"
  echo
}

print_unhealthy_services_details() {
  ((${#DOCKER_HEALTH_UNHEALTHY_TARGETS[@]} == 0)) && return 0

  echo
  echo "Unhealthy services:"
  local item svc cid

  for item in "${DOCKER_HEALTH_UNHEALTHY_TARGETS[@]}"; do
    IFS='|' read -r svc cid <<<"$item"
    echo "  - ${svc} (container ${cid})"

    if command -v jq >/dev/null 2>&1; then
      local health_json
      health_json="$(docker inspect --format='{{json .State.Health}}' "$cid" 2>/dev/null || echo '{}')"

      local status failing
      status="$(jq -r '.Status // "<none>"' <<<"$health_json")"
      failing="$(jq -r '.FailingStreak // 0' <<<"$health_json")"

      echo "    Health:         ${status}"
      echo "    Failing streak: ${failing}"
      echo "    Last probes:"

      jq -r '.Log // [] | (.[-5:] // .)[] | "      • ExitCode=\(.ExitCode)  \(.Output|tostring|gsub("\n$";""))"' \
        <<<"$health_json" || echo "      • <no entries>"
    else
      echo "    Health details (raw JSON):"
      docker inspect --format='{{json .State.Health}}' "$cid" | sed 's/^/      /'
    fi

    echo
    echo "    Last ${DOCKER_HEALTH_LOG_LINES} container log lines:"
    docker logs --tail "${DOCKER_HEALTH_LOG_LINES}" "$cid" 2>/dev/null | sed 's/^/      /' ||
      echo "      <failed to read logs>"
    echo
  done
}

execute() {
  if (("$#" == 0)); then
    error "Usage: $0 docker compose [args...]"
    exit 1
  fi

  local -a cmd_args=("$@")
  print_command_pretty "${cmd_args[@]}"

  local compose_rc=0 tmp_out
  tmp_out="$(mktemp)"

  if ! "${cmd_args[@]}" 2>&1 | tee "$tmp_out"; then
    compose_rc=${PIPESTATUS[0]:-1}

    error "Docker compose failed to start (exit $compose_rc)."

    echo
    echo "🔍  Diagnostics summary"
    echo "─────────────────────────────────────────────────────────────"
    printf '  Platform:              %s\n' "${DOCKER_DEFAULT_PLATFORM:-<unknown>}"
    printf '  Global timeout:        %ss (per service)\n' "$DOCKER_HEALTH_TIMEOUT"

    printf '  Compose command:\n'
    printf '      '
    for i in "${cmd_args[@]}"; do printf '%q ' "$i"; done
    echo

    echo
    info "--- docker compose output (last 25 lines) ---"
    echo "─────────────────────────────────────────────────────────────"

    tail -n 25 "$tmp_out" || true
    rm -f "$tmp_out"

    echo
    info "--- docker compose ps --all ---"
    echo "─────────────────────────────────────────────────────────────"
    docker compose ps --all 2>/dev/null || true
    echo

    info "--- docker compose ls (all projects) ---"
    echo "─────────────────────────────────────────────────────────────"
    docker compose ls 2>/dev/null || true
    echo

    info "--- docker ps --all (global) ---"
    echo "─────────────────────────────────────────────────────────────"
    docker ps --all --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' || true
    echo
    echo "─────────────────────────────────────────────────────────────"

    error "Some services failed to start (docker compose error)."
    exit 1
  fi

  rm -f "$tmp_out"

  local services="${SERVICES_LIST:-}"
  if [[ -z "$services" ]]; then
    services="$(docker compose config --services 2>/dev/null || true)"
  fi

  if [[ -z "$services" ]]; then
    error "Could not determine services from docker compose."

    echo
    echo "🔍  Diagnostics summary"
    echo "─────────────────────────────────────────────────────────────"
    printf 'COMPOSE_PROJECT_NAME=%s\n' "${COMPOSE_PROJECT_NAME:-<unset>}"
    printf 'COMPOSE_PROFILES=%s\n' "${COMPOSE_PROFILES:-<unset>}"

    echo
    info "--- docker compose ps --all ---"
    echo "─────────────────────────────────────────────────────────────"
    docker compose ps --all 2>/dev/null || true
    echo

    info "--- docker compose ls (all projects) ---"
    echo "─────────────────────────────────────────────────────────────"
    docker compose ls 2>/dev/null || true
    echo

    info "--- docker ps --all (global) ---"
    echo "─────────────────────────────────────────────────────────────"
    docker ps --all 2>/dev/null || true
    echo

    exit 1
  fi

  local up_services="$services"

  echo "Checking health status of services (running only)..."
  local svc
  local services_checked=0
  local healthy_count=0
  local unhealthy_count=0
  local no_hc_count=0
  local no_containers_count=0
  local health_failed=0

  while IFS= read -r svc; do
    [[ -z "$svc" ]] && continue
    services_checked=$((services_checked + 1))

    if ! check_service_health "$svc" "$DOCKER_HEALTH_TIMEOUT"; then
      health_failed=1
      unhealthy_count=$((unhealthy_count + 1))
    else
      healthy_count=$((healthy_count + 1))
    fi
  done <<<"$(tr ' ' '\n' <<<"$up_services")"

  echo
  echo "─────────────────────────────────────────────────────────────"
  info "Healthcheck summary"
  echo "─────────────────────────────────────────────────────────────"

  printf '  Platform:              %s\n' "${DOCKER_DEFAULT_PLATFORM:-<unknown>}"
  printf '  Global timeout:        %ss (per service)\n' "$DOCKER_HEALTH_TIMEOUT"

  printf '  Compose command:\n      '
  for i in "${cmd_args[@]}"; do printf '%q ' "$i"; done
  echo

  echo
  if ((health_failed == 0)); then
    echo "  Overall result:        OK (all services healthy)"
  else
    echo "  Overall result:        FAILED (unhealthy services detected)"
  fi

  printf '  Services checked:      %d\n' "$services_checked"
  printf '  Healthy:               %d\n' "$healthy_count"
  printf '  Unhealthy:             %d\n' "$unhealthy_count"
  printf '  Without healthcheck:   %d\n' "$no_hc_count"
  printf '  No containers:         %d\n' "$no_containers_count"
  echo

  if ((health_failed != 0)); then
    print_unhealthy_services_details
  fi

  print_detected_services_table "$services" "$up_services"

  if ((health_failed != 0)); then
    error "Some services failed healthcheck."
    exit 1
  fi

  echo "Application started successfully!"
}

execute "$@"
