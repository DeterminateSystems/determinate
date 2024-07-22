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
