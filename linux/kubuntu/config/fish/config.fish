set -gx PI_CONFIG_DIR .omp

if status is-interactive
    set -U fish_greeting ""

    # PATH additions (must come before tools that depend on them)
    fish_add_path $HOME/.local/bin
    fish_add_path $HOME/.local/share/fnm
    fish_add_path $HOME/.bun/bin
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

    function cc --description "Claude Code with yolo + sudo"
        if test (count $argv) -gt 0
            switch $argv[1]
                case resume
                    if test (count $argv) -gt 1
                        command claude --dangerously-skip-permissions --permission-mode bypassPermissions --resume $argv[2..-1]
                    else
                        command claude --dangerously-skip-permissions --permission-mode bypassPermissions --continue
                    end
                    return
            end
        end
        command claude --dangerously-skip-permissions --permission-mode bypassPermissions $argv
    end

    # Kubuntu helpers
    alias upd "sudo apt update && sudo apt upgrade"
    alias kreboot "systemctl reboot"
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /home/typosbro/miniconda3/bin/conda
    eval /home/typosbro/miniconda3/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "/home/typosbro/miniconda3/etc/fish/conf.d/conda.fish"
        . "/home/typosbro/miniconda3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/home/typosbro/miniconda3/bin" $PATH
    end
end
# <<< conda initialize <<<

