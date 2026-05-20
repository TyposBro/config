if status is-interactive
    set -U fish_greeting ""

    # PATH additions (must come before tools that depend on them)
    fish_add_path $HOME/.local/bin
    fish_add_path $HOME/.local/share/fnm
    fish_add_path $HOME/.bun/bin
    fish_add_path $HOME/.opencode/bin
    fish_add_path $HOME/.cargo/bin
    fish_add_path $HOME/.deno/bin
    fish_add_path $HOME/Android/Sdk/platform-tools
    fish_add_path $HOME/Android/Sdk/emulator
    fish_add_path $HOME/Android/Sdk/cmdline-tools/latest/bin

    # Tools
    if command -q starship
        starship init fish | source
    end
    if command -q fnm
        fnm env --use-on-cd --shell fish | source
    end

    # Env
    set -gx BUN_INSTALL $HOME/.bun
    set -gx ANDROID_HOME $HOME/Android/Sdk
    if test -d $HOME/.local/jdks/jdk-21
        set -gx JAVA_HOME $HOME/.local/jdks/jdk-21
        fish_add_path $JAVA_HOME/bin
    end
    if test -d /snap/android-studio/current/android-studio/jbr
        set -gx JAVA_HOME /snap/android-studio/current/android-studio/jbr
    end

    # GitHub token for any tooling that wants it
    if command -q gh
        set -gx GH_TOKEN (gh auth token 2>/dev/null)
    end

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

    function __agent_memory_register --description "Register current project for agent-memory"
        set -l register_script "$HOME/agent-memory/register-project.sh"
        if test -x "$register_script"
            bash "$register_script" --cwd "$PWD" --quiet >/dev/null 2>/dev/null
        end
    end

    function claude --description "Claude wrapper with agent-memory sync"
        __agent_memory_register
        command claude $argv
    end

    function codex --description "Codex wrapper with agent-memory sync"
        __agent_memory_register
        command codex $argv
    end

    function opencode --description "OpenCode wrapper with agent-memory sync"
        __agent_memory_register
        command opencode $argv
    end

    function gemini --description "Gemini wrapper with agent-memory sync"
        __agent_memory_register
        command gemini $argv
    end

    function oc --description "OpenCode wrapper"
        __agent_memory_register
        if test (count $argv) -gt 0
            switch $argv[1]
                case resume
                    if test (count $argv) -gt 1
                        opencode --session $argv[2] $argv[3..-1]
                    else
                        opencode --continue
                    end
                    return
                case run
                    opencode run --dangerously-skip-permissions $argv[2..-1]
                    return
            end
        end
        opencode $argv
    end

    function cli --description "Codex with yolo + sudo"
        __agent_memory_register
        codex --yolo --config allow_login_shell=true $argv
    end

    function cc --description "Claude Code with yolo + sudo"
        __agent_memory_register
        if test (count $argv) -gt 0
            switch $argv[1]
                case resume
                    if test (count $argv) -gt 1
                        claude --dangerously-skip-permissions --permission-mode bypassPermissions --resume $argv[2..-1]
                    else
                        claude --dangerously-skip-permissions --permission-mode bypassPermissions --continue
                    end
                    return
            end
        end
        claude --dangerously-skip-permissions --permission-mode bypassPermissions $argv
    end

    # Kubuntu helpers
    alias upd "sudo apt update && sudo apt upgrade"
    alias kreboot "systemctl reboot"
end
