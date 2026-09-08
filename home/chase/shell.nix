{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      nrs = "sudo nixos-rebuild switch --flake $HOME/.config/flake/#$(hostname)";
      nrd = "sudo nixos-rebuild dry-build --flake $HOME/.config/flake/#$(hostname)";
    };

    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "zoxide" ];
    };
  };

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    settings.theme = "dankcolors";
  };
}
