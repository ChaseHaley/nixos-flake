{ pkgs, ... }:

let
  fedoraShim = import ./fedora-shim.nix { inherit pkgs; };

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
}
