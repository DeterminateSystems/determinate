inputs:
{ lib, config, pkgs, ... }:
let
  inherit (import ./shared.nix inputs)
    commonNixSettingsModule
    restrictedNixSettingsModule
    mkPreferable
  ;
in
{
  imports = [
    commonNixSettingsModule
    restrictedNixSettingsModule
  ];

  config = {
    # Make Nix use the Nix daemon
    nix.useDaemon = true;

    # Make sure that the user can't enable the nix-daemon in their own nix-darwin config
    services.nix-daemon.enable = lib.mkForce false;

    system.activationScripts.nix-daemon = lib.mkForce { enable = false; text = ""; };
    system.activationScripts.launchd.text = lib.mkBefore ''
      if test -e /Library/LaunchDaemons/org.nixos.nix-daemon.plist; then
        echo "Unloading org.nixos.nix-daemon"
        launchctl bootout system /Library/LaunchDaemons/org.nixos.nix-daemon.plist || true
        mv /Library/LaunchDaemons/org.nixos.nix-daemon.plist /Library/LaunchDaemons/.before-determinate-nixd.org.nixos.nix-daemon.plist.skip
      fi

      if test -e /Library/LaunchDaemons/org.nixos.darwin-store.plist; then
        echo "Unloading org.nixos.darwin-store"
        launchctl bootout system /Library/LaunchDaemons/org.nixos.darwin-store.plist || true
        mv /Library/LaunchDaemons/org.nixos.darwin-store.plist /Library/LaunchDaemons/.before-determinate-nixd.org.nixos.darwin-store.plist.skip
      fi

      install -d -m 755 -o root -g wheel /usr/local/bin
      cp ${inputs.self.packages.${pkgs.stdenv.system}.default}/bin/determinate-nixd /usr/local/bin/.determinate-nixd.next
      chmod +x /usr/local/bin/.determinate-nixd.next
      mv /usr/local/bin/.determinate-nixd.next /usr/local/bin/determinate-nixd
    '';

    launchd.daemons.determinate-nixd-store.serviceConfig = {
      Label = "systems.determinate.nix-store";
      RunAtLoad = true;

      StandardErrorPath = lib.mkForce "/var/log/determinate-nix-init.log";
      StandardOutPath = lib.mkForce "/var/log/determinate-nix-init.log";

      ProgramArguments = lib.mkForce [
        "/usr/local/bin/determinate-nixd"
        "--nix-bin"
        "${config.nix.package}/bin"
        "init"
      ];
    };

    launchd.daemons.determinate-nixd.serviceConfig = {
      Label = "systems.determinate.nix-daemon";

      StandardErrorPath = lib.mkForce "/var/log/determinate-nix-daemon.log";
      StandardOutPath = lib.mkForce "/var/log/determinate-nix-daemon.log";

      ProgramArguments = lib.mkForce [
        "/usr/local/bin/determinate-nixd"
        "--nix-bin"
        "${config.nix.package}/bin"
        "daemon"
      ];

      Sockets = {
        "determinate-nixd.socket" = {
          # We'd set `SockFamily = "Unix";`, but nix-darwin automatically sets it with SockPathName
          SockPassive = true;
          SockPathName = "/var/run/determinate-nixd.socket";
        };

        "nix-daemon.socket" = {
          # We'd set `SockFamily = "Unix";`, but nix-darwin automatically sets it with SockPathName
          SockPassive = true;
          SockPathName = "/var/run/nix-daemon.socket";
        };
      };

      SoftResourceLimits = {
        NumberOfFiles = mkPreferable 1048576;
        NumberOfProcesses = mkPreferable 1048576;
        Stack = mkPreferable 67108864;
      };
      HardResourceLimits = {
        NumberOfFiles = mkPreferable 1048576;
        NumberOfProcesses = mkPreferable 1048576;
        Stack = mkPreferable 67108864;
      };
    };
  };
}
