{ pkgs, ... }:

{
  home.packages = with pkgs; [
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
    nodejs
    lua-language-server
    stylua
    odin
    ols
    wayland-scanner
  ];
}
