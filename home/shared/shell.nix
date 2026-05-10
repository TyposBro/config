{ ... }:

{
  # Fish shell — common config and aliases
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      fnm env --use-on-cd --shell fish | source
      # JAVA_HOME — macOS: system Java, Linux: Android Studio bundled JDK
      if test -x /usr/libexec/java_home
        set -gx JAVA_HOME (/usr/libexec/java_home -v 17 2>/dev/null)
      else if test -d ~/.local/share/JetBrains/Toolbox/apps/android-studio/jbr
        set -gx JAVA_HOME ~/.local/share/JetBrains/Toolbox/apps/android-studio/jbr
      end

      # Keep pi-lens state and cache under ~/.agents
      set -gx PILENS_DATA_DIR "$HOME/.agents/pi-lens/projects"

      # GitHub token for Nix flake fetches (avoids API rate limits)
      if command -q gh
        set -gx NIX_CONFIG "access-tokens = github.com=$(gh auth token 2>/dev/null)"
      end
    '';
    shellAliases = {
      # System
      ll  = "ls -la";
      la  = "ls -la";

      # Git
      gs  = "git status";
      ga  = "git add";
      gc  = "git commit";
      gca = "git commit --amend";
      gp  = "git push";
      gpl = "git pull";
      gd  = "git diff";
      gl  = "git log --oneline --graph --decorate";

      # Nix cleanup
      ngc = "sudo nix-collect-garbage -d";
      nopt = "sudo nix-store --optimise";

      # config repo dir
      ncd = "cd ~/config";

      # React Native / Expo
      exs  = "npx expo start";
      exc  = "npx expo start --clear";
      expa = "npx expo run:android";
      expi = "npx expo run:ios";
    };
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };

  # Ghostty terminal (shared config — works on Linux and macOS)
  xdg.configFile."ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    font-size = 17
    theme = Catppuccin Mocha
    background-opacity = 0.9
    cursor-style = bar
    shell-integration = fish
    window-decoration = true
    macos-titlebar-style = tabs
    command = /run/current-system/sw/bin/fish
  '';
}
