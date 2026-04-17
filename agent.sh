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

runtime_known() {
  case "$1" in
    codex) return 0 ;;
    *) return 1 ;;
  esac
}

runtime_ids() {
  printf '%s\n' codex
}

runtime_command_name() {
  case "$1" in
    codex) printf '%s\n' codex ;;
    *) return 1 ;;
  esac
}

runtime_install_method() {
  case "$1" in
    codex) printf '%s\n' npm-global ;;
    *) return 1 ;;
  esac
}

runtime_default_config_dir() {
  case "$1" in
    codex) printf '%s\n' /etc/codexctl ;;
    *) return 1 ;;
  esac
}

runtime_auth_formats_json() {
  case "$1" in
    codex) printf '%s\n' '["json_refresh_token"]' ;;
    *) return 1 ;;
  esac
}

runtime_command_exists() {
  local runtime="$1"
  local command_name=""

  command_name="$(runtime_command_name "$runtime")" || return 1
  command -v "$command_name" >/dev/null 2>&1
}

runtime_installed_json() {
  local runtime="$1"
  if runtime_command_exists "$runtime"; then
    printf '%s\n' true
  else
    printf '%s\n' false
  fi
}

ensure_runtime_known() {
  local runtime="$1"
  runtime_known "$runtime" || die "unsupported runtime: $runtime"
}

ensure_runtime_installed() {
  local runtime="$1"
  ensure_runtime_known "$runtime"
  runtime_command_exists "$runtime" && return 0
  die "runtime not installed: $runtime (run: agent.sh runtime install $runtime)"
}

json_runtime_info() {
  local runtime="$1"
  local installed_json preferred_json

  ensure_runtime_known "$runtime"
  installed_json="$(runtime_installed_json "$runtime")"
  if [ "$(runtime_preferred)" = "$runtime" ]; then
    preferred_json=true
  else
    preferred_json=false
  fi

  jq -n \
    --arg runtime "$runtime" \
    --arg image "$IMAGE_NAME" \
    --arg default_profile "$DEFAULT_PROFILE" \
    --arg preferred "$(runtime_preferred)" \
    --arg launcher "/usr/local/bin/agent.sh run" \
    --arg command_name "$(runtime_command_name "$runtime")" \
    --arg install_method "$(runtime_install_method "$runtime")" \
    --arg config_dir "$(runtime_default_config_dir "$runtime")" \
    --argjson auth_formats "$(runtime_auth_formats_json "$runtime")" \
    --argjson installed "$installed_json" \
    --argjson selected "$preferred_json" \
    '{
      runtime: $runtime,
      image: $image,
      installed: $installed,
      preferred: $selected,
      preferred_runtime: $preferred,
      launcher: $launcher,
      command: $command_name,
      install_method: $install_method,
      auth_formats: $auth_formats,
      default_config_dir: $config_dir,
      default_profile: $default_profile,
      phase: 2
    }'
}

json_runtime_capabilities() {
  local runtime="$1"

  ensure_runtime_known "$runtime"
  jq -n \
    --arg runtime "$runtime" \
    '{
      runtime: $runtime,
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
        "runtime install codex",
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
  ensure_runtime_known "$runtime"
  [ "$key" = json_refresh_token ] || die "unsupported auth format: $key"
  [ -f "$CODEX_AUTH_FILE" ] || exit 1
  cat "$CODEX_AUTH_FILE"
}

auth_write() {
  local runtime="$1" key="$2" value="${3:-}"
  ensure_runtime_known "$runtime"
  [ "$key" = json_refresh_token ] || die "unsupported auth format: $key"
  ensure_user_dirs
  if [ -z "$value" ] && [ ! -t 0 ]; then
    value="$(cat)"
  fi
  printf '%s' "$value" >"$CODEX_AUTH_FILE"
}

auth_login() {
  local runtime="$1"
  ensure_runtime_installed "$runtime"
  exec codex login --device-auth
}

preferred_get() {
  runtime_preferred
}

preferred_set() {
  local runtime="${1:-}"
  ensure_runtime_known "$runtime"
  ensure_user_dirs
  printf '%s\n' "$runtime" >"$USER_RUNTIME_FILE"
}

runtime_list() {
  runtime_ids
}

runtime_install() {
  local runtime="${1:-}"
  ensure_runtime_known "$runtime"

  case "$runtime" in
    codex)
      npm install -g @openai/codex --omit=dev --no-fund --no-audit
      preferred_set "$runtime"
      ;;
  esac
}

runtime_update() {
  local runtime="${1:-}"
  ensure_runtime_known "$runtime"
  exec npm install -g @openai/codex --omit=dev --no-fund --no-audit
}

runtime_reset_config() {
  local runtime="${1:-}"
  ensure_runtime_known "$runtime"
  local config_dir

  config_dir="$(runtime_default_config_dir "$runtime")"
  ensure_user_dirs
  cp "$config_dir/config.toml" "$CODEX_HOME_DIR/config.toml"
  if [ -f "$config_dir/local_models.json" ]; then
    cp "$config_dir/local_models.json" "$CODEX_HOME_DIR/local_models.json"
  else
    rm -f "$CODEX_HOME_DIR/local_models.json"
  fi
  ln -sf "$config_dir/image.md" "$CODEX_HOME_DIR/AGENTS.md"
  rm -f "$USER_RUNTIME_FILE"
}

refresh_agent() {
  ensure_user_dirs
  jq -n \
    --arg preferred "$(runtime_preferred)" \
    --argjson runtimes "$(runtime_ids | jq -R . | jq -s .)" \
    '{status: "ok", preferred_runtime: $preferred, runtimes: $runtimes}'
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
  agent.sh runtime install codex
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
      ensure_runtime_installed "$(runtime_preferred)"
      case "$(runtime_preferred)" in
        codex)
          run_codex "$@"
          ;;
        *)
          die "unsupported runtime: $(runtime_preferred)"
          ;;
      esac
      ;;
    version)
      printf '%s\n' "agent.sh phase2"
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
          json_runtime_info "${2:-}"
          ;;
        capabilities)
          json_runtime_capabilities "${2:-}"
          ;;
        install)
          runtime_install "${2:-}"
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
