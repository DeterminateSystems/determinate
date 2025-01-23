inputs:
{ lib, pkgs, config, ... }:
let
  inherit (import ./shared.nix inputs)
    commonNixSettingsModule
    restrictedNixSettingsModule
    mkPreferable
    mkMorePreferable
  ;
in
{
  imports = [
    commonNixSettingsModule
    restrictedNixSettingsModule
  ];

  config = {
    # Push the user's nix.conf into /etc/nix/nix.custom.conf,
    # leaving determinate-nixd to manage /etc/nix/nix.conf
    environment.etc."nix/nix.conf".target = "nix/nix.custom.conf";

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
