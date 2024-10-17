# Determinate

**Determinate** is TODO.
Determinate has two core components:

- [Determinate Nix][det-nix] is TODO.
  It comes bundled with [`fh`][fh], the CLI for FlakeHub.
- [FlakeHub] is TODO.

You can get started with Determinate in one of two ways:

- If you're on macOS or Linux, you can use the [Determinate Nix Installer](#installing-using-the-determinate-nix-installer).
- If you're on [NixOS] or use [nix-darwin], you can use the modules provided by the [Nix flake](#installing-using-our-nix-flake) in this repo.

## Installing using the Determinate Nix Installer

If you use...

- **macOS** (not [nix-darwin]) or
- **Linux** (not [NixOS])

...you can install Determinate using the [Determinate Nix Installer][installer] with the `--determinate` flag:

```shell
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install --determinate
```

## Installing using our Nix flake

If you use [nix-darwin] or [NixOS] you can install Determinate using this [Nix flake][flakes]:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
}
```

> We recommend not using a [`follows`][follows] directive for [Nixpkgs] (`inputs.nixpkgs.follows = "nixpkgs"`) in conjunction with the Determinate flake, as it leads to cache misses for artifacts otherwise available from [FlakeHub Cache][cache].

### NixOS

If you're a [NixOS] user, you can quickly set up Determinate using the `nixosModules.default` module output from this flake.
Here's an example `configuration.nix` file:

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

### nix-darwin

If you're a [nix-darwin] user on macOS, you can quickly set up Determinate using the `darwinModules.default` module output from this flake.
Here's an example nix-darwin configuration:

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
[det-nix]: https://determinate.systems/nix
[detsys]: https://determinate.systems
[fh]: https://github.com/DeterminateSystems/fh
[flakehub]: https://flakehub.com
[flakes]: https://zero-to-nix.com/concepts/flakes
[follows]: https://zero-to-nix.com/concepts/flakes#inputs
[installer]: https://github.com/DeterminateSystems/nix-installer
[netrc]: https://www.gnu.org/software/inetutils/manual/html_node/The-_002enetrc-file.html
[nix]: https://zero-to-nix.com/concepts/nix
[nix-conf]: https://nix.dev/manual/nix/latest/command-ref/conf-file
[nix-darwin]: https://github.com/LnL7/nix-darwin
[nixos]: https://zero-to-nix.com/concepts/nixos
[nixpkgs]: https://zero-to-nix.com/concepts/nixpkgs
