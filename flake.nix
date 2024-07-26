{
  description = "Determinate";

  inputs = {
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/0.1";
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix/2.0";
    nixpkgs.follows = "fh/nixpkgs";

    determinate-nixd-aarch64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/rev/87e416024f6e7203748aebc25862ddf17efb428e/aarch64-linux";
      flake = false;
    };
    determinate-nixd-x86_64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/rev/87e416024f6e7203748aebc25862ddf17efb428e/x86_64-linux";
      flake = false;
    };
    determinate-nixd-aarch64-darwin = {
      url = "https://install.determinate.systems/determinate-nixd/rev/87e416024f6e7203748aebc25862ddf17efb428e/aarch64-darwin";
      flake = false;
    };
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
      packages = forAllSystems ({ system, pkgs, ... }: {
        default = pkgs.runCommand "determinate-nixd" { } ''
          mkdir -p $out/bin
          cp ${inputs."determinate-nixd-${system}"} $out/bin/determinate-nixd
          chmod +x $out/bin/determinate-nixd
          $out/bin/determinate-nixd --help
        '';
      });

      devShells = forAllSystems ({ system, pkgs, ... }:
        {
          default = pkgs.mkShell {
            name = "determinate-dev";

            buildInputs = with pkgs; [
              nixpkgs-fmt
            ];
          };
        });

      homeModules.default = { lib, config, pkgs, ... }: {
        options = {
          determinate.nix.primaryUser.username = lib.mkOption {
            type = lib.types.str;
            description = "The Determinate Nix user";
            default = config.home.username;
          };

          determinate.nix.primaryUser.netrcPath = lib.mkOption {
            type = lib.types.path;
            description = "The path to the `netrc` file for the user configured by `primaryUser`";
            default =
              let
                unprivUserLocation = "${if pkgs.stdenv.isDarwin then "/Users" else "/home"}/${config.determinate.nix.primaryUser.username}";
                rootLocation = if pkgs.stdenv.isDarwin then "/var/root" else "/root";
                netrcRoot = if config.determinate.nix.primaryUser.username == "root" then rootLocation else unprivUserLocation;
              in
              "${netrcRoot}/.local/share/flakehub/netrc";
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

          nix.package = inputs.nix.packages."${pkgs.stdenv.system}".default;


          nix.registry.nixpkgs = {
            exact = true;
            from = {
              type = "indirect";
              id = "nixpkgs";
            };
            to = {
              type = "tarball";
              url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1.0.tar.gz";
            };
          };

          # The `netrc-file` and `extra-trusted-public-keys` settings are privileged and so
          # they're applied only if `primaryUser.isTrusted` is set to `true`
          nix.settings = lib.mkMerge [
            (lib.optionalAttrs (config.determinate.nix.primaryUser.isTrusted) {
              always-allow-substitutes = true;
              extra-trusted-public-keys = [
                "cache.flakehub.com-1:t6986ugxCA+d/ZF9IeMzJkyqi5mDhvFIx7KA/ipulzE="
                "cache.flakehub.com-2:ntBGiaKSmygJOw2j1hFS7KDlUHQWmZALvSJ9PxMJJYU="
              ];
              netrc-file = config.determinate.nix.primaryUser.netrcPath;
              upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";
            })
            {
              bash-prompt-prefix = "(nix:$name)\\040";
              experimental-features = [ "nix-command" "flakes" ];
              extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
              extra-substituters = [ "https://cache.flakehub.com" ];
            }
          ];
        };
      };

      darwinModules.default = { lib, config, pkgs, ... }: {
        options = {
          determinate.nix.primaryUser.username = lib.mkOption {
            type = lib.types.str;
            description = "The Determinate Nix user";
          };

          determinate.nix.primaryUser.netrcPath = lib.mkOption {
            type = lib.types.path;
            description = "The path to the `netrc` file for the user configured by `primaryUser`";
            default =
              let
                netrcRoot =
                  if config.determinate.nix.primaryUser.username == "root"
                  then "/var/root"
                  else "/Users/${config.determinate.nix.primaryUser.username}";
              in
              "${netrcRoot}/.local/share/flakehub/netrc";
          };
        };

        config = {
          environment.systemPackages = [
            inputs.fh.packages."${pkgs.stdenv.system}".default
          ];

          services.nix-daemon.enable = true;

          nix.package = inputs.nix.packages."${pkgs.stdenv.system}".default;

          nix.registry.nixpkgs = {
            exact = true;
            from = {
              type = "indirect";
              id = "nixpkgs";
            };
            to = {
              type = "tarball";
              url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1.0.tar.gz";
            };
          };

          launchd.daemons.nix-daemon.serviceConfig.ProgramArguments = [
            "${self.packages.${pkgs.stdenv.system}.default}/bin/determinate-nixd"
            "--nix-bin"
            "${config.nix.package}/bin"
          ];

          nix.settings = {
            always-allow-substitutes = true;
            bash-prompt-prefix = "(nix:$name)\\040";
            experimental-features = [ "nix-command" "flakes" ];
            extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
            extra-substituters = [ "https://cache.flakehub.com" ];
            extra-trusted-public-keys = [
              "cache.flakehub.com-1:t6986ugxCA+d/ZF9IeMzJkyqi5mDhvFIx7KA/ipulzE="
              "cache.flakehub.com-2:ntBGiaKSmygJOw2j1hFS7KDlUHQWmZALvSJ9PxMJJYU="
            ];
            netrc-file = config.determinate.nix.primaryUser.netrcPath;
            upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";
          };
        };
      };


      nixosModules.default = { lib, pkgs, config, ... }: {
        options = {
          determinate.nix.primaryUser.username = lib.mkOption {
            type = lib.types.str;
            description = "The Determinate Nix user";
          };

          determinate.nix.primaryUser.netrcPath = lib.mkOption {
            type = lib.types.path;
            description = "The path to the `netrc` file for the user configured by `primaryUser`";

            default =
              let
                netrcRoot =
                  if config.determinate.nix.primaryUser.username == "root"
                  then "/root"
                  else "/home/${config.determinate.nix.primaryUser.username}";
              in
              "${netrcRoot}/.local/share/flakehub/netrc";
          };
        };

        config = {
          environment.systemPackages = [
            inputs.fh.packages."${pkgs.stdenv.system}".default
          ];

          nix.package = inputs.nix.packages."${pkgs.stdenv.system}".default;

          nix.registry.nixpkgs = {
            exact = true;
            from = {
              type = "indirect";
              id = "nixpkgs";
            };
            to = {
              type = "tarball";
              url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1.0.tar.gz";
            };
          };

          systemd.services.nix-daemon.serviceConfig.ExecStart = [
            ""
            "@${self.packages.${pkgs.stdenv.system}.default}/bin/determinate-nixd determinate-nixd --nix-bin ${config.nix.package}/bin"
          ];

          nix.settings = {
            always-allow-substitutes = true;
            bash-prompt-prefix = "(nix:$name)\\040";
            experimental-features = [ "nix-command" "flakes" ];
            extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
            extra-substituters = [ "https://cache.flakehub.com" ];
            extra-trusted-public-keys = [
              "cache.flakehub.com-1:t6986ugxCA+d/ZF9IeMzJkyqi5mDhvFIx7KA/ipulzE="
              "cache.flakehub.com-2:ntBGiaKSmygJOw2j1hFS7KDlUHQWmZALvSJ9PxMJJYU="
            ];
            netrc-file = config.determinate.nix.primaryUser.netrcPath;
            upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";
          };
        };
      };
    };
}
