inputs:

{ lib, pkgs, config, ... }:

let
  cfg = config.determinate;

  # Stronger than mkDefault (1000), weaker than mkForce (50) and the "default override priority"
  # (100).
  mkPreferable = lib.mkOverride 750;

  # Stronger than the "default override priority", as the upstream module uses that, and weaker than mkForce (50).
  mkMorePreferable = lib.mkOverride 75;

  # The settings configured in this module must be generally settable by users both trusted and
  # untrusted by the Nix daemon. Settings that require being a trusted user belong in the
  # `restrictedSettingsModule` below.
  commonNixSettingsModule = { config, pkgs, lib, ... }: lib.mkIf cfg.enable {
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
        url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
      });
    };
  };
in
{
  imports = [
    commonNixSettingsModule
  ];

  options.determinate = {
    enable = lib.mkEnableOption "Determinate Nix" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.self.packages.${pkgs.stdenv.system}.default
    ];

    # NOTE(cole-h): Move the generated nix.conf to /etc/nix/nix.custom.conf, which is included from
    # the Determinate Nixd-managed /etc/nix/nix.conf.
    environment.etc."nix/nix.conf".target = "nix/nix.custom.conf";

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
