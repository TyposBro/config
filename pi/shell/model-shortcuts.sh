#!/usr/bin/env bash
# Shared model shortcut helpers for shell-based AI CLIs.
# Source this file (or equivalent) to enable:
#   aispark, ai_high, ai_xhigh
#   ai_reviewer, ai_oracle, ai_explore, ai_quick_task
#
# Usage:
#   ai_explore [cli] [args...]   # Default cli: pi
#   ai_quick_task pi --continue
#
# Supported cli targets:
#   pi       (uses --thinking)
#   claude   (model only)

_ai_profile_for_name() {
  case "$1" in
    spark)
      _AI_PROFILE_PROVIDER="openai-codex"
      _AI_PROFILE_MODEL="gpt-5.3-codex-spark"
      _AI_PROFILE_THINKING="medium"
      ;;
    high)
      _AI_PROFILE_PROVIDER="openai-codex"
      _AI_PROFILE_MODEL="gpt-5.5"
      _AI_PROFILE_THINKING="high"
      ;;
    xhigh|reviewer|oracle)
      _AI_PROFILE_PROVIDER="openai-codex"
      _AI_PROFILE_MODEL="gpt-5.5"
      _AI_PROFILE_THINKING="xhigh"
      ;;
    explore)
      _AI_PROFILE_PROVIDER="google"
      _AI_PROFILE_MODEL="gemini-3.1-pro-preview"
      _AI_PROFILE_THINKING="high"
      ;;
    quick_task)
      _AI_PROFILE_PROVIDER="deepseek"
      _AI_PROFILE_MODEL="deepseek-v4-pro"
      _AI_PROFILE_THINKING="medium"
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}

_ai() {
  local profile="$1"
  shift || true

  local cli="pi"
  case "${1:-}" in
    pi|claude)
      cli="$1"
      shift
      ;;
  esac
  if ! _ai_profile_for_name "$profile"; then
    echo "Unknown profile: $profile" >&2
    return 1
  fi

  case "$cli" in
    pi)
      local provider_args=()
      if [ "$_AI_PROFILE_PROVIDER" != "openai-codex" ]; then
        provider_args=(--provider "$_AI_PROFILE_PROVIDER")
      fi
      command pi "${provider_args[@]}" --model "$_AI_PROFILE_MODEL" --thinking "$_AI_PROFILE_THINKING" "$@"
      ;;
    claude)
      command claude --model "$_AI_PROFILE_MODEL" "$@"
      ;;
    *)
      echo "Unsupported cli target: $cli (expected pi|claude)" >&2
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

ai_reviewer() {
  _ai reviewer "$@"
}

ai_oracle() {
  _ai oracle "$@"
}

ai_explore() {
  _ai explore "$@"
}

ai_quick_task() {
  _ai quick_task "$@"
}

# Optional quick commands:
#   spark       -> aispark
#   high        -> ai_high
#   xhigh       -> ai_xhigh
#   reviewer    -> ai_reviewer
#   oracle      -> ai_oracle
#   explore     -> ai_explore
#   quick_task  -> ai_quick_task
alias spark='aispark'
alias high='ai_high'
alias xhigh='ai_xhigh'
alias reviewer='ai_reviewer'
alias oracle='ai_oracle'
alias explore='ai_explore'
alias quick_task='ai_quick_task'
