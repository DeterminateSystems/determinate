inputs:
{ lib, pkgs, config, ... }:
let
  # Stronger than mkDefault (1000), weaker than mkForce (50) and the "default override priority"
  # (100).
  mkPreferable = lib.mkOverride 750;

  # Stronger than the "default override priority", as the upstream module uses that, and weaker than mkForce (50).
  mkMorePreferable = lib.mkOverride 75;

  # The settings configured in this module must be generally settable by users both trusted and
  # untrusted by the Nix daemon. Settings that require being a trusted user belong in the
  # `restrictedSettingsModule` below.
  commonNixSettingsModule = { config, pkgs, lib, ... }: {
    nix.package = inputs.nix.packages."${pkgs.stdenv.system}".default;

    nix.registry.nixpkgs = {
      exact = true;

      from = {
        type = "indirect";
        id = "nixpkgs";
      };

      # NOTE(cole-h): The NixOS module exposes a `flake` option that is a fancy wrapper around
      # setting `to` -- we don't want to clobber this if users have set it on their own
      to = lib.mkIf (config.nix.registry.nixpkgs.flake or null == null) (mkPreferable {
        type = "tarball";
        url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1.0.tar.gz";
      });
    };

    nix.settings = {
      bash-prompt-prefix = "(nix:$name)\\040";
      extra-experimental-features = [ "nix-command" "flakes" ];
      extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
      extra-substituters = [ "https://cache.flakehub.com" ];
    };
  };

  # The settings configured in this module require being a user trusted by the Nix daemon.
  restrictedNixSettingsModule = { ... }: {
    nix.settings = restrictedNixSettings;
  };

  # Nix settings that require being a trusted user to configure.
  restrictedNixSettings = {
    always-allow-substitutes = true;
    netrc-file = "/nix/var/determinate/netrc";
    upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";
    extra-trusted-public-keys = [
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio="
      "cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU="
      "cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU="
      "cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8="
      "cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ="
      "cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o="
      "cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y="
    ];
  };
in
{
  imports = [
    commonNixSettingsModule
    restrictedNixSettingsModule
  ];

  config = {
    environment.systemPackages = [
      inputs.self.packages.${pkgs.stdenv.system}.default
    ];

    systemd.services.nix-daemon.serviceConfig = {
      ExecStart = [
        ""
        "@${inputs.self.packages.${pkgs.stdenv.system}.default}/bin/determinate-nixd determinate-nixd --nix-bin ${config.nix.package}/bin daemon"
      ];
      KillMode = mkPreferable "process";
      LimitNOFILE = mkMorePreferable 1048576;
      LimitSTACK = mkPreferable "64M";
      TasksMax = mkPreferable 1048576;
    };

    systemd.sockets.nix-daemon.socketConfig.FileDescriptorName = "nix-daemon.socket";
    systemd.sockets.determinate-nixd = {
      description = "Determinate Nixd Daemon Socket";
      wantedBy = [ "sockets.target" ];
      before = [ "multi-user.target" ];

      unitConfig = {
        RequiresMountsFor = [ "/nix/store" "/nix/var/determinate" ];
      };

      socketConfig = {
        Service = "nix-daemon.service";
        FileDescriptorName = "determinate-nixd.socket";
        ListenStream = "/nix/var/determinate/determinate-nixd.socket";
        DirectoryMode = "0755";
      };
    };
  };
}
