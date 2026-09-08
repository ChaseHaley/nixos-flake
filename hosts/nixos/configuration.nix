{
  imports = [
    ./hardware-configuration.nix
    ./desktop.nix
    ./networking.nix
    ./system.nix
    ./users.nix
    ../../secure-boot/nixos.nix
  ];
}
