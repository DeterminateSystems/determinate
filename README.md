# Determinate

Determinate System's validated Nix, configured for FlakeHub and a pre-provided fh.

## NixOS

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0";
  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2405.0";

  outputs = { determinate, nixpkgs, ... }: {
    nixosConfigurations.my-workstation = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          imports = [
            determinate.nixosModules.default
          ];
          # the rest of your configuration
        })
      ];
    };
  };
}
```

## nix-darwin

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0";
  inputs.nix-darwin.url = "github:LnL7/nix-darwin";

  outputs = { determinate, nix-darwin, ... }: {
    darwinConfigurations.my-workstation-aarch64-darwin = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ({ pkgs, ... }: {
          imports = [
            determinate.darwinModules.default
          ];
          # the rest of your configuration
        })
      ];
    };
  };
}
```

## Home Manager

Usage notes: this Home Manager module assumes the Nix daemon is configured for FlakeHub already:

```
netrc-file = /your/home/directory/.local/share/flakehub/netrc
extra-substituters = https://cache.flakehub.com
extra-trusted-public-keys = cache.flakehub.com-1:t6986ugxCA+d/ZF9IeMzJkyqi5mDhvFIx7KA/ipulzE= cache.flakehub.com-2:ntBGiaKSmygJOw2j1hFS7KDlUHQWmZALvSJ9PxMJJYU=
```

Inclusion:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0";
  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2405.*";
  inputs.home-manager.url = "https://flakehub.com/f/nix-community/home-manager/0.2405.*";

  outputs = { nix, nixpkgs, home-manager, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      homeConfigurations.my-workstation = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          determinate.homeManagerModules.default
        ];
      };
    }
}
```
