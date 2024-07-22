{
  description = "";

  inputs = {
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/0.1";
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix/2.0";
  };

  outputs = { self, nixpkgs, ... } @ inputs:
    let
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      version = "${builtins.substring 0 8 lastModifiedDate}-${self.shortRev or "dirty"}";

      pkgsFor = system: import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };

      supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        inherit system;
        pkgs = pkgsFor system;
        lib = nixpkgs.lib;
      });
    in
    {
      packages = forAllSystems ({ system, pkgs, ... }: { });

      devShells = forAllSystems ({ system, pkgs, ... }:
        {
          default = pkgs.mkShell {
            name = "determinate-dev";

            buildInputs = with pkgs; [
              nixpkgs-fmt
            ];
          };
        });

      darwinModules.default = { lib, config, pkgs, ... }: {
        imports = [
          inputs.nix.darwinModules.default
        ];


        options = {
          determinate.nix.primaryUser = lib.mkOption {
            type = lib.types.str;
          };

          determinate.nix.primaryUserNetrc = lib.mkOption {
            type = lib.types.str;
            default =
              let
                unprivUserLocation = (if pkgs.stdenv.isDarwin then "/Users/" else "/home/") + config.determinate.nix.primaryUser;
                rootLocation = if pkgs.stdenv.isDarwin then "/var/root" else "/root";
              in
              if config.determinate.nix.primaryUser == "root" then rootLocation else unprivUserLocation;
          };
        };

        config = {
          environment.systemPackages = [
            inputs.fh.packages."${pkgs.stdenv.system}".default
          ];

          nix.settings = {
            netrc-file = config.determinate.nix.primaryUserNetrc;
            extra-substituters = [ "https://cache.flakehub.com" ];
            extra-trusted-public-keys = [
              "cache.flakehub.com-1:t6986ugxCA+d/ZF9IeMzJkyqi5mDhvFIx7KA/ipulzE="
              "cache.flakehub.com-2:ntBGiaKSmygJOw2j1hFS7KDlUHQWmZALvSJ9PxMJJYU="
            ];
          };
        };
      };


      nixosModules.default = { lib, pkgs, config, ... }: {
        imports = [
          inputs.nix.nixosModules.default
        ];

        options = {
          determinate.nix.primaryUser = lib.mkOption {
            type = lib.types.str;
          };

          determinate.nix.primaryUserNetrc = lib.mkOption {
            type = lib.types.str;
            default =
              let
                unprivUserLocation = (if pkgs.stdenv.isDarwin then "/Users/" else "/home/") + config.determinate.nix.primaryUser;
                rootLocation = if pkgs.stdenv.isDarwin then "/var/root" else "/root";
              in
              if config.determinate.nix.primaryUser == "root" then rootLocation else unprivUserLocation;
          };
        };

        config = {
          environment.systemPackages = [
            inputs.fh.packages."${pkgs.stdenv.system}".default
          ];

          nix.settings = {
            netrc-file = config.determinate.nix.primaryUserNetrc;
            extra-substituters = [ "https://cache.flakehub.com" ];
            extra-trusted-public-keys = [
              "cache.flakehub.com-1:t6986ugxCA+d/ZF9IeMzJkyqi5mDhvFIx7KA/ipulzE="
              "cache.flakehub.com-2:ntBGiaKSmygJOw2j1hFS7KDlUHQWmZALvSJ9PxMJJYU="
            ];
          };
        };
      };
    };
}
