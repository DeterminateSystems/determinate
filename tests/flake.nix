{
  inputs = {
    determinate.url = "path:../";
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/=0.2511";
    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/=0.2511";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/=0.2511";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      ...
    }@inputs:
    {
      checks = {
        x86_64-linux.nixos =
          (inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              inputs.determinate.nixosModules.default
              {
                fileSystems."/" = {
                  device = "/dev/bogus";
                  fsType = "ext4";
                };
                boot.loader.grub.devices = [ "/dev/bogus" ];
                system.stateVersion = "24.11";
              }
            ];
          }).config.system.build.toplevel;

        # Regression test: a path-valued `additionalNetrcSources` entry must be serialized as the
        # literal filesystem path. Handing the path straight to `builtins.toJSON` copies it into
        # `/nix/store`, which publishes the netrc contents and yields a source the daemon rejects.
        x86_64-linux.nixos-determinate-nixd-config =
          let
            nixos = inputs.nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              modules = [
                inputs.determinate.nixosModules.default
                {
                  fileSystems."/" = {
                    device = "/dev/bogus";
                    fsType = "ext4";
                  };
                  boot.loader.grub.devices = [ "/dev/bogus" ];
                  system.stateVersion = "24.11";

                  determinate = {
                    edgeCacheSubstituters = [ "https://cache.example.com/" ];
                    determinateNixd.authentication.additionalNetrcSources = [
                      /etc/extra/netrc
                      "/run/agenix/extra-netrc"
                    ];
                  };
                }
              ];
            };

            actual = nixos.config.environment.etc."determinate/config.json".text;

            expected = builtins.toJSON {
              edgeCacheSubstituters = [ "https://cache.example.com/" ];
              authentication.additionalNetrcSources = [
                "/etc/extra/netrc"
                "/run/agenix/extra-netrc"
              ];
            };
          in
          assert inputs.nixpkgs.lib.assertMsg (
            actual == expected
          ) "/etc/determinate/config.json mismatch\n  actual:   ${actual}\n  expected: ${expected}";
          nixos.pkgs.runCommand "nixos-determinate-nixd-config" { } "touch $out";

        aarch64-darwin = {
          home-manager =
            (inputs.home-manager.lib.homeManagerConfiguration {
              pkgs = import inputs.nixpkgs {
                system = "aarch64-darwin";
              };
              modules = [
                inputs.determinate.homeManagerModules.default
                {
                  home.username = "test";
                  home.homeDirectory = "/Users/test";
                  home.stateVersion = "24.11";
                }
              ];
            }).activationPackage;

          nix-darwin =
            (inputs.nix-darwin.lib.darwinSystem {
              system = "aarch64-darwin";

              modules = [
                inputs.determinate.darwinModules.default
                {
                  determinateNix.enable = true;
                  system.stateVersion = 5;
                }
              ];
            }).system;

          nix-darwin-custom-config =
            (inputs.nix-darwin.lib.darwinSystem {
              system = "aarch64-darwin";

              modules = [
                inputs.determinate.darwinModules.default
                {
                  determinateNix = {
                    enable = true;
                    customSettings = {
                      auto-optimise-store = true;
                      extra-experimental-features = [ "build-time-fetch-tree" ];
                      flake-registry = "/etc/nix/flake-registry.json";
                    };
                    determinateNixd = {
                      builder.state = "disabled";
                      authentication.additionalNetrcSources = [ "/etc/extra/netrc" ];
                      garbageCollector.strategy = "disabled";
                    };
                  };
                  system.stateVersion = 5;
                }
              ];
            }).system;
        };
      };
    };
}
