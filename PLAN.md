# Codex Container Script Plan (macOS)

## Goal
Create a single bash script (approach A) that manages creation/running/restarting/removing Codex containers via Apple `container`. Default is persistent containers; `--temp` creates throwaway containers.

## Scope and Inputs
- Default use: local inference (Ollama) with images built from `DockerFile*`.
- Optional OpenAI mode: handle device-auth automatically and persist auth in Keychain.
- Parameters: container name, base image, temp/persist, CPU, memory, openai vs local, exec shell.

## Deliverables
1) `codexctl` shell script with subcommands.
2) Enhanced `codex-auth-keychain.sh` with a `verify` subcommand.
3) Help text and examples.

## CLI Shape (proposed)
- `codexctl build` — build images from Dockerfiles.
- `codexctl run` — create/start container for current directory.
- `codexctl start|stop|restart|rm|exec|ls` — container management.
- `codexctl auth` — trigger OpenAI device-auth flow on demand.

## Default Behavior
- Persistent container by default; `--temp` uses `--rm`.
- Default name: `codex-$(basename "$PWD")`.
- `--openai` default image: `codex-swift` (unless `--image` supplied).
- Mount current directory: `--mount type=bind,src=$(pwd),dst=/workdir`.

## OpenAI Flow (automatic command execution)
1) **Auth check**:
   - If `--auth` passed or keychain missing, run login flow.
2) **Login flow**:
   - Start an auth container (name like `codex-openai-auth-$(basename "$PWD")`).
   - Run `codex login --device-auth` automatically inside it.
   - After completion, store auth: `./codex-auth-keychain.sh store-from-container <auth-container>`.
   - Remove auth container if desired.
3) **Run main container**:
   - Ensure container exists (create if missing, start if stopped).
   - Start detached: `container start <name>`.
   - Load auth: `./codex-auth-keychain.sh load-to-container <name>`.
   - Attach and run: `container exec -it <name> codex --dangerously-bypass-approvals-and-sandbox`.

## Keychain Script Enhancement
- Add subcommand:
  - `verify`: exit 0 if key exists, non-zero if not.
  - Implementation: `security find-generic-password -a "$ACCOUNT_NAME" -s "$SERVICE_NAME" >/dev/null`.

## Parsing/Dispatch Notes
- Use `case "$1" in ...` for subcommands.
- Parse flags in a `while` loop; support `--name`, `--image`, `--openai`, `--auth`, `--temp`, `--cpu`, `--mem`, `--shell`.
- Helpers:
  - `container_exists(name)`
  - `container_running(name)`
  - `default_name(prefix)`
  - `run_container(args)`

## Error Handling
- Fail fast if `container` is missing.
- Print clear errors if image not found or container actions fail.
- For `--openai`: warn if keychain store/load fails.

## Testing/Validation
- `codexctl run --temp` runs throwaway container.
- `codexctl run` creates persistent container and can restart it.
- `codexctl run --openai` triggers auth flow if key missing.
- `codexctl run --openai --auth` forces login flow.

## Open Questions (to resolve before coding)
- Should auth container be removed automatically after storing key? (default: yes)
- Should `codexctl auth` run login flow and then exit, or proceed to start the main container?
- Should `--openai` imply `--shell` (bash) or direct `codex` run after auth?
