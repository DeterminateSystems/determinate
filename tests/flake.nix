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

          nix-darwin-shell-completions =
            let
              pkgs = import inputs.nixpkgs { system = "aarch64-darwin"; };

              mkSystem =
                enable:
                (inputs.nix-darwin.lib.darwinSystem {
                  system = "aarch64-darwin";

                  modules = [
                    inputs.determinate.darwinModules.default
                    {
                      determinateNix = {
                        enable = true;
                        shellCompletions.enable = enable;
                      };
                      # nix-darwin only links completions for the shells it manages
                      programs = {
                        bash.completion.enable = true;
                        fish.enable = true;
                      };
                      system.stateVersion = 5;
                    }
                  ];
                }).system;

              enabled = mkSystem true;
              disabled = mkSystem false;
            in
            pkgs.runCommand "nix-darwin-shell-completions" { } ''
              # Completions are installed when enabled
              test -e ${enabled}/sw/share/zsh/site-functions/_determinate-nixd
              test -e ${enabled}/sw/share/fish/vendor_completions.d/determinate-nixd.fish
              test -e ${enabled}/sw/share/bash-completion/completions/determinate-nixd.bash

              # The binary itself is left to Determinate Nix Installer
              test ! -e ${enabled}/sw/bin/determinate-nixd

              # Nothing is installed when disabled
              test ! -e ${disabled}/sw/share/zsh/site-functions/_determinate-nixd

              touch $out
            '';

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
