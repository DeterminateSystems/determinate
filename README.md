# Determinate

[Determinate Systems'][detsys] validated [Nix], configured for [FlakeHub] and bundled with [`fh`][fh], the CLI for FlakeHub.
To add it to a [flake][flakes]:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
}
```

> We recommend not using a [`follows`][follows] directive for [Nixpkgs] (`inputs.nixpkgs.follows = "nixpkgs"`) in conjunction with the Determinate flake, as it leads to cache misses for artifacts otherwise available from [FlakeHub Cache][cache].

## NixOS

You can quickly set up Determinate on [NixOS] using the NixOS module.

Here's an example configuration:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2405.0";

  outputs = { determinate, nixpkgs, ... }: {
    nixosConfigurations.my-workstation = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Load the Determinate module
        determinate.nixosModules.default
      ];
    };
  };
}
```

## nix-darwin

You can quickly set up Determinate on macOS using the [nix-darwin] module.

Here's an example configuration:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
  inputs.nix-darwin.url = "github:LnL7/nix-darwin";

  outputs = { determinate, nix-darwin, ... }: {
    darwinConfigurations.my-workstation-aarch64-darwin = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        # Load the Determinate module
        determinate.darwinModules.default
      ];
    };
  };
}
```

[cache]: https://determinate.systems/posts/flakehub-cache-beta
[detsys]: https://determinate.systems
[fh]: https://github.com/DeterminateSystems/fh
[flakehub]: https://flakehub.com
[flakes]: https://zero-to-nix.com/concepts/flakes
[follows]: https://zero-to-nix.com/concepts/flakes#inputs
[netrc]: https://www.gnu.org/software/inetutils/manual/html_node/The-_002enetrc-file.html
[nix]: https://zero-to-nix.com/concepts/nix
[nix-conf]: https://nix.dev/manual/nix/latest/command-ref/conf-file
[nix-darwin]: https://github.com/LnL7/nix-darwin
[nixos]: https://zero-to-nix.com/concepts/nixos
[nixpkgs]: https://zero-to-nix.com/concepts/nixpkgs
