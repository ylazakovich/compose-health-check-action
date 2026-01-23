#!/usr/bin/env bash
set -euo pipefail

compose_files_input="${COMPOSE_FILES_INPUT:-}"
additional_args_input="${ADDITIONAL_COMPOSE_ARGS_INPUT:-}"
compose_services_input="${COMPOSE_SERVICES_INPUT:-}"
services_input="${SERVICES_INPUT:-}"
compose_profiles_input="${COMPOSE_PROFILES_INPUT:-}"
docker_command_input="${DOCKER_COMMAND_INPUT:-}"

if [[ -n "$compose_services_input" ]]; then
  services_input="$compose_services_input"
fi

parse_docker_command() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to parse docker-command safely." >&2
    exit 1
  fi
  python3 - <<'PY' "$docker_command_input"
import shlex
import sys

cmd = sys.argv[1]
parts = shlex.split(cmd)
sys.stdout.write("\0".join(parts) + "\0")
PY
}

if [[ -n "$docker_command_input" ]]; then
  mapfile -d '' -t CMD < <(parse_docker_command)
  if ((${#CMD[@]} < 2)) || [[ "${CMD[0]}" != "docker" || "${CMD[1]}" != "compose" ]]; then
    echo "docker-command must start with 'docker compose'." >&2
    exit 1
  fi
else
  CMD=(docker compose)

  while IFS= read -r file; do
    if [[ -n "$file" ]]; then
      CMD+=(-f "$file")
    fi
  done <<<"$compose_files_input"

  if [[ -n "$compose_profiles_input" ]]; then
    read -r -a profile_arr <<<"$(tr '\n' ' ' <<<"$compose_profiles_input")"
    for profile in "${profile_arr[@]}"; do
      [[ -n "$profile" ]] || continue
      CMD+=(--profile "$profile")
    done
  fi

  CMD+=(up -d)

  if [[ -n "$additional_args_input" ]]; then
    read -r -a extra_args <<<"$additional_args_input"
    CMD+=("${extra_args[@]}")
  fi

  if [[ -n "$services_input" ]]; then
    read -r -a svc_arr <<<"$services_input"
    CMD+=("${svc_arr[@]}")
  fi
fi

printf '%s\0' "${CMD[@]}"
