{
  description = "Determinate";

  inputs = {
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix-src/*";
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";

    determinate-nixd-aarch64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/tag/v3.17.3/aarch64-linux";
      flake = false;
    };
    determinate-nixd-x86_64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/tag/v3.17.3/x86_64-linux";
      flake = false;
    };
    determinate-nixd-aarch64-darwin = {
      url = "https://install.determinate.systems/determinate-nixd/tag/v3.17.3/macOS";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
              };
            };
          }
        );
    in
    {
      packages = forEachSupportedSystem (
        { system, pkgs, ... }:
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "determinate-nixd";
            inherit (inputs.nix.packages.${system}.default) version;

            src = inputs."determinate-nixd-${system}";
            dontUnpack = true;

            installPhase = ''
              mkdir -p $out/bin
              cp $src $out/bin/determinate-nixd
              chmod +x $out/bin/determinate-nixd
            '';

            doInstallCheck = true;
            installCheckPhase = ''
              $out/bin/determinate-nixd --help
            '';
          };
        }
      );

      devShells = forEachSupportedSystem (
        { system, pkgs, ... }:
        {
          default = pkgs.mkShell {
            name = "determinate-dev";

            packages = with pkgs; [
              self.formatter.${system}
            ];
          };
        }
      );

      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt);

      darwinModules = {
        default = ./modules/nix-darwin/default.nix;

        # In case we come across anyone who still needs to migrate
        migration = ./modules/nix-darwin/migration.nix;
      };

      homeManagerModules.default = ./modules/home-manager/default.nix;

      nixosModules.default = import ./modules/nixos.nix inputs;
    };
}
