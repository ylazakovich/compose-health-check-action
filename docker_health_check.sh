#!/usr/bin/env bash
set -euo pipefail

############################################
# CONFIG
############################################

DOCKER_HEALTH_TIMEOUT="${DOCKER_HEALTH_TIMEOUT:-120}"
COMPOSE_BIN="${COMPOSE_BIN:-docker compose}"

############################################
# LOGGING
############################################

info()  { echo -e "\033[1;36mℹ $*\033[0m"; }
ok()    { echo -e "\033[1;32m✔ $*\033[0m"; }
warn()  { echo -e "\033[1;33m⚠ $*\033[0m"; }
fail()  { echo -e "\033[1;31m✖ $*\033[0m"; }

############################################
# STATE
############################################

declare -A SERVICE_STATUS          # healthy | completed | up | unhealthy | failed | no_containers
declare -A SERVICE_IS_TARGET       # true / false

############################################
# UTILS
############################################

compose() {
  $COMPOSE_BIN "$@"
}

all_services() {
  compose config --services
}

service_containers() {
  local service="$1"
  docker ps --all \
    --filter "label=com.docker.compose.service=$service" \
    --format "{{.ID}}"
}

inspect() {
  docker inspect -f "$2" "$1"
}

############################################
# CORE LOGIC (НЕ ЛОМАЛАСЬ)
############################################

evaluate_container() {
  local cid="$1"

  local state health exit_code
  state="$(inspect "$cid" '{{.State.Status}}')"
  health="$(inspect "$cid" '{{.State.Health.Status}}' 2>/dev/null || true)"
  exit_code="$(inspect "$cid" '{{.State.ExitCode}}')"

  case "$state" in
    exited)
      if [[ "$exit_code" == "0" ]]; then
        echo "completed"
      else
        echo "failed"
      fi
      ;;
    running)
      if [[ -n "$health" ]]; then
        case "$health" in
          healthy)   echo "healthy" ;;
          unhealthy) echo "unhealthy" ;;
          *)         echo "up" ;;
        esac
      else
        echo "up"
      fi
      ;;
    *)
      echo "up"
      ;;
  esac
}

check_service() {
  local service="$1"
  local containers
  containers="$(service_containers "$service")"

  if [[ -z "$containers" ]]; then
    SERVICE_STATUS["$service"]="no_containers"
    return
  fi

  local final=""
  for cid in $containers; do
    status="$(evaluate_container "$cid")"

    case "$status" in
      failed|unhealthy)
        final="$status"
        break
        ;;
      healthy)
        final="healthy"
        ;;
      completed)
        [[ -z "$final" ]] && final="completed"
        ;;
      up)
        [[ -z "$final" ]] && final="up"
        ;;
    esac
  done

  SERVICE_STATUS["$service"]="$final"
}

############################################
# TARGET SERVICES (как было)
############################################

if [[ -n "${DOCKER_SERVICES_LIST:-}" ]]; then
  for svc in $DOCKER_SERVICES_LIST; do
    SERVICE_IS_TARGET["$svc"]="true"
  done
fi

############################################
# RUN CHECK
############################################

info "Detecting services from compose config"
services="$(all_services)"

if [[ -z "$services" ]]; then
  fail "No services found in compose config"
  exit 1
fi

for svc in $services; do
  check_service "$svc"
done

############################################
# DETECTED SERVICES
############################################

echo
info "Detected services"
echo "------------------------------------------"

for svc in $services; do
  status="${SERVICE_STATUS[$svc]:-no_containers}"

  case "$status" in
    healthy)       label="[HEALTHY]" ;;
    completed)     label="[COMPLETED]" ;;
    up)            label="[UP]" ;;
    unhealthy)     label="[UNHEALTHY]" ;;
    failed)        label="[FAILED]" ;;
    no_containers) label="[NO CONTAINERS]" ;;
    *)             label="[UNKNOWN]" ;;
  esac
  printf " %-35s %s\n" "$svc" "$label"
done

echo "------------------------------------------"

############################################
# HEALTHCHECK SUMMARY
############################################

overall_ok=true

for svc in $services; do
  status="${SERVICE_STATUS[$svc]}"
  is_target="${SERVICE_IS_TARGET[$svc]:-false}"

  [[ "$is_target" != "true" ]] && continue

  case "$status" in
    healthy|completed|up)
      ;;
    *)
      overall_ok=false
      ;;
  esac
done

if [[ "$overall_ok" == true ]]; then
  ok "Healthcheck passed"
  exit 0
else
  fail "Healthcheck failed"
  exit 1
fi