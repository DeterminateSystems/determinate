# Determinate

**Determinate** is [Nix] for the enterprise.
It provides an end-to-end experience around using Nix, from installation to collaboration to deployment.
Determinate has two core components:

- [Determinate Nix][det-nix] is [Determinate Systems][detsys]' validated and secure downstream [Nix] distribution.
  It comes bundled with [Determinate Nixd][dnixd], a helpful daemon that automates some otherwise-unpleasant aspects of using Nix, such as garbage collection and providing Nix with [Keychain]-provided certificates on macOS.
- [FlakeHub] is a platform for publishing and discovering Nix flakes, providing [semantic versioning][semver] (SemVer) for flakes and automated flake publishing from [GitHub Actions][actions] and [GitLab CI][gitlab-ci].

You can get started with Determinate in one of two ways:

| Situation                       | How to install                                                               |
| :------------------------------ | :--------------------------------------------------------------------------- |
| **Linux** but not using [NixOS] | [Determinate Nix Installer](#installing-using-the-determinate-nix-installer) |
| **macOS**                       | [Determinate Nix Installer](#installing-using-the-determinate-nix-installer) |
| **Linux** and using [NixOS]     | The [NixOS module](#nixos) provided by this flake                            |

## Installing using the Determinate Nix Installer

**macOS** users, including [nix-darwin] users, should install Determinate using [Determinate.pkg][pkg], our graphical installer.

**Linux** users who are *not* on [NixOS] should use the [Determinate Nix Installer][installer] with the `--determinate` flag:

```shell
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install --determinate
```

Linux users who *are* on NixOS should follow the instructions [below](#installing-using-our-nix-flake).

## Installing using our Nix flake

If you use [NixOS] you can install Determinate using this [Nix flake][flakes].
To add the `determinate` flake as a [flake input][flake-inputs]:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
}
```

> We recommend not using a [`follows`][follows] directive for [Nixpkgs] (`inputs.nixpkgs.follows = "nixpkgs"`) in conjunction with the Determinate flake, as it leads to cache misses for artifacts otherwise available from [FlakeHub Cache][cache].

You can quickly set up Determinate using the `nixosModules.default` module output from this flake.
Here's an example NixOS configuration for the current stable NixOS:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";

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

If you use [nix-darwin] to provide Nix-based configuration for your macOS system, you need to disable nix-darwin's built-in Nix configuration mechanisms by setting `nix.enable = false`; if not, Determinate Nix **does not work properly**.
Here's an example nix-darwin configuration that would be compatible with Determinate Nix:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0";
  inputs.nix-darwin = {
    url = "https://flakehub.com/f/nix-darwin/nix-darwin/0";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";

  outputs = { determinate, nixpkgs, ... }: {
    darwinConfigurations."my-username-aarch64-darwin" = inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      modules = [
        ({ ... }: {
          # Let Determinate Nix handle Nix configuration rather than nix-darwin
          nix.enable = false;

          # Other nix-darwin settings
        })
      ];
    };
  };
}
```

While Determinate Nix creates and manages the standard `nix.conf` file for you, you can set custom configuration in the `/etc/nix/nix.custom.conf` file, which is explained in more detail [in our documentation][configuring-determinate-nix].
If you'd like to set that custom configuration using nix-darwin, you can use this `determinate` flake for that.
Here's an example nix-darwin configuration that writes custom settings:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0";
  inputs.nix-darwin = {
    url = "https://flakehub.com/f/nix-darwin/nix-darwin/0";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";

  outputs = { determinate, nixpkgs, ... }: {
    darwinConfigurations."my-username-aarch64-darwin" = inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      modules = [
        # Add the determinate nix-darwin module
        inputs.determinate.darwinModules.default
        ({ ... }: {
          # Let Determinate Nix handle Nix configuration rather than nix-darwin
          nix.enable = false;

          # Custom settings written to /etc/nix/nix.custom.conf
          determinate-nix.customSettings = {
            flake-registry = "/etc/nix/flake-registry.json";
          };
        })
      ];
    };
  };
}
```

[actions]: https://github.com/features/actions
[cache]: https://determinate.systems/posts/flakehub-cache-beta
[configuring-determinate-nix]: https://docs.determinate.systems/determinate-nix#determinate-nix-configuration
[det-nix]: https://determinate.systems/nix
[detsys]: https://determinate.systems
[dnixd]: https://docs.determinate.systems/determinate-nix#determinate-nixd
[fh]: https://github.com/DeterminateSystems/fh
[flakehub]: https://flakehub.com
[flake-inputs]: https://zero-to-nix.com/concepts/flakes#inputs
[flakes]: https://zero-to-nix.com/concepts/flakes
[follows]: https://zero-to-nix.com/concepts/flakes#inputs
[gitlab-ci]: https://docs.gitlab.com/ee/ci
[installer]: https://github.com/DeterminateSystems/nix-installer
[keychain]: https://developer.apple.com/documentation/security/keychain-services
[netrc]: https://www.gnu.org/software/inetutils/manual/html_node/The-_002enetrc-file.html
[nix]: https://zero-to-nix.com/concepts/nix
[nix-conf]: https://nix.dev/manual/nix/latest/command-ref/conf-file
[nix-darwin]: https://github.com/nix-darwin/nix-darwin
[nixos]: https://zero-to-nix.com/concepts/nixos
[nixpkgs]: https://zero-to-nix.com/concepts/nixpkgs
[pkg]: https://install.determinate.systems/determinate-pkg/stable/Universal
[semver]: https://docs.determinate.systems/flakehub/concepts/semver
