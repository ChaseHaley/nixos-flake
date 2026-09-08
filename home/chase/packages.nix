{ pkgs, ... }:

{
  home.packages = with pkgs; [
    codex
    grim
    kdePackages.dolphin
    kitty
    neovim
    pavucontrol
    slurp
    vivaldi
    vivaldi-ffmpeg-codecs
    wget
    wl-clipboard
    bitwarden-desktop
    github-cli
    ripgrep
    fd
    fzf
    zoxide
    nix-diff
    vesktop
    tlrc
    btop
    unzip
    spotify
    vlc
    yazi
  ];
}
