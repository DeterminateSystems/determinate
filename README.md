# Determinate

**Determinate** is [Nix] for the enterprise.
It provides an end-to-end experience around using Nix, from installation to collaboration to deployment.
Determinate has two core components:

- [Determinate Nix][det-nix] is [Determinate Systems][detsys]' validated and secure downstream [Nix] distribution.
  It comes bundled with [Determinate Nixd][dnixd], a helpful daemon that automates some otherwise-unpleasant aspects of using Nix, such as garbage collection and providing Nix with Keychain-provided certificates on macOS.
- [FlakeHub] is a platform for publishing and discovering Nix flakes, providing [semantic versioning][semver] (SemVer) for flakes and automated flake publishing from [GitHub Actions][actions] and [GitLab CI][gitlab-ci].

You can get started with Determinate in one of two ways:

| Situation                            | How to install                                                               |
| :----------------------------------- | :--------------------------------------------------------------------------- |
| **Linux** but not using [NixOS]      | [Determinate Nix Installer](#installing-using-the-determinate-nix-installer) |
| **macOS** but not using [nix-darwin] | [Determinate Nix Installer](#installing-using-the-determinate-nix-installer) |
| **Linux** and using [NixOS]          | The [NixOS module](#nixos) provided by this flake                            |
| **macOS** and using [nix-darwin]     | The [nix-darwin module](#nix-darwin) provided by this flake                  |

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

If you use [nix-darwin] or [NixOS] you can install Determinate using this [Nix flake][flakes].
To add the `determinate` flake as a [flake input][flake-inputs]:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
}
```

> We recommend not using a [`follows`][follows] directive for [Nixpkgs] (`inputs.nixpkgs.follows = "nixpkgs"`) in conjunction with the Determinate flake, as it leads to cache misses for artifacts otherwise available from [FlakeHub Cache][cache].

### NixOS

If you're a [NixOS] user, you can quickly set up Determinate using the `nixosModules.default` module output from this flake.
Here's an example NixOS configuration:

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

[actions]: https://github.com/features/actions
[cache]: https://determinate.systems/posts/flakehub-cache-beta
[det-nix]: https://determinate.systems/nix
[detsys]: https://determinate.systems
[fh]: https://github.com/DeterminateSystems/fh
[flakehub]: https://flakehub.com
[flake-inputs]: https://zero-to-nix.com/concepts/flakes#inputs
[flakes]: https://zero-to-nix.com/concepts/flakes
[follows]: https://zero-to-nix.com/concepts/flakes#inputs
[gitlab-ci]: https://docs.gitlab.com/ee/ci
[installer]: https://github.com/DeterminateSystems/nix-installer
[netrc]: https://www.gnu.org/software/inetutils/manual/html_node/The-_002enetrc-file.html
[nix]: https://zero-to-nix.com/concepts/nix
[nix-conf]: https://nix.dev/manual/nix/latest/command-ref/conf-file
[nix-darwin]: https://github.com/LnL7/nix-darwin
[nixos]: https://zero-to-nix.com/concepts/nixos
[nixpkgs]: https://zero-to-nix.com/concepts/nixpkgs
[semver]: https://docs.determinate.systems/flakehub/concepts/semver
