#!/usr/bin/env bash

# peer-review.sh — session lifecycle for cross-agent peer review
#
# commands:
#   init                              create session dir, print path
#   invoke <target> <session-dir> <round>   invoke reviewer, capture response
#   cleanup <session-dir>             safe deletion of session dir

set -euo pipefail

TIMEOUT="${PEER_REVIEW_TIMEOUT:-600}"
MAX_ROUNDS="${PEER_REVIEW_MAX_ROUNDS:-3}"
# used for "transport exists but unavailable in current environment"
TRANSPORT_UNAVAILABLE_CODE=75

# resolve skill directory for prompt template access
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="${PEER_REVIEW_SKILL_DIR:-$(dirname "$SCRIPT_DIR")}"
PROMPT_FILE="$SKILL_DIR/templates/prompt.md"

die() { echo "error: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  peer-review.sh init [label]
  peer-review.sh invoke <codex|claude> <session-dir> <round>
  peer-review.sh cleanup <session-dir>

Commands:
  init      Create a session directory under .agent-chat/ in the current repo.
            Optional label becomes part of the directory name for readability.
            Prints the absolute session dir path to stdout.
            Example: peer-review.sh init "auth refactor"
              → .agent-chat/260208-1430-auth-refactor/

  invoke    Assemble a request file, invoke the reviewer, and capture the
            response. Exit codes:
              0  success (response at <session-dir>/round-<N>-response.md)
              1  invocation failed (details at <session-dir>/round-<N>-error.txt)
              2  transport unavailable (details at <session-dir>/round-<N>-error.txt)

  cleanup   Delete a session directory. Validates the path is inside .agent-chat/
            and contains a .workspace_root marker before deletion.

Environment:
  PEER_REVIEW_TIMEOUT    seconds per reviewer call (default: 600)
  PEER_REVIEW_MAX_ROUNDS maximum round number allowed (default: 3)
  PEER_REVIEW_SKILL_DIR  override skill directory path
EOF
}

summarize_output() {
  local raw_output="$1"
  local compact_output

  compact_output="$(printf '%s' "$raw_output" | tr '\r' '\n' | sed -n '1,6p' | tr '\n' ' ')"
  if [[ -z "${compact_output//[[:space:]]/}" ]]; then
    printf '%s' "<no output>"
    return
  fi

  printf '%s' "${compact_output:0:320}"
}

archive_file_if_exists() {
  local file_path="$1"
  local timestamp

  [[ -f "$file_path" ]] || return 0
  timestamp="$(date +%Y%m%d-%H%M%S)-$RANDOM"
  mv "$file_path" "${file_path}.prev-${timestamp}"
}

check_claude_local_access() {
  command -v claude >/dev/null 2>&1 || {
    printf '%s\n' "command not found: claude"
    return 1
  }

  # claude writes runtime state under $HOME
  if [[ ! -w "$HOME" ]]; then
    printf '%s\n' "cannot write to HOME path '$HOME' (required by claude runtime)"
    return 1
  fi
}

canonicalize_path() {
  local input_path="$1"
  realpath -m "$input_path" 2>/dev/null || readlink -f "$input_path" 2>/dev/null
}

resolve_session_dir() {
  local session_dir="$1"
  local resolved_session_dir
  local parent_name
  local dir_name
  local workspace_root
  local resolved_workspace_root
  local expected_workspace_root

  resolved_session_dir="$(canonicalize_path "$session_dir")" \
    || die "cannot resolve path: $session_dir"
  [[ -d "$resolved_session_dir" ]] || die "session dir not found: $resolved_session_dir"

  parent_name="$(basename "$(dirname "$resolved_session_dir")")"
  [[ "$parent_name" == ".agent-chat" ]] \
    || die "invalid session dir parent '$parent_name'; expected '.agent-chat'"

  [[ -f "$resolved_session_dir/.workspace_root" ]] \
    || die "missing .workspace_root marker in $resolved_session_dir"
  workspace_root="$(cat "$resolved_session_dir/.workspace_root" 2>/dev/null || true)"
  [[ -n "$workspace_root" ]] \
    || die "empty .workspace_root marker in $resolved_session_dir"

  resolved_workspace_root="$(canonicalize_path "$workspace_root")" \
    || die "cannot resolve workspace root path: $workspace_root"
  expected_workspace_root="$(dirname "$(dirname "$resolved_session_dir")")"
  [[ "$resolved_workspace_root" == "$expected_workspace_root" ]] \
    || die "session marker mismatch: .workspace_root points to '$resolved_workspace_root', expected '$expected_workspace_root'"

  printf '%s\n' "$resolved_session_dir"
}

# --- init command ---

init_command() {
  local label="${1:-review}"

  # sanitize label: lowercase, non-alphanumeric to hyphens, collapse, trim edges, truncate
  label="$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//')"
  label="${label:0:40}"
  [[ -n "$label" ]] || label="review"

  local workspace_root
  workspace_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"

  local session_root="$workspace_root/.agent-chat"
  mkdir -p "$session_root"
  [[ -f "$session_root/.gitignore" ]] || printf '*\n' > "$session_root/.gitignore"

  local timestamp
  timestamp="$(date +%y%m%d-%H%M)"
  local base="$session_root/${timestamp}-${label}"
  local session_dir="$base"
  # atomic collision handling: mkdir fails if dir exists, then try numeric suffixes
  local i=1
  while ! mkdir "$session_dir" 2>/dev/null; do
    ((i++))
    session_dir="${base}-${i}"
    [[ $i -le 99 ]] || die "too many session collisions for ${base}"
  done

  # record workspace root so the reviewer knows where to look
  printf '%s\n' "$workspace_root" > "$session_dir/.workspace_root"

  # single line of output — the session dir path
  printf '%s\n' "$session_dir"
}

# --- invoke command ---

# assemble the request file: context first, then review instructions
assemble_request() {
  local session_dir="$1"
  local round="$2"
  local request_file="$session_dir/round-$round-request.md"
  local workspace_root
  workspace_root="$(cat "$session_dir/.workspace_root")"

  {
    echo "# Peer review request"
    echo

    # workspace orientation comes first so reviewer knows where they are
    echo "## Workspace"
    echo
    echo "Project root: \`$workspace_root\`"
    echo "Session dir: \`$session_dir\`"
    echo

    if [[ "$round" -eq 1 ]]; then
      # round 1: caller context (the thing being reviewed) before instructions
      echo "## Context"
      echo
      cat "$session_dir/context.md"
      echo
    else
      # round 2+: previous response + caller followup
      local prev_round=$((round - 1))
      echo "## Previous reviewer response (round $prev_round)"
      echo
      cat "$session_dir/round-$prev_round-response.md"
      echo
      echo "## Caller followup"
      echo
      cat "$session_dir/round-$round-followup.md"
      echo
      echo "## Session history"
      echo
      echo "Original context: \`$session_dir/context.md\`"
      echo "All round artifacts are in \`$session_dir/\` (\`round-N-request.md\`, \`round-N-response.md\`, \`round-N-followup.md\`). Read earlier rounds sequentially as needed for full conversation history."
      echo
    fi

    # review instructions (criteria, output format, principles)
    cat "$PROMPT_FILE"
    echo

    # round-specific instructions at the end
    echo "## Round instructions"
    echo
    if [[ "$round" -eq 1 ]]; then
      echo "This is round 1. Inspect the repository directly before concluding."
    else
      echo "This is round $round. Focus on unresolved disagreements and validate any proposed solutions."
      echo "Keep settled points closed. Do not re-raise accepted items."
      echo "Read earlier round artifacts from the session history above if needed for background."
    fi
  } > "$request_file"
}

# invoke the reviewer CLI with full timeout
run_reviewer() {
  local target="$1"
  local request_file="$2"
  local response_file="$3"

  case "$target" in
    codex)
      # use last-message capture to keep response artifacts clean
      # note: --output-last-message is a codex CLI feature that may change across versions;
      # fallback chain below handles degradation if the flag is removed or changes behavior
      local codex_log_file="${response_file%-response.md}-invoke.log"
      local codex_status=0
      timeout "${TIMEOUT}s" codex exec --sandbox read-only \
        --output-last-message "$response_file" \
        "Read the file at $request_file and follow every instruction in it." \
        > "$codex_log_file" 2>&1 || codex_status=$?
      # fallback: if --output-last-message produced no output, use full transcript
      if [[ $codex_status -eq 0 && ! -s "$response_file" && -s "$codex_log_file" ]]; then
        cp "$codex_log_file" "$response_file"
      fi
      # retry without --output-last-message if it caused a non-timeout failure
      if [[ $codex_status -ne 0 && $codex_status -ne 124 && ! -s "$response_file" ]]; then
        codex_status=0
        timeout "${TIMEOUT}s" codex exec --sandbox read-only \
          "Read the file at $request_file and follow every instruction in it." \
          > "$response_file" 2>&1 || codex_status=$?
      fi
      return $codex_status
      ;;
    claude)
      local claude_preflight_error=""
      if ! claude_preflight_error="$(check_claude_local_access)"; then
        # codex sandbox cannot run claude reliably without elevated permissions
        printf '%s\n' "$claude_preflight_error" > "${response_file%-response.md}-invoke.log"
        return "$TRANSPORT_UNAVAILABLE_CODE"
      fi

      # claude -p hangs if stdin is not closed when using a positional prompt
      # stderr goes to invoke.log to keep the response file clean
      local claude_log_file="${response_file%-response.md}-invoke.log"
      timeout "${TIMEOUT}s" claude -p \
        "Read the file at $request_file and follow every instruction in it." \
        --output-format text --permission-mode dontAsk --tools Read,Grep,Glob \
      < /dev/null > "$response_file" 2>"$claude_log_file"
      ;;
  esac
}

invoke_command() {
  local target="$1"
  local session_dir="$2"
  local round="$3"

  # validate inputs
  case "$target" in
    codex|claude) ;;
    *) die "target must be 'codex' or 'claude', got: $target" ;;
  esac
  session_dir="$(resolve_session_dir "$session_dir")"
  [[ "$round" =~ ^[0-9]+$ ]] || die "round must be a positive integer, got: $round"
  [[ "$round" -ge 1 ]] || die "round must be >= 1"
  [[ "$round" -le "$MAX_ROUNDS" ]] || die "round $round exceeds max rounds ($MAX_ROUNDS). Set PEER_REVIEW_MAX_ROUNDS to increase."

  local request_file="$session_dir/round-$round-request.md"
  local response_file="$session_dir/round-$round-response.md"
  local error_file="$session_dir/round-$round-error.txt"
  local invoke_log_file="${response_file%-response.md}-invoke.log"
  local workspace_root

  workspace_root="$(cat "$session_dir/.workspace_root" 2>/dev/null || true)"
  [[ -n "$workspace_root" ]] || die "missing .workspace_root in $session_dir"
  [[ -d "$workspace_root" ]] || die "workspace root not found: $workspace_root"

  # archive prior round artifacts so retries stay debuggable without stale-state confusion
  archive_file_if_exists "$request_file"
  archive_file_if_exists "$response_file"
  archive_file_if_exists "$error_file"
  archive_file_if_exists "$invoke_log_file"

  # validate required input files
  if [[ "$round" -eq 1 ]]; then
    [[ -f "$session_dir/context.md" ]] || die "missing context.md in $session_dir"
  else
    local prev_round=$((round - 1))
    [[ -f "$session_dir/round-$prev_round-response.md" ]] \
      || die "missing round-$prev_round-response.md in $session_dir"
    [[ -f "$session_dir/round-$round-followup.md" ]] \
      || die "missing round-$round-followup.md in $session_dir"
    # round 2+ assembly points to context.md for session history
    [[ -f "$session_dir/context.md" ]] \
      || die "missing context.md in $session_dir (needed for round 2+ session history)"
  fi

  [[ -f "$PROMPT_FILE" ]] || die "missing prompt template: $PROMPT_FILE"

  # assemble the request
  assemble_request "$session_dir" "$round"

  # invoke reviewer
  local invoke_status=0
  (cd "$workspace_root" && run_reviewer "$target" "$request_file" "$response_file") || invoke_status=$?

  # check for timeout
  if [[ $invoke_status -eq 124 ]]; then
    {
      echo "Reviewer timed out after ${TIMEOUT}s."
      echo "Session artifacts preserved at: $session_dir"
    } > "$error_file"
    exit 1
  fi

  # transport unavailable in current execution environment (for example codex sandbox)
  if [[ $invoke_status -eq "$TRANSPORT_UNAVAILABLE_CODE" ]]; then
    local script_path
    local transport_details="<no details>"
    script_path="$(canonicalize_path "${BASH_SOURCE[0]}" || true)"
    [[ -n "$script_path" ]] || script_path="${BASH_SOURCE[0]}"
    if [[ -s "$invoke_log_file" ]]; then
      transport_details="$(summarize_output "$(cat "$invoke_log_file")")"
    fi
    {
      echo "Transport unavailable: '$target' CLI cannot run in this environment."
      echo "Details: $transport_details"
      echo ""
      echo "Run this command with elevated permissions:"
      echo "  $script_path invoke $target $session_dir $round"
      echo ""
      echo "If elevated execution is unavailable, ask for manual handoff:"
      echo "  /peer-review pickup $session_dir"
    } > "$error_file"
    exit 2
  fi

  # check for other failure
  if [[ $invoke_status -ne 0 ]]; then
    {
      echo "Reviewer exited with code $invoke_status."
      echo "Session artifacts preserved at: $session_dir"
    } > "$error_file"
    exit 1
  fi

  # check for empty response
  if [[ ! -s "$response_file" ]] || ! grep -q '[^[:space:]]' "$response_file"; then
    {
      echo "Reviewer returned empty or whitespace-only response."
      echo "Session artifacts preserved at: $session_dir"
    } > "$error_file"
    exit 1
  fi
}

# --- cleanup command ---

cleanup_command() {
  local session_dir="$1"
  local resolved

  resolved="$(resolve_session_dir "$session_dir")"

  [[ -d "$resolved" ]] && rm -rf "$resolved"
}

# --- main ---

[[ $# -ge 1 ]] || { usage; exit 1; }

command_name="$1"
shift

case "$command_name" in
  init)
    init_command "${1:-}"
    ;;
  invoke)
    [[ $# -eq 3 ]] || die "invoke requires: <target> <session-dir> <round>"
    invoke_command "$1" "$2" "$3"
    ;;
  cleanup)
    [[ $# -eq 1 ]] || die "cleanup requires: <session-dir>"
    cleanup_command "$1"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    die "unknown command: $command_name"
    ;;
esac
