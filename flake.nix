{
  description = "Determinate";

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

      homeManagerModules.default = { lib, config, pkgs, ... }: {
        imports = [
          inputs.nix.homeManagerModules.default
        ];

        options = {
          determinate.nix.primaryUser.username = lib.mkOption {
            type = lib.types.str;
            description = "The Determinate Nix user";
          };

          determinate.nix.primaryUser.netrcPath = lib.mkOption {
            type = lib.types.path;
            description = "The path to the `netrc` file for the user configured by `primaryUser`";
            default = "${if pkgs.stdenv.isDarwin then "/Users" else "/home"}/${config.determinate.nix.primaryUser.username}/.local/share/flakehub/netrc";
          };

          determinate.nix.primaryUser.isTrusted = lib.mkOption {
            type = lib.types.bool;
            description = "Whether the Determinate Nix user is a trusted user";
            default = config.determinate.nix.primaryUser.username == "root";
          };
        };

        config = {
          home.packages = [
            inputs.fh.packages."${pkgs.stdenv.system}".default
          ];

          # The `netrc-file` and `extra-trusted-public-keys` settings are privileged and so
          # they're applied only if `primaryUser.isTrusted` is set to `true`
          nix.settings = lib.mkMerge [
            (lib.optionalAttrs (config.determinate.nix.primaryUser.isTrusted) {
              extra-trusted-public-keys = [
                "cache.flakehub.com-1:t6986ugxCA+d/ZF9IeMzJkyqi5mDhvFIx7KA/ipulzE="
                "cache.flakehub.com-2:ntBGiaKSmygJOw2j1hFS7KDlUHQWmZALvSJ9PxMJJYU="
              ];
            })
            {
              netrc-file = config.determinate.nix.primaryUser.netrcPath;
              extra-substituters = [ "https://cache.flakehub.com" ];
            }
          ];
        };
      };


      darwinModules.default = { lib, config, pkgs, ... }: {
        imports = [
          inputs.nix.darwinModules.default
        ];

        options = {
          determinate.nix.primaryUser.username = lib.mkOption {
            type = lib.types.str;
            description = "The Determinate Nix user";
          };

          determinate.nix.primaryUser.netrcPath = lib.mkOption {
            type = lib.types.path;
            description = "The path to the `netrc` file for the user configured by `primaryUser`";
            default = "/Users/${config.determinate.nix.primaryUser.username}/.local/share/flakehub/netrc";
          };
        };

        config = {
          environment.systemPackages = [
            inputs.fh.packages."${pkgs.stdenv.system}".default
          ];

          nix.settings = {
            netrc-file = config.determinate.nix.primaryUser.netrcPath;
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
          determinate.nix.primaryUser.username = lib.mkOption {
            type = lib.types.str;
            description = "The Determinate Nix user";
          };

          determinate.nix.primaryUser.netrcPath = lib.mkOption {
            type = lib.types.path;
            description = "The path to the `netrc` file for the user configured by `primaryUser`";
            default = "/home/${config.determinate.nix.primaryUser.username}/.local/share/flakehub/netrc";
          };
        };

        config = {
          environment.systemPackages = [
            inputs.fh.packages."${pkgs.stdenv.system}".default
          ];

          nix.settings = {
            netrc-file = config.determinate.nix.primaryUser.netrcPath;
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
