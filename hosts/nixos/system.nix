{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "winboot";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.efibootmgr
        pkgs.gnused
        pkgs.systemd
      ];
      text = ''
        if [[ "$(id -u)" -ne 0 ]]; then
          echo "winboot must be run as root: sudo winboot" >&2
          exit 1
        fi

        boot_number="$(efibootmgr | sed -n \
          's/^Boot\([0-9A-Fa-f]\{4\}\)\** Windows Boot Manager.*/\1/p' | head -n 1)"

        if [[ -z "$boot_number" ]]; then
          echo "No 'Windows Boot Manager' UEFI entry was found." >&2
          exit 1
        fi

        efibootmgr --bootnext "$boot_number"
        systemctl reboot
      '';
    })
  ];

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  zramSwap.enable = true;

  # Keep this at the release used for the initial installation.
  system.stateVersion = "26.05";
}
