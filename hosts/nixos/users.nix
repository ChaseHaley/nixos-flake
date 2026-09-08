{ pkgs, ... }:

{
  users.users.chase = {
    isNormalUser = true;
    description = "Chase";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  programs.zsh.enable = true;
}
