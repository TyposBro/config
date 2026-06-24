# Shared model shortcut helpers for fish shell.
# Source this file (or keep it autoloaded) to enable:
#   aispark [cli] [...]
#   ai_high [cli] [...]
#   ai_xhigh [cli] [...]
#   ai_reviewer [cli] [...]
#   ai_oracle [cli] [...]
#   ai_explore [cli] [...]
#   ai_quick_task [cli] [...]
#
# Supported cli targets: pi, claude

function __ai_profile_for_name
	set -l name "$argv[1]"
	switch "$name"
		case spark
			printf "%s\n%s\n%s\n" "gpt-5.3-codex-spark" "medium" "openai-codex"
		case high
			printf "%s\n%s\n%s\n" "gpt-5.5" "high" "openai-codex"
		case xhigh reviewer oracle
			printf "%s\n%s\n%s\n" "gpt-5.5" "xhigh" "openai-codex"
		case explore
			printf "%s\n%s\n%s\n" "gemini-3.1-pro-preview" "high" "google"
		case quick_task
			printf "%s\n%s\n%s\n" "deepseek-v4-pro" "medium" "deepseek"
		case '*'
			return 1
	end
end

function __ai_with_profile
	set -l profile "$argv[1]"
	set -e argv[1]
	set -l cli "pi"

	if test (count $argv) -ge 1
		switch "$argv[1]"
			case pi claude
				set cli "$argv[1]"
				set -e argv[1]
		end
	end

	set -l profile_values (__ai_profile_for_name "$profile")
	if test -z "$profile_values"
		echo "Unknown profile: $profile" >&2
		return 1
	end

	set -l model "$profile_values[1]"
	set -l thinking "$profile_values[2]"
	set -l provider "$profile_values[3]"

	switch "$cli"
		case pi
			set -l pi_args --model "$model" --thinking "$thinking"
			if test "$provider" != openai-codex
				set pi_args --provider "$provider" $pi_args
			end
			command pi $pi_args $argv
		case claude
			command claude --model "$model" $argv
		case '*'
			echo "Unsupported cli target: $cli (expected pi|claude)" >&2
			return 1
	end
end

function aispark
	__ai_with_profile spark $argv
end

function ai_high
	__ai_with_profile high $argv
end

function ai_xhigh
	__ai_with_profile xhigh $argv
end

function ai_reviewer
	__ai_with_profile reviewer $argv
end

function ai_oracle
	__ai_with_profile oracle $argv
end

function ai_explore
	__ai_with_profile explore $argv
end

function ai_quick_task
	__ai_with_profile quick_task $argv
end

# Optional quick short names.
alias spark 'aispark'
alias high 'ai_high'
alias xhigh 'ai_xhigh'
alias reviewer 'ai_reviewer'
alias oracle 'ai_oracle'
alias explore 'ai_explore'
alias quick_task 'ai_quick_task'
