#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"

DOCKER_HEALTH_TIMEOUT="${DOCKER_HEALTH_TIMEOUT:-120}"
DOCKER_HEALTH_LOG_LINES="${DOCKER_HEALTH_LOG_LINES:-25}"

HOST_PLATFORM="$(docker info --format '{{.OSType}}/{{.Architecture}}' 2>/dev/null || true)"
if [[ -n "${HOST_PLATFORM}" ]]; then
  export DOCKER_DEFAULT_PLATFORM="${HOST_PLATFORM}"
fi

declare -a DOCKER_HEALTH_UNHEALTHY_TARGETS=()

services_checked=0
healthy_count=0
unhealthy_count=0
no_hc_count=0
no_containers_count=0

docker_health_add_unhealthy_target() {
  local service="$1"
  local cid="$2"
  DOCKER_HEALTH_UNHEALTHY_TARGETS+=("${service}|${cid}")
}

wait_for_container_health() {
  local cid="$1"
  local timeout="${2:-$DOCKER_HEALTH_TIMEOUT}"

  local state_status exit_code
  state_status="$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || echo "unknown")"
  if [[ "$state_status" == "exited" || "$state_status" == "dead" ]]; then
    exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$cid" 2>/dev/null || echo "1")"
    if [[ "$exit_code" == "0" ]]; then
      echo "exited_0"
    else
      echo "exited_${exit_code}"
    fi
    return 0
  fi

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

  local svc_has_containers=0
  local svc_healthy=0
  local svc_unhealthy=0
  local svc_no_hc=0

  local failed=0

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
    done < <(docker ps --all --no-trunc -q \
      ${project_filter+"${project_filter[@]}"} \
      --filter "label=com.docker.compose.service=$service")

    if ((${#cids[@]} > 0)); then
      svc_has_containers=1
      break
    fi

    ((waited_c >= timeout)) && break
    sleep "$interval_c"
    waited_c=$((waited_c + interval_c))
  done

  if ((svc_has_containers == 0)); then
    warning "Service '$service' has no containers (running or stopped); marking as 'No containers'."
    ((no_containers_count++))
    ((services_checked++))
    return 1
  fi

  local cid result
  for cid in "${cids[@]}"; do
    [[ -n "$cid" ]] || continue

    result="$(wait_for_container_health "$cid" "$timeout")"

    case "$result" in
      healthy)

        svc_healthy=1
        ;;
      exited_0)
        # One-shot container finished successfully. Treat as success, but not 'healthy'.
        svc_no_hc=1
        ;;
      exited_*)
        svc_unhealthy=1
        failed=1
        docker_health_add_unhealthy_target "$service" "$cid"
        ;;
      unhealthy)
        svc_unhealthy=1
        failed=1
        docker_health_add_unhealthy_target "$service" "$cid"
        ;;
      NO_HEALTHCHECK)
        svc_no_hc=1
        ;;
      starting | unknown)
        warning "Service '$service' did not reach 'healthy' in ${timeout}s (container $cid). State.Health.Status: $result"
        svc_unhealthy=1
        failed=1
        docker_health_add_unhealthy_target "$service" "$cid"
        ;;
      *)
        warning "Unknown health status '$result' for container $cid"
        svc_unhealthy=1
        failed=1
        docker_health_add_unhealthy_target "$service" "$cid"
        ;;
    esac
  done

  ((services_checked++))

  if ((svc_unhealthy == 1)); then
    ((unhealthy_count++))
    error "Service '$service' healthcheck failed!!!"
  elif ((svc_healthy == 1 && svc_no_hc == 0)); then
    ((healthy_count++))
    info "Service '$service' is healthy."
  elif ((svc_healthy == 0 && svc_unhealthy == 0 && svc_no_hc == 1)); then
    ((no_hc_count++))
    warning "Service '$service' has containers but no healthcheck configured."
  fi

  if ((failed != 0)); then
    return 1
  fi

  return 0
}

get_service_runtime_tag() {
  local service="$1"

  local -a project_filter=()
  if [[ -n "${COMPOSE_PROJECT_NAME:-}" ]]; then
    project_filter+=(--filter "label=com.docker.compose.project=${COMPOSE_PROJECT_NAME}")
  fi

  local -a cids=()
  while IFS= read -r cid; do
    [[ -n "$cid" ]] && cids+=("$cid")
  done < <(docker ps --all --no-trunc -q \
      ${project_filter+"${project_filter[@]}"} \
      --filter "label=com.docker.compose.service=$service")

  if ((${#cids[@]} == 0)); then
    echo "NO_CONTAINERS"
    return 0
  fi

  local any_running=0 any_healthy=0 any_unhealthy=0 any_completed=0 any_failed=0 any_starting=0

  local cid state health exit_code
  for cid in "${cids[@]}"; do
    state="$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || echo "unknown")"

    if [[ "$state" == "exited" || "$state" == "dead" ]]; then
      exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$cid" 2>/dev/null || echo "1")"
      if [[ "$exit_code" == "0" ]]; then
        any_completed=1
      else
        any_failed=1
      fi
      continue
    fi

    if [[ "$state" == "running" ]]; then
      any_running=1
      health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$cid" 2>/dev/null || echo "")"
      case "$health" in
        healthy) any_healthy=1 ;;
        unhealthy) any_unhealthy=1 ;;
        starting) any_starting=1 ;;
        "") : ;;
        *) any_starting=1 ;;
      esac
    else
      any_starting=1
    fi
  done

  if ((any_failed == 1)); then
    echo "FAILED"
  elif ((any_unhealthy == 1)); then
    echo "UNHEALTHY"
  elif ((any_healthy == 1)); then
    echo "HEALTHY"
  elif ((any_running == 1)); then
    # running but no healthcheck (or still starting)
    echo "UP"
  elif ((any_completed == 1)); then
    echo "COMPLETED"
  else
    echo "UP"
  fi
}

print_detected_services_table() {
  local all="$1"
  local up="$2"

  printf '──────────────────────────────────────────────
'
  info "Detected services:"
  printf '──────────────────────────────────────────────
'

  local idx=1 line maxlen=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    ((${#line} > maxlen)) && maxlen=${#line}
  done <<<"$(tr ' ' '
' <<<"$all")"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local runtime tag extra=""
    runtime="$(get_service_runtime_tag "$line")"

    extra=""

    case "$runtime" in
      HEALTHY) tag="[HEALTHY]" ;;
      COMPLETED) tag="[COMPLETED]" ;;
      UNHEALTHY) tag="[UNHEALTHY]" ;;
      FAILED) tag="[FAILED]" ;;
      NO_CONTAINERS) tag="[SKIP]" ;;
      UP) tag="[UP]" ;;
      *) tag="[UP]" ;;
    esac

    printf "  %2d. %-*s  %s%s
" "$idx" "$maxlen" "$line" "$tag" "$extra"
    idx=$((idx + 1))
  done <<<"$(tr ' ' '
' <<<"$all")"

  printf '──────────────────────────────────────────────

'
}


print_unhealthy_services_details() {
  ((${#DOCKER_HEALTH_UNHEALTHY_TARGETS[@]} == 0)) && return 0

  echo
  echo "Unhealthy services:"
  local item svc cid status raw_json line

  for item in "${DOCKER_HEALTH_UNHEALTHY_TARGETS[@]}"; do
    svc="${item%%|*}"
    cid="${item#*|}"

    status="$(docker inspect -f '{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "unknown")"

    echo "  - $svc (container $cid)"
    echo "    Health status: $status"

    # If the container has no health status (e.g., one-shot), show its lifecycle state/exit code.
    local state exit_code
    state="$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || echo "unknown")"
    if [[ "$state" == "exited" || "$state" == "dead" ]]; then
      exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$cid" 2>/dev/null || echo "unknown")"
      echo "    Container state: $state (exit code: $exit_code)"
    fi

    raw_json="$(docker inspect -f '{{json .State.Health.Log}}' "$cid" 2>/dev/null || echo '[]')"

    echo "    Last ${DOCKER_HEALTH_LOG_LINES} health probe outputs:"
    if command -v jq >/dev/null 2>&1; then
      echo "$raw_json" \
        | jq -r '.[-'"$DOCKER_HEALTH_LOG_LINES"':] | .[].Output' \
        | while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            printf '      %s\n' "$line"
          done
    else
      echo "$raw_json" \
        | sed -n 's/.*"Output":[[:space:]]*"\(.*\)".*/\1/p' \
        | tail -n "$DOCKER_HEALTH_LOG_LINES" \
        | while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            printf '      %s\n' "$line"
          done
    fi

    echo
    echo "    Last ${DOCKER_HEALTH_LOG_LINES} container log lines:"
    docker logs --tail "$DOCKER_HEALTH_LOG_LINES" "$cid" 2>&1 \
      | while IFS= read -r line; do
          printf '      %s\n' "$line"
        done
    echo
  done
}

execute() {
  if (($# == 0)); then
    echo "Usage: $0 docker compose [args...]"
    exit 1
  fi

  local -a cmd_args=("$@")

  local -a services_from_cmd=()
  local i token
  local up_index=-1

  for ((i = 0; i < ${#cmd_args[@]}; i++)); do
    if [[ "${cmd_args[i]}" == "up" ]]; then
      up_index=$i
      break
    fi
  done

  if ((up_index >= 0)); then
    for ((i = up_index + 1; i < ${#cmd_args[@]}; i++)); do
      token="${cmd_args[i]}"
      [[ "$token" == "--" ]] && break
      if [[ "$token" == -* ]]; then
        continue
      fi
      services_from_cmd+=("$token")
    done
  fi

  if ((${#services_from_cmd[@]} > 0)); then
    DOCKER_SERVICES_LIST="${services_from_cmd[*]}"
  else
    if [[ -z "${DOCKER_SERVICES_LIST:-}" ]]; then
      error "No services specified. Either:
    - pass services in docker compose command, e.g. 'docker compose up -d web api'
    - or set DOCKER_SERVICES_LIST environment variable (space-separated list of services)."
      exit 1
    fi
  fi
  read -r -a services_to_check <<<"${DOCKER_SERVICES_LIST:-}"

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

  local -a cfg_cmd=("docker" "compose")
  local j

  for ((j = 2; j < ${#cmd_args[@]}; j++)); do
    if [[ "${cmd_args[j]}" == "up" ]]; then
      break
    fi
    cfg_cmd+=("${cmd_args[j]}")
  done

  cfg_cmd+=(config --services)

  local all_services
  all_services="$("${cfg_cmd[@]}" 2>/dev/null || true)"

  echo "Checking health status of services (running only)..."
  local svc
  local health_failed=0

  for svc in "${services_to_check[@]}"; do
    [[ -n "$svc" ]] || continue
    if ! check_service_health "$svc" "$DOCKER_HEALTH_TIMEOUT"; then
      health_failed=1
    fi
  done

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

  # Aggregate summary by factual runtime status across *all* services from compose config.
  # This is aligned with the "Detected services" table.
  local sum_healthy=0 sum_completed=0 sum_unhealthy=0 sum_no_hc=0 sum_no_containers=0
  local s runtime
  while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    runtime="$(get_service_runtime_tag "$s")"
    case "$runtime" in
      HEALTHY) ((++sum_healthy)) ;;
      COMPLETED) ((++sum_completed)) ;;
      UNHEALTHY|FAILED) ((++sum_unhealthy)) ;;
      NO_CONTAINERS) ((++sum_no_containers)) ;;
      UP|*) ((++sum_no_hc)) ;;
    esac
  done <<<"$all_services"

  printf '  Healthy:               %d\n' "$sum_healthy"
  printf '  Completed:             %d\n' "$sum_completed"
  printf '  Unhealthy:             %d\n' "$sum_unhealthy"
  printf '  Without healthcheck:   %d\n' "$sum_no_hc"
  printf '  No containers:         %d\n' "$sum_no_containers"
  echo

  if ((health_failed != 0)); then
    print_unhealthy_services_details
  fi

  print_detected_services_table "$all_services" "${DOCKER_SERVICES_LIST:-}"

  if ((health_failed != 0)); then
    error "Some services failed healthcheck."
    exit 1
  fi

  echo "Application started successfully!"
}

execute "$@"
