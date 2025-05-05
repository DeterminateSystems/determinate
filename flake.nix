{
  description = "Determinate";

  inputs = {
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix-src/*";
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";

    determinate-nixd-aarch64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/tag/v3.4.2/aarch64-linux";
      flake = false;
    };
    determinate-nixd-x86_64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/tag/v3.4.2/x86_64-linux";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... } @ inputs:
    let
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      allSystems = linuxSystems ++ [ "aarch64-darwin" "x86_64-darwin" ];

      forSystems = systems: f: nixpkgs.lib.genAttrs systems (system: f {
        inherit system;
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
      });

      forLinuxSystems = forSystems linuxSystems;
      forAllSystems = forSystems allSystems;
    in
    {
      packages = forLinuxSystems ({ system, pkgs, ... }: {
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

      # Stub for migration.
      darwinModules.default = ./modules/nix-darwin.nix;

      nixosModules.default = import ./modules/nixos.nix inputs;
    };
}
