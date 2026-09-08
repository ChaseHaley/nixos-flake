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

    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      lanzaboote,
      dms,
      dank-greeter,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system}.fedora-shim = import ./secure-boot/fedora-shim.nix { inherit pkgs; };

      apps.${system} = {
        create-shim-mok = import ./secure-boot/create-shim-mok-app.nix { inherit pkgs; };
        test-shim-boot = import ./secure-boot/test-shim-boot-app.nix { inherit pkgs; };
      };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/nixos/configuration.nix
          lanzaboote.nixosModules.lanzaboote
          dank-greeter.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.chase = {
              imports = [
                dms.homeModules.dank-material-shell
                ./home/chase
              ];
            };
          }
        ];
      };
    };
}
