# Shared model shortcut helpers for fish shell.
# Source this file (or keep it autoloaded) to enable:
#   aispark [cli] [...]
#   ai_high [cli] [...]
#   ai_xhigh [cli] [...]
#
# Supported cli targets: pi, codex, opencode, claude

function __ai_profile_for_name
	set -l name "$argv[1]"
	switch "$name"
		case spark
			printf "%s\n%s\n" "gpt-5.3-codex-spark" "medium"
		case high
			printf "%s\n%s\n" "gpt-5.5" "high"
		case xhigh
			printf "%s\n%s\n" "gpt-5.5" "xhigh"
		case '*'
			return 1
	end
end

function __ai_with_profile
	set -l profile "$argv[1]"
	set -l cli "pi"

	if test (count $argv) -ge 2
		set cli "$argv[2]"
		set argv $argv[3..-1]
	end

	set -l profile_values (__ai_profile_for_name "$profile")
	if test -z "$profile_values"
		echo "Unknown profile: $profile" >&2
		return 1
	end

	set -l model "$profile_values[1]"
	set -l thinking "$profile_values[2]"

	switch "$cli"
		case pi
			command pi --provider openai-codex --model "$model" --thinking "$thinking" $argv
		case codex
			command codex --model "$model" $argv
		case opencode
			command opencode --model "$model" $argv
		case claude
			command claude --model "$model" $argv
		case '*'
			echo "Unsupported cli target: $cli (expected pi|codex|opencode|claude)" >&2
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

# Optional quick short names.
alias spark 'aispark'
alias high 'ai_high'
alias xhigh 'ai_xhigh'
