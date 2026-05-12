#!/usr/bin/env bash
# Shared model shortcut helpers for shell-based AI CLIs.
# Source this file (or equivalent) to enable:
#   aispark, ai_high, ai_xhigh
#
# Usage:
#   aispark [cli] [args...]      # Default cli: pi
#   aispark codex --resume last
#   ai_high codex "ask ..."
#   ai_xhigh pi --continue
#
# Supported cli targets:
#   pi       (uses --thinking)
#   codex    (model only)
#   opencode (model only)
#   claude   (model only)

_ai_profile_for_name() {
  case "$1" in
    spark)
      _AI_PROFILE_MODEL="gpt-5.3-codex-spark"
      _AI_PROFILE_THINKING="medium"
      ;;
    high)
      _AI_PROFILE_MODEL="gpt-5.5"
      _AI_PROFILE_THINKING="high"
      ;;
    xhigh)
      _AI_PROFILE_MODEL="gpt-5.5"
      _AI_PROFILE_THINKING="xhigh"
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}

_ai() {
  local profile="$1"
  local cli="${2:-pi}"
  shift 2 || true

  if ! _ai_profile_for_name "$profile"; then
    echo "Unknown profile: $profile" >&2
    return 1
  fi

  case "$cli" in
    pi)
      command pi --provider openai-codex --model "$_AI_PROFILE_MODEL" --thinking "$_AI_PROFILE_THINKING" "$@"
      ;;
    codex)
      command codex --model "$_AI_PROFILE_MODEL" "$@"
      ;;
    opencode)
      command opencode --model "$_AI_PROFILE_MODEL" "$@"
      ;;
    claude)
      command claude --model "$_AI_PROFILE_MODEL" "$@"
      ;;
    *)
      echo "Unsupported cli target: $cli (expected pi|codex|opencode|claude)" >&2
      return 1
      ;;
  esac
}

aispark() {
  _ai spark "$@"
}

ai_high() {
  _ai high "$@"
}

ai_xhigh() {
  _ai xhigh "$@"
}

# Optional quick commands:
#   spark  -> aispark
#   high   -> ai_high
#   xhigh  -> ai_xhigh
alias spark='aispark'
alias high='ai_high'
alias xhigh='ai_xhigh'
