{
  imports = [
    ./packages.nix
    ./development.nix
    ./git.nix
    ./shell.nix
    ./desktop.nix
  ];

  home = {
    username = "chase";
    homeDirectory = "/home/chase";

    # Keep this at the first Home Manager version used for this account.
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
