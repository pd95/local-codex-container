CLAUDE_HOME_DIR="${HOME}/.claude"
CLAUDE_SETTINGS_FILE="${CLAUDE_HOME_DIR}/settings.json"

claude_command_path() {
  runtime_command_path claude
}

claude_write_default_settings() {
  local target_file="$1"

  cat >"$target_file" <<'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "USE_BUILTIN_RIPGREP": "0"
  }
}
EOF
}

claude_verify_alpine_dependencies() {
  if ! command -v apk >/dev/null 2>&1; then
    return 0
  fi

  local missing=0
  local package=""
  for package in libgcc libstdc++ ripgrep; do
    if ! apk info -e "$package" >/dev/null 2>&1; then
      printf 'missing Alpine package for claude: %s\n' "$package" >&2
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    die "Install Claude prerequisites as root first: apk add libgcc libstdc++ ripgrep"
  fi
}

agent_runtime_run() {
  local runtime="$1"
  shift

  [ "$runtime" = "claude" ] || die "unsupported runtime adapter: $runtime"
  exec "$(claude_command_path)" "$@"
}

agent_runtime_install() {
  local runtime="$1"

  [ "$runtime" = "claude" ] || die "unsupported runtime adapter: $runtime"
  claude_verify_alpine_dependencies
  curl -fsSL https://claude.ai/install.sh | bash
  claude_command_path >/dev/null 2>&1 || die "claude installer finished but launcher was not found on PATH or in ~/.local/bin"
  agent_runtime_reset_config "$runtime" "$(runtime_default_config_dir "$runtime")"
  preferred_set "$runtime"
}

agent_runtime_update() {
  local runtime="$1"

  [ "$runtime" = "claude" ] || die "unsupported runtime adapter: $runtime"
  "$(claude_command_path)" update
}

agent_runtime_reset_config() {
  local runtime="$1"
  local config_dir="${2:-}"

  [ "$runtime" = "claude" ] || die "unsupported runtime adapter: $runtime"
  mkdir -p "$CLAUDE_HOME_DIR"
  if [ -n "$config_dir" ] && [ -f "$config_dir/settings.json" ]; then
    cp "$config_dir/settings.json" "$CLAUDE_SETTINGS_FILE"
  else
    claude_write_default_settings "$CLAUDE_SETTINGS_FILE"
  fi
  rm -f "$USER_RUNTIME_FILE"
}

agent_runtime_auth_read() {
  local runtime="$1"

  [ "$runtime" = "claude" ] || die "unsupported runtime adapter: $runtime"
  die "auth read not implemented yet for claude"
}

agent_runtime_auth_write() {
  local runtime="$1"

  [ "$runtime" = "claude" ] || die "unsupported runtime adapter: $runtime"
  die "auth write not implemented yet for claude"
}

agent_runtime_auth_login() {
  local runtime="$1"

  [ "$runtime" = "claude" ] || die "unsupported runtime adapter: $runtime"
  die "auth login not implemented yet for claude"
}
