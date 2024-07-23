# Determinate

[Determinate Systems'][detsys] validated [Nix], configured for [FlakeHub] and bundled with [`fh`][fh], the CLI for FlakeHub.

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

> [!WARNING]
> We recommend not using a [`follows`][follows] directive for [Nixpkgs] (`inputs.nixpkgs.follows = "nixpkgs"`) in conjunction with the Determinate flake, as it leads to cache misses for artifacts otherwise available from [FlakeHub Cache][cache].

## nix-darwin

Here's an example [nix-darwin] configuration that uses Determinate's nix-darwin module:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0";
  inputs.nix-darwin.url = "github:LnL7/nix-darwin";

  outputs = { determinate, nix-darwin, ... }: {
    darwinConfigurations.my-workstation-aarch64-darwin = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        # Load the Determinate module
        determinate.darwinModules.default

        # Set this value somewhere in your own configuration
        { determinate.nix.primaryUser.name = "<your-username>"; }
      ];
    };
  };
}
```

## Home Manager

Note: this [Home Manager][hm] module assumes that the Nix daemon is already configured for FlakeHub:

```shell
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

[cache]: https://determinate.systems/posts/flakehub-cache-beta
[detsys]: https://determinate.systems
[fh]: https://github.com/DeterminateSystems/fh
[flakehub]: https://flakehub.com
[follows]: https://zero-to-nix.com/concepts/flakes#inputs
[hm]: https://github.com/nix-community/home-manager
[nix-darwin]: https://github.com/LnL7/nix-darwin
[nixpkgs]: https://zero-to-nix.com/concepts/nixpkgs
