{ pkgs, ... }:

let
  fedoraShim = import ../../secure-boot/fedora-shim.nix { inherit pkgs; };
  shimStage = pkgs.writeShellScript "stage-nixos-shim" ''
    set -euo pipefail

    destination=/boot/EFI/NixOS-shim
    loader=/boot/EFI/systemd/systemd-bootx64.efi
    certificate=/var/lib/shim-mok/keys/db/db.pem

    test -f "$loader"
    test -f "$certificate"
    ${pkgs.sbsigntool}/bin/sbverify --cert "$certificate" "$loader"

    ${pkgs.coreutils}/bin/install -d -m 0700 "$destination"
    ${pkgs.coreutils}/bin/install -m 0644 ${fedoraShim}/shimx64.efi "$destination/shimx64.efi"
    ${pkgs.coreutils}/bin/install -m 0644 ${fedoraShim}/mmx64.efi "$destination/mmx64.efi"
    ${pkgs.coreutils}/bin/install -m 0644 ${fedoraShim}/fbx64.efi "$destination/fbx64.efi"
    ${pkgs.coreutils}/bin/install -m 0644 "$loader" "$destination/grubx64.efi"

    ${pkgs.sbsigntool}/bin/sbverify --cert "$certificate" "$destination/grubx64.efi"
  '';
in
{
  imports = [ ./hardware-configuration.nix ];

  boot = {
    kernelPackages = pkgs.linuxPackages_7_1;
    # Lanzaboote signs the NixOS loader and generation artifacts with the shim
    # MOK. It must never enroll this key into the firmware databases.
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/shim-mok";
      autoGenerateKeys.enable = false;
      autoEnrollKeys.enable = false;
    };
    loader = {
      systemd-boot.enable = false;
      efi.canTouchEfiVariables = true;
    };
  };

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

  # Keep shim's conventionally named second stage synchronized with the
  # MOK-signed systemd-boot binary produced by Lanzaboote.
  systemd.services.stage-nixos-shim = {
    description = "Stage Microsoft-signed shim and MOK-signed NixOS loader";
    wantedBy = [ "multi-user.target" ];
    after = [ "boot.mount" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = shimStage;
    };
  };

  systemd.paths.stage-nixos-shim = {
    description = "Watch for MOK-signed NixOS loader updates";
    wantedBy = [ "paths.target" ];
    pathConfig.PathChanged = "/boot/EFI/systemd/systemd-bootx64.efi";
  };

  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
  };

  time.timeZone = "America/Chicago";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  services.xserver = {
    xkb = {
      layout = "us";
      variant = "";
    };
    videoDrivers = [ "nvidia" ];
  };

  users.users.chase = {
    isNormalUser = true;
    description = "Chase";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaSettings = true;
    };
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  programs.steam = {
    enable = true;
    protontricks = {
      enable = true;
    };
  };

  programs.gamescope = {
    enable = true;
  };

  programs.zsh.enable = true;

  zramSwap.enable = true;

  # Keep this at the release used for the initial installation.
  system.stateVersion = "26.05";
}
