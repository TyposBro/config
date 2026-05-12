if status is-interactive
    # Homebrew
    eval (/opt/homebrew/bin/brew shellenv)

    set -U fish_greeting ""

    # Tools
    starship init fish | source
    fnm env --use-on-cd --shell fish | source

    # PATH additions
    fish_add_path $HOME/.bun/bin
    fish_add_path $HOME/.opencode/bin
    fish_add_path $HOME/.cargo/bin

    # Env
    set -gx BUN_INSTALL $HOME/.bun
    set -gx ANDROID_HOME $HOME/Library/Android/sdk
    set -gx JAVA_HOME (/usr/libexec/java_home -v 17 2>/dev/null)
    set -gx HOMEBREW_CASK_OPTS --no-quarantine
    # Keep pi-lens data under ~/.agents
    set -gx PILENS_DATA_DIR "$HOME/.agents/pi-lens/projects"

    # Aliases
    alias ll "ls -la"
    alias la "ls -la"
    alias gs "git status"
    alias ga "git add"
    alias gc "git commit"
    alias gca "git commit --amend"
    alias gp "git push"
    alias gpl "git pull"
    alias gd "git diff"
    alias gl "git log --oneline --graph --decorate"
    alias ncd "cd ~/config"
    alias exs "npx expo start"
    alias exc "npx expo start --clear"
    alias expa "npx expo run:android"
    alias expi "npx expo run:ios"

    # Shared model shortcuts for AI CLIs (pi / codex / opencode / claude)
    set -l pi_model_shortcuts "$HOME/config/pi/shell/model-shortcuts.fish"
    if test -f "$pi_model_shortcuts"
        source "$pi_model_shortcuts"
    end

    function cli --description "Run Codex in bypass mode with shorthand for resume/fork last"
        set -l base_args --dangerously-bypass-approvals-and-sandbox

        if test (count $argv) -ge 2
            if test "$argv[1]" = "resume" -a "$argv[2]" = "last"
                command codex $base_args resume --last $argv[3..-1]
                return $status
            else if test "$argv[1]" = "fork" -a "$argv[2]" = "last"
                command codex $base_args fork --last $argv[3..-1]
                return $status
            end
        end

        command codex $base_args $argv
    end

    function picli --description "Run pi with shorthand for last-session continue"
        if test (count $argv) -ge 2
            if test "$argv[1]" = "resume" -a "$argv[2]" = "last"
                command pi --continue $argv[3..-1]
                return $status
            else if test "$argv[1]" = "resume"
                command pi --resume $argv[2..-1]
                return $status
            end
        end

        command pi $argv
    end

    function ocli --description "Run opencode in skip-permissions mode with shorthand for resume/fork last"
        set -l base_args --dangerously-skip-permissions

        if test (count $argv) -ge 2
            if test "$argv[1]" = "resume" -a "$argv[2]" = "last"
                command opencode $base_args --continue $argv[3..-1]
                return $status
            else if test "$argv[1]" = "fork" -a "$argv[2]" = "last"
                command opencode $base_args --continue --fork $argv[3..-1]
                return $status
            end
        end

        command opencode $base_args $argv
    end
end
