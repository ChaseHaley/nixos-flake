{ pkgs }:

let
  program = pkgs.writeShellApplication {
    name = "test-shim-boot";
    runtimeInputs = [
      pkgs.efibootmgr
      pkgs.gawk
      pkgs.util-linux
    ];
    text = ''
      if [[ "$(id -u)" -ne 0 ]]; then
        echo "Run this command as root." >&2
        exit 1
      fi

      shim=/boot/EFI/NixOS-shim/shimx64.efi
      [[ -f "$shim" ]] || {
        echo "The staged shim does not exist at $shim" >&2
        exit 1
      }

      esp="$(findmnt --noheadings --output SOURCE --target /boot)"
      disk_name="$(lsblk --noheadings --output PKNAME "$esp" | awk '{ print $1; exit }')"
      partition="$(lsblk --noheadings --output PARTN "$esp" | awk '{ print $1; exit }')"
      [[ -n "$disk_name" && -n "$partition" ]] || {
        echo "Could not resolve the disk and partition mounted at /boot" >&2
        exit 1
      }

      boot_number="$(efibootmgr | awk '
        index($0, "NixOS") && substr($1, 1, 4) == "Boot" {
          print substr($1, 5, 4)
          exit
        }
      ')"

      if [[ -z "$boot_number" ]]; then
        efibootmgr --create-only \
          --disk "/dev/$disk_name" \
          --part "$partition" \
          --label "NixOS" \
          --loader '\EFI\NixOS-shim\shimx64.efi'
        boot_number="$(efibootmgr | awk '
          index($0, "NixOS") && substr($1, 1, 4) == "Boot" {
            print substr($1, 5, 4)
            exit
          }
        ')"
      fi

      [[ -n "$boot_number" ]] || {
        echo "The test entry was not found after creation." >&2
        exit 1
      }

      efibootmgr --bootnext "$boot_number"
      echo "Set BootNext to NixOS (Boot$boot_number)."
      echo "The persistent BootOrder was not changed. Reboot when ready."
    '';
  };
in
{
  type = "app";
  program = "${program}/bin/test-shim-boot";
  meta.description = "Create and select a one-shot NixOS shim test entry";
}
