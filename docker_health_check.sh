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
# GLOBAL STATE (single source of truth)
############################################

declare -A SERVICE_STATUS   # healthy | completed | up | failed | unhealthy | no_containers
declare -A SERVICE_REASON   # optional details

############################################
# UTILS
############################################

compose() {
  $COMPOSE_BIN "$@"
}

get_all_services() {
  compose config --services
}

get_service_containers() {
  local service="$1"
  docker ps --all --filter "label=com.docker.compose.service=$service" --format "{{.ID}}"
}

inspect() {
  docker inspect -f "$2" "$1"
}

############################################
# CORE LOGIC
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
  containers="$(get_service_containers "$service")"

  if [[ -z "$containers" ]]; then
    SERVICE_STATUS["$service"]="no_containers"
    return
  fi

  local final_status=""
  for cid in $containers; do
    status="$(evaluate_container "$cid")"

    case "$status" in
      failed|unhealthy)
        final_status="$status"
        break
        ;;
      healthy)
        final_status="healthy"
        ;;
      completed)
        [[ -z "$final_status" ]] && final_status="completed"
        ;;
      up)
        [[ -z "$final_status" ]] && final_status="up"
        ;;
    esac
  done

  SERVICE_STATUS["$service"]="$final_status"
}

info "Collecting services from compose config..."
services="$(get_all_services)"

for svc in $services; do
  check_service "$svc"
done

############################################
# SUMMARY
############################################

echo
info "Healthcheck summary"
echo "------------------------------------------"

overall_ok=true

for svc in $services; do
  status="${SERVICE_STATUS[$svc]}"

  case "$status" in
    healthy)
      printf " %-35s [HEALTHY]\n" "$svc"
      ;;
    completed)
      printf " %-35s [COMPLETED]\n" "$svc"
      ;;
    up)
      printf " %-35s [UP]\n" "$svc"
      ;;
    no_containers)
      printf " %-35s [NO CONTAINERS]\n" "$svc"
      ;;
    unhealthy)
      printf " %-35s [UNHEALTHY]\n" "$svc"
      overall_ok=false
      ;;
    failed)
      printf " %-35s [FAILED]\n" "$svc"
      overall_ok=false
      ;;
    *)
      printf " %-35s [UNKNOWN]\n" "$svc"
      ;;
  esac
done

echo "------------------------------------------"

if [[ "$overall_ok" == true ]]; then
  ok "Application started successfully!"
  exit 0
else
  fail "Some services failed to start correctly"
  exit 1
fi