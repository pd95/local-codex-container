#!/usr/bin/env bash
set -euo pipefail

readonly IMAGE_NAME="${IMAGE_NAME:-agent-plain}"
readonly DEFAULT_RUNTIME_FILE="/etc/agentctl/preferred-runtime"
readonly USER_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agentctl"
readonly USER_RUNTIME_FILE="${USER_CONFIG_DIR}/preferred-runtime"
readonly CODEX_HOME_DIR="${HOME}/.codex"
readonly CODEX_AUTH_FILE="${CODEX_HOME_DIR}/auth.json"
readonly DEFAULT_PROFILE="${AGENTCTL_DEFAULT_PROFILE:-gpt-oss}"
readonly RUN_MODE="${AGENTCTL_RUN_MODE:-local-model}"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

runtime_default() {
  if [ -f "$DEFAULT_RUNTIME_FILE" ]; then
    tr -d '[:space:]' <"$DEFAULT_RUNTIME_FILE"
    return
  fi
  printf '%s\n' codex
}

runtime_preferred() {
  if [ -n "${AGENTCTL_PREFERRED_RUNTIME:-}" ]; then
    printf '%s\n' "$AGENTCTL_PREFERRED_RUNTIME"
    return
  fi

  if [ -f "$USER_RUNTIME_FILE" ]; then
    tr -d '[:space:]' <"$USER_RUNTIME_FILE"
    return
  fi

  runtime_default
}

require_codex_runtime() {
  local runtime
  runtime="$(runtime_preferred)"
  case "$runtime" in
    codex) return 0 ;;
    *) die "unsupported runtime: $runtime" ;;
  esac
}

has_explicit_profile() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --profile|--profile=*) return 0 ;;
    esac
  done
  return 1
}

run_codex() {
  require_codex_runtime
  case "$RUN_MODE" in
    openai)
      exec codex "$@"
      ;;
  esac
  if has_explicit_profile "$@"; then
    exec codex "$@"
  fi
  exec codex --profile "$DEFAULT_PROFILE" "$@"
}

ensure_user_dirs() {
  mkdir -p "$USER_CONFIG_DIR" "$CODEX_HOME_DIR"
}

json_runtime_info() {
  jq -n \
    --arg runtime codex \
    --arg image "$IMAGE_NAME" \
    --arg default_profile "$DEFAULT_PROFILE" \
    --arg preferred "$(runtime_preferred)" \
    --arg launcher "/usr/local/bin/agent.sh run" \
    '{
      runtime: $runtime,
      image: $image,
      preferred_runtime: $preferred,
      launcher: $launcher,
      default_profile: $default_profile,
      phase: 1
    }'
}

json_runtime_capabilities() {
  jq -n '
    {
      runtime: "codex",
      commands: [
        "help",
        "run",
        "version",
        "refresh",
        "runtime list",
        "preferred get",
        "preferred set codex",
        "runtime info codex",
        "runtime capabilities codex",
        "runtime update codex",
        "runtime reset-config codex",
        "auth login codex",
        "auth read codex json_refresh_token",
        "auth write codex json_refresh_token",
        "system manifest"
      ]
    }'
}

json_system_manifest() {
  local package_manager packages_json

  if command -v apk >/dev/null 2>&1; then
    package_manager=apk
    packages_json="$(apk info -q 2>/dev/null | sort -u | jq -R . | jq -s .)"
  elif command -v dpkg-query >/dev/null 2>&1; then
    package_manager=dpkg
    packages_json="$(dpkg-query -W -f='${Package}\n' 2>/dev/null | sort -u | jq -R . | jq -s .)"
  else
    package_manager=unknown
    packages_json='[]'
  fi

  jq -n \
    --arg package_manager "$package_manager" \
    --argjson packages "$packages_json" \
    '{
      package_manager: $package_manager,
      packages: $packages
    }'
}

auth_read() {
  local runtime="$1" key="$2"
  [ "$runtime" = codex ] || die "unsupported runtime: $runtime"
  [ "$key" = json_refresh_token ] || die "unsupported auth format: $key"
  [ -f "$CODEX_AUTH_FILE" ] || exit 1
  cat "$CODEX_AUTH_FILE"
}

auth_write() {
  local runtime="$1" key="$2" value="${3:-}"
  [ "$runtime" = codex ] || die "unsupported runtime: $runtime"
  [ "$key" = json_refresh_token ] || die "unsupported auth format: $key"
  ensure_user_dirs
  if [ -z "$value" ] && [ ! -t 0 ]; then
    value="$(cat)"
  fi
  printf '%s' "$value" >"$CODEX_AUTH_FILE"
}

auth_login() {
  local runtime="$1"
  [ "$runtime" = codex ] || die "unsupported runtime: $runtime"
  exec codex login --device-auth
}

preferred_get() {
  runtime_preferred
}

preferred_set() {
  local runtime="${1:-}"
  case "$runtime" in
    codex) ;;
    *) die "unsupported preferred runtime: $runtime" ;;
  esac
  ensure_user_dirs
  printf '%s\n' "$runtime" >"$USER_RUNTIME_FILE"
}

runtime_list() {
  printf '%s\n' codex
}

runtime_update() {
  local runtime="${1:-}"
  [ "$runtime" = codex ] || die "unsupported runtime: $runtime"
  exec npm install -g @openai/codex --omit=dev --no-fund --no-audit
}

runtime_reset_config() {
  local runtime="${1:-}"
  [ "$runtime" = codex ] || die "unsupported runtime: $runtime"
  ensure_user_dirs
  cp /etc/codexctl/config.toml "$CODEX_HOME_DIR/config.toml"
  if [ -f /etc/codexctl/local_models.json ]; then
    cp /etc/codexctl/local_models.json "$CODEX_HOME_DIR/local_models.json"
  else
    rm -f "$CODEX_HOME_DIR/local_models.json"
  fi
  ln -sf /etc/codexctl/image.md "$CODEX_HOME_DIR/AGENTS.md"
  rm -f "$USER_RUNTIME_FILE"
}

refresh_agent() {
  ensure_user_dirs
  jq -n \
    --arg preferred "$(runtime_preferred)" \
    '{status: "ok", preferred_runtime: $preferred}'
}

usage() {
  cat <<'EOF'
Usage:
  agent.sh help
  agent.sh run [codex args...]
  agent.sh version
  agent.sh refresh
  agent.sh runtime list
  agent.sh preferred get
  agent.sh preferred set codex
  agent.sh runtime info codex
  agent.sh runtime capabilities codex
  agent.sh runtime update codex
  agent.sh runtime reset-config codex
  agent.sh auth login codex
  agent.sh auth read codex json_refresh_token
  agent.sh auth write codex json_refresh_token [VALUE]
  agent.sh system manifest
EOF
}

main() {
  local command="${1:-help}"
  shift || true

  case "$command" in
    help|-h|--help)
      usage
      ;;
    run)
      run_codex "$@"
      ;;
    version)
      printf '%s\n' "agent.sh phase1"
      ;;
    refresh)
      refresh_agent
      ;;
    runtime)
      case "${1:-}" in
        list)
          runtime_list
          ;;
        info)
          case "${2:-}" in
            codex) json_runtime_info ;;
            *) die "unsupported runtime: ${2:-}" ;;
          esac
          ;;
        capabilities)
          case "${2:-}" in
            codex) json_runtime_capabilities ;;
            *) die "unsupported runtime: ${2:-}" ;;
          esac
          ;;
        update)
          runtime_update "${2:-}"
          ;;
        reset-config)
          runtime_reset_config "${2:-}"
          ;;
        *)
          die "unknown runtime command: ${1:-}"
          ;;
      esac
      ;;
    preferred)
      case "${1:-}" in
        get)
          preferred_get
          ;;
        set)
          preferred_set "${2:-}"
          ;;
        *)
          die "unknown preferred command: ${1:-}"
          ;;
      esac
      ;;
    auth)
      case "${1:-}" in
        login)
          auth_login "${2:-}"
          ;;
        read)
          auth_read "${2:-}" "${3:-}"
          ;;
        write)
          auth_write "${2:-}" "${3:-}" "${4:-}"
          ;;
        *)
          die "unknown auth command: ${1:-}"
          ;;
      esac
      ;;
    system)
      case "${1:-}" in
        manifest)
          json_system_manifest
          ;;
        *)
          die "unknown system command: ${1:-}"
          ;;
      esac
      ;;
    *)
      die "unknown command: $command"
      ;;
  esac
}

main "$@"
