{
  description = "Determinate";

  inputs = {
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix-src/*";
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1.tar.gz";

    determinate-nixd-aarch64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/tag/v3.4.0/aarch64-linux";
      flake = false;
    };
    determinate-nixd-x86_64-linux = {
      url = "https://install.determinate.systems/determinate-nixd/tag/v3.4.0/x86_64-linux";
      flake = false;
    };
    determinate-nixd-aarch64-darwin = {
      url = "https://install.determinate.systems/determinate-nixd/tag/v3.4.0/macOS";
      flake = false;
    };
    determinate-nixd-x86_64-darwin.follows = "determinate-nixd-aarch64-darwin";
  };

  outputs = { self, nixpkgs, ... } @ inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      pkgsFor = system: import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };

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
