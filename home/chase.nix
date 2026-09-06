{ pkgs, ... }:

{
  home = {
    username = "chase";
    homeDirectory = "/home/chase";

    # Existing user-facing packages migrated from environment.systemPackages.
    packages = with pkgs; [
      codex
      grim
      hypridle
      hyprlauncher
      hyprlock
      hyprpaper
      kdePackages.dolphin
      kitty
      mako
      neovim
      pavucontrol
      slurp
      vivaldi
      waybar
      wget
      wl-clipboard
      bitwarden-desktop
      github-cli
      ripgrep
      fd
      fzf
      nix-diff
      tree-sitter
      clang
      zig
      meson
      ninja
      cargo
      rust-analyzer
      clippy
      rustfmt
      pkg-config
      nixd
      hyprlandPlugins.hy3
      vesktop
      tlrc
    ];

    # Keep this at the first Home Manager version used for this account.
    stateVersion = "26.05";
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings.user = {
      name = "Chase Haley";
      email = "chasehaley33@gmail.com";
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    oh-my-zsh = {
      enable = true;
    };
  };

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.home-manager.enable = true;
}
