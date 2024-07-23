# Determinate

[Determinate Systems'][detsys] validated [Nix], configured for [FlakeHub] and bundled with [`fh`][fh], the CLI for FlakeHub.
To apply it to your flake:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0";
}
```

> [!WARNING]
> We recommend not using a [`follows`][follows] directive for [Nixpkgs] (`inputs.nixpkgs.follows = "nixpkgs"`) in conjunction with the Determinate flake, as it leads to cache misses for artifacts otherwise available from [FlakeHub Cache][cache].

## NixOS

You can quickly set up Determinate on [NixOS] using the NixOS module:

```nix
{
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0";
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

These parameters are available:

| Parameter                               | Description                                          | Default                                                                                                |
| :-------------------------------------- | :--------------------------------------------------- | :----------------------------------------------------------------------------------------------------- |
| `determinate.nix.primaryUser.username`  | The Determinate Nix user                             |                                                                                                        |
| `determinate.nix.primaryUser.netrcPath` | The path to the primary user's [`netrc`][netrc] file | `/root/.local/share/flakehub/netrc` (root user) or `$HOME/.local/share/flakehub/netrc` (non-root user) |

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
      ];
    };
  };
}
```

These parameters are available:

| Parameter                               | Description                                          | Default                                                                                                    |
| :-------------------------------------- | :--------------------------------------------------- | :--------------------------------------------------------------------------------------------------------- |
| `determinate.nix.primaryUser.username`  | The Determinate Nix user                             |                                                                                                            |
| `determinate.nix.primaryUser.netrcPath` | The path to the primary user's [`netrc`][netrc] file | `/var/root/.local/share/flakehub/netrc` (root user) or `$HOME/.local/share/flakehub/netrc` (non-root user) |

## Home Manager

The Determinate [Home Manager module][hm] functions a bit differently depending on whether the Nix user is [trusted](#trusted-user) or [untrusted](#untrusted-user).

| Parameter                               | Description                                          | Default                                                                                                    |
| :-------------------------------------- | :--------------------------------------------------- | :--------------------------------------------------------------------------------------------------------- |
| `determinate.nix.primaryUser.username`  | The Determinate Nix user                             | The [`home.username`][hm-username] parameter in the Home Manager configuration                             |
| `determinate.nix.primaryUser.isTrusted` | Whether the Determinate Nix user is a trusted user   | Whether `determinate.nix.primaryUser.username` equals `"root"                                              |
| `determinate.nix.primaryUser.netrcPath` | The path to the primary user's [`netrc`][netrc] file | `/var/root/.local/share/flakehub/netrc` (root user) or `$HOME/.local/share/flakehub/netrc` (non-root user) |

### Trusted user

For a trusted user, apply a configuration like this (note the `isTrusted` parameter):

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
          # Load the Determinate module
          determinate.homeManagerModules.default

          {
            # Required if a trusted user
            determinate.nix.primaryUser.isTrusted = true;

            # Optional; defaults to `home.username` in Home Manager
            determinate.nix.primaryUser.username = "<your-username>";
          }
        ];
      };
    }
}
```

> [!SUCCESS]
> For trusted users, Nix and [`fh`][fh] are automatically configured to use FlakeHub.

### Untrusted user

For an untrusted user, you need to ensure that the Nix daemon is configured to use [FlakeHub] by applying these settings in your [`nix.conf`][nix-conf] file:

```shell
netrc-file = /your/home/directory/.local/share/flakehub/netrc
extra-substituters = https://cache.flakehub.com
extra-trusted-public-keys = cache.flakehub.com-1:t6986ugxCA+d/ZF9IeMzJkyqi5mDhvFIx7KA/ipulzE= cache.flakehub.com-2:ntBGiaKSmygJOw2j1hFS7KDlUHQWmZALvSJ9PxMJJYU=
```

Then you can apply a Home Manager configuration along these lines:

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
          # Load the Determinate module
          determinate.homeManagerModules.default

          {
            # Optional; defaults to `home.username` in Home Manager
            determinate.nix.primaryUser.username = "<your-username>";
          }
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
[netrc]: https://www.gnu.org/software/inetutils/manual/html_node/The-_002enetrc-file.html
[nix]: https://zero-to-nix.com/concepts/nix
[nix-conf]: https://nix.dev/manual/nix/latest/command-ref/conf-file
[nix-darwin]: https://github.com/LnL7/nix-darwin
[nixos]: https://zero-to-nix.com/concepts/nixos
[nixpkgs]: https://zero-to-nix.com/concepts/nixpkgs
[hm-username]: https://nix-community.github.io/home-manager/options.xhtml#opt-home.username
