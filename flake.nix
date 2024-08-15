{
  description = "Determinate";

  inputs = {
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/0.1";
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix/2.0";
    nixpkgs.follows = "fh/nixpkgs";

    determinate-nixd-aarch64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/rev/06fe26d67808f9d29585f3255917b1438ce14aca/aarch64-linux";
      flake = false;
    };
    determinate-nixd-x86_64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/rev/06fe26d67808f9d29585f3255917b1438ce14aca/x86_64-linux";
      flake = false;
    };
    determinate-nixd-aarch64-darwin = {
      url = "https://install.determinate.systems/determinate-nixd/rev/06fe26d67808f9d29585f3255917b1438ce14aca/macOS";
      flake = false;
    };
    determinate-nixd-x86_64-darwin.follows = "determinate-nixd-aarch64-darwin";
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

      supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        inherit system;
        pkgs = pkgsFor system;
      });

      # Stronger than mkDefault (1000), weaker than mkForce (50) and the "default override priority"
      # (100).
      mkPreferable = inputs.nixpkgs.lib.mkOrder 750;
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

          determinate.nix.primaryUser.isTrusted = lib.mkOption {
            type = lib.types.bool;
            description = "Whether the Determinate Nix user is a trusted user";
            default = config.determinate.nix.primaryUser.username == "root";
          };
        };

        config = {
          home.packages = [
            inputs.fh.packages."${pkgs.stdenv.system}".default
            config.nix.package
          ];

          nix.package = inputs.nix.packages."${pkgs.stdenv.system}".default;

          nix.registry.nixpkgs = {
            exact = true;

            from = {
              type = "indirect";
              id = "nixpkgs";
            };

            # NOTE(cole-h): The NixOS module exposes a `flake` option that is a fancy wrapper around
            # setting `to` -- we don't want to clobber this if users have set it on their own
            to = lib.mkIf (config.nix.registry.nixpkgs.flake or null == null) (mkPreferable {
              type = "tarball";
              url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1.0.tar.gz";
            });
          };

          # The `extra-trusted-public-keys` settings are privileged and so
          # they're applied only if `primaryUser.isTrusted` is set to `true`
          nix.settings = lib.mkMerge [
            (lib.optionalAttrs (config.determinate.nix.primaryUser.isTrusted) {
              always-allow-substitutes = true;
              extra-trusted-public-keys = [
                "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
                "cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio="
                "cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU="
                "cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU="
                "cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8="
                "cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ="
                "cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o="
                "cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y="
              ];
              netrc-file = "/nix/var/determinate/netrc";
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

            # NOTE(cole-h): The NixOS module exposes a `flake` option that is a fancy wrapper around
            # setting `to` -- we don't want to clobber this if users have set it on their own
            to = lib.mkIf (config.nix.registry.nixpkgs.flake or null == null) (mkPreferable {
              type = "tarball";
              url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1.0.tar.gz";
            });
          };

          launchd.daemons.nix-daemon.serviceConfig = {
            ProgramArguments = [
              "${self.packages.${pkgs.stdenv.system}.default}/bin/determinate-nixd"
              "--nix-bin"
              "${config.nix.package}/bin"
            ];

            Sockets = {
              "determinate-nixd.socket" = {
                # We'd set `SockFamily = "Unix";`, but nix-darwin automatically sets it with SockPathName
                SockPassive = true;
                SockPathName = "/var/run/determinate-nixd.socket";
              };

              "nix-daemon.socket" = {
                # We'd set `SockFamily = "Unix";`, but nix-darwin automatically sets it with SockPathName
                SockPassive = true;
                SockPathName = "/var/run/nix-daemon.socket";
              };
            };

            SoftResourceLimits.NumberOfFiles = 1048576;
            HardResourceLimits.NumberOfFiles = 2097152;
          };

          nix.settings = {
            always-allow-substitutes = true;
            bash-prompt-prefix = "(nix:$name)\\040";
            experimental-features = [ "nix-command" "flakes" ];
            extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
            extra-substituters = [ "https://cache.flakehub.com" ];
            extra-trusted-public-keys = [
              "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
              "cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio="
              "cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU="
              "cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU="
              "cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8="
              "cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ="
              "cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o="
              "cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y="
            ];
            netrc-file = "/nix/var/determinate/netrc";
            upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";
          };
        };
      };


      nixosModules.default = { lib, pkgs, config, ... }: {
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

            # NOTE(cole-h): The NixOS module exposes a `flake` option that is a fancy wrapper around
            # setting `to` -- we don't want to clobber this if users have set it on their own
            to = lib.mkIf (config.nix.registry.nixpkgs.flake or null == null) (mkPreferable {
              type = "tarball";
              url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1.0.tar.gz";
            });
          };

          systemd.services.nix-daemon.serviceConfig.ExecStart = [
            ""
            "@${self.packages.${pkgs.stdenv.system}.default}/bin/determinate-nixd determinate-nixd --nix-bin ${config.nix.package}/bin"
          ];

          systemd.sockets.nix-daemon.socketConfig.FileDescriptorName = "nix-daemon.socket";
          systemd.sockets.determinate-nixd = {
            description = "Determinate Nixd Daemon Socket";
            wantedBy = [ "sockets.target" ];
            before= [ "multi-user.target" ];

            unitConfig = {
              RequiresMountsFor = [ "/nix/store" "/nix/var/determinate" ];
              ConditionPathIsReadWrite = [ "/nix/var/determinate" ];
            };

            socketConfig = {
              Service = "nix-daemon.service";
              FileDescriptorName = "determinate-nixd.socket";
              ListenStream = "/nix/var/determinate/determinate-nixd.socket";
            };
          };

          nix.settings = {
            always-allow-substitutes = true;
            bash-prompt-prefix = "(nix:$name)\\040";
            experimental-features = [ "nix-command" "flakes" ];
            extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
            extra-substituters = [ "https://cache.flakehub.com" ];
            extra-trusted-public-keys = [
              "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
              "cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio="
              "cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU="
              "cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU="
              "cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8="
              "cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ="
              "cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o="
              "cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y="
            ];
            netrc-file = "/nix/var/determinate/netrc";
            upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";
          };
        };
      };
    };
}
