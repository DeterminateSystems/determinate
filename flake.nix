{
  description = "Determinate";

  inputs = {
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix/2.0";
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1.tar.gz";

    determinate-nixd-aarch64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/tag/v0.2.2/aarch64-linux";
      flake = false;
    };
    determinate-nixd-x86_64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/tag/v0.2.2/x86_64-linux";
      flake = false;
    };
    determinate-nixd-aarch64-darwin = {
      url = "https://install.determinate.systems/determinate-nixd/tag/v0.2.2/macOS";
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
      mkPreferable = inputs.nixpkgs.lib.mkOverride 750;

      # Stronger than the "default override priority", as the upstream module uses that, and weaker than mkForce (50).
      mkMorePreferable = inputs.nixpkgs.lib.mkOverride 75;

      # Common settings that are shared between NixOS and nix-darwin modules.
      # The settings configured in this module must be generally settable by users both trusted and
      # untrusted by the Nix daemon. Settings that require being a trusted user belong in the
      # `restrictedSettingsModule` below.
      commonSettingsModule = { config, pkgs, lib, ... }: {
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

        nix.settings = {
          bash-prompt-prefix = "(nix:$name)\\040";
          extra-experimental-features = [ "nix-command" "flakes" ];
          extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
          extra-substituters = [ "https://cache.flakehub.com" ];
        };
      };

      # Restricted settings that are shared between NixOS and nix-darwin modules.
      # The settings configured in this module require being a user trusted by the Nix daemon.
      restrictedSettingsModule = { ... }: {
        nix.settings = restrictedNixSettings;
      };

      # Nix settings that require being a trusted user to configure.
      restrictedNixSettings = {
        always-allow-substitutes = true;
        netrc-file = "/nix/var/determinate/netrc";
        upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";
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
      };
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

            packages = with pkgs; [
              lychee
              nixpkgs-fmt

              (writeScriptBin "check-readme-links" ''
                lychee README.md
              '')
            ];
          };
        });

      darwinModules.default = { lib, config, pkgs, ... }: {
        imports = [
          commonSettingsModule
          restrictedSettingsModule
        ];

        config = {
          # Make Nix use the Nix daemon
          nix.useDaemon = true;

          # Make sure that the user can't enable the nix-daemon in their own nix-darwin config
          services.nix-daemon.enable = lib.mkForce false;

          system.activationScripts.nix-daemon = lib.mkForce { enable = false; text = ""; };
          system.activationScripts.launchd.text = lib.mkBefore ''
            if test -e /Library/LaunchDaemons/org.nixos.nix-daemon.plist; then
              echo "Unloading org.nixos.nix-daemon"
              launchctl bootout system /Library/LaunchDaemons/org.nixos.nix-daemon.plist || true
              mv /Library/LaunchDaemons/org.nixos.nix-daemon.plist /Library/LaunchDaemons/.before-determinate-nixd.org.nixos.nix-daemon.plist.skip
            fi

            if test -e /Library/LaunchDaemons/org.nixos.darwin-store.plist; then
              echo "Unloading org.nixos.darwin-store"
              launchctl bootout system /Library/LaunchDaemons/org.nixos.darwin-store.plist || true
              mv /Library/LaunchDaemons/org.nixos.darwin-store.plist /Library/LaunchDaemons/.before-determinate-nixd.org.nixos.darwin-store.plist.skip
            fi

            install -d -m 755 -o root -g wheel /usr/local/bin
            cp ${self.packages.${pkgs.stdenv.system}.default}/bin/determinate-nixd /usr/local/bin/.determinate-nixd.next
            chmod +x /usr/local/bin/.determinate-nixd.next
            mv /usr/local/bin/.determinate-nixd.next /usr/local/bin/determinate-nixd
          '';

          launchd.daemons.determinate-nixd-store.serviceConfig = {
            Label = "systems.determinate.nix-store";
            RunAtLoad = true;

            StandardErrorPath = lib.mkForce "/var/log/determinate-nix-init.log";
            StandardOutPath = lib.mkForce "/var/log/determinate-nix-init.log";

            ProgramArguments = lib.mkForce [
              "/usr/local/bin/determinate-nixd"
              "--nix-bin"
              "${config.nix.package}/bin"
              "init"
            ];
          };

          launchd.daemons.determinate-nixd.serviceConfig = {
            Label = "systems.determinate.nix-daemon";

            StandardErrorPath = lib.mkForce "/var/log/determinate-nix-daemon.log";
            StandardOutPath = lib.mkForce "/var/log/determinate-nix-daemon.log";

            ProgramArguments = lib.mkForce [
              "/usr/local/bin/determinate-nixd"
              "--nix-bin"
              "${config.nix.package}/bin"
              "daemon"
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

            SoftResourceLimits = {
              NumberOfFiles = mkPreferable 1048576;
              NumberOfProcesses = mkPreferable 1048576;
              Stack = mkPreferable 67108864;
            };
            HardResourceLimits = {
              NumberOfFiles = mkPreferable 1048576;
              NumberOfProcesses = mkPreferable 1048576;
              Stack = mkPreferable 67108864;
            };
          };
        };
      };


      nixosModules.default = { lib, pkgs, config, ... }: {
        imports = [
          commonSettingsModule
          restrictedSettingsModule
        ];

        config = {
          environment.systemPackages = [
            self.packages.${pkgs.stdenv.system}.default
          ];

          systemd.services.nix-daemon.serviceConfig = {
            ExecStart = [
              ""
              "@${self.packages.${pkgs.stdenv.system}.default}/bin/determinate-nixd determinate-nixd --nix-bin ${config.nix.package}/bin daemon"
            ];
            KillMode = mkPreferable "process";
            LimitNOFILE = mkMorePreferable 1048576;
            LimitSTACK = mkPreferable "64M";
            TasksMax = mkPreferable 1048576;
          };

          systemd.sockets.nix-daemon.socketConfig.FileDescriptorName = "nix-daemon.socket";
          systemd.sockets.determinate-nixd = {
            description = "Determinate Nixd Daemon Socket";
            wantedBy = [ "sockets.target" ];
            before = [ "multi-user.target" ];

            unitConfig = {
              RequiresMountsFor = [ "/nix/store" "/nix/var/determinate" ];
            };

            socketConfig = {
              Service = "nix-daemon.service";
              FileDescriptorName = "determinate-nixd.socket";
              ListenStream = "/nix/var/determinate/determinate-nixd.socket";
              DirectoryMode = "0755";
            };
          };
        };
      };
    };
}
