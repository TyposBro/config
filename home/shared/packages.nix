{ pkgs, pkgs-unstable, ... }:

{
  home.packages = with pkgs; [
    # Editor (vscode managed by programs.vscode in vscode.nix)
    claude-code          # from overlay — always latest
    pkgs-unstable.opencode

    # Dev tools
    nodejs
    deno
    gradle
    python3
    ruby
    git-lfs
    git-filter-repo

    # Rust (toolchain managed by rustup)
    rustup

    # React Native
    bun
    pkgs-unstable.watchman
    nodePackages.typescript
    nodePackages.typescript-language-server # LSP for TS (expo/arbee/spiko) — xd://lsp

    # LSP / AST / DAP — for omp/opencode/codex harnesses
    pyright                                 # LSP for Python (feelflow/backend)
    ast-grep                                # AST codemods (xd://ast_edit — sg)
    python3Packages.debugpy                 # DAP adapter for Python (xd://debug)

    # Media
    mpv
    tesseract

    # Cloud
    awscli2
    cloudflared
    google-cloud-sdk
    pkgs-unstable.infisical
    terraform
    opentofu

    # CLI tools
    aria2
    cloc
    fzf
    htop
    lazygit
    rename
    tectonic
    tmux

    # Utils
    btop
    unzip
    jq

    # GUI
    postman
    obsidian
    qbittorrent
    ghostty
    discord
    bitwarden-desktop
    spotify
    telegram-desktop
  ];
}
