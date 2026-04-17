agent_runtime_run() {
  local runtime="$1"
  shift

  [ "$runtime" = "claude" ] || die "unsupported runtime adapter: $runtime"
  exec claude "$@"
}

agent_runtime_install() {
  local runtime="$1"

  [ "$runtime" = "claude" ] || die "unsupported runtime adapter: $runtime"
  die "runtime install not implemented yet for claude"
}

agent_runtime_update() {
  local runtime="$1"

  [ "$runtime" = "claude" ] || die "unsupported runtime adapter: $runtime"
  die "runtime update not implemented yet for claude"
}

agent_runtime_reset_config() {
  local runtime="$1"

  [ "$runtime" = "claude" ] || die "unsupported runtime adapter: $runtime"
  die "runtime reset-config not implemented yet for claude"
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
