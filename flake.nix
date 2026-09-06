{
  description = "Chase's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, lanzaboote, ... }:
    {
      packages.x86_64-linux.fedora-shim =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        import ./secure-boot/fedora-shim.nix { inherit pkgs; };

      apps.x86_64-linux.create-shim-mok =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          program = pkgs.writeShellApplication {
            name = "create-shim-mok";
            runtimeInputs = [ pkgs.openssl ];
            text = ''
              set -o noclobber

              if [[ "$(id -u)" -ne 0 ]]; then
                echo "Run this command as root." >&2
                exit 1
              fi

              key_dir=/var/lib/shim-mok/keys/db
              if [[ -e "$key_dir/db.key" || -e "$key_dir/db.pem" || -e "$key_dir/db.der" ]]; then
                echo "Refusing to replace an existing shim MOK in $key_dir" >&2
                exit 1
              fi

              install -d -m 0700 "$key_dir"
              openssl req -new -x509 -newkey rsa:4096 -sha256 -nodes \
                -subj "/CN=Chase NixOS Shim MOK/" \
                -addext "basicConstraints=critical,CA:FALSE" \
                -addext "keyUsage=critical,digitalSignature" \
                -addext "extendedKeyUsage=codeSigning" \
                -days 3650 \
                -keyout "$key_dir/db.key" \
                -out "$key_dir/db.pem"
              openssl x509 -in "$key_dir/db.pem" -outform DER -out "$key_dir/db.der"
              chmod 0600 "$key_dir/db.key"
              chmod 0644 "$key_dir/db.pem" "$key_dir/db.der"

              echo "Created the signing key and MOK certificate in $key_dir"
              echo "No firmware or MOK variables were changed."
            '';
          };
        in
        {
          type = "app";
          program = "${program}/bin/create-shim-mok";
          meta.description = "Create the local NixOS signing key for shim MOK enrollment";
        };

      apps.x86_64-linux.test-shim-boot =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
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
        };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/nixos/configuration.nix
          lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.chase = import ./home/chase.nix;
          }
        ];
      };
    };
}
