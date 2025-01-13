{ lib, pkgs, ... }:
let
  failWithoutDeterminateMessage = ''
    if ! /usr/local/bin/determinate-nixd status > /dev/null 2>&1 ; then
      echo "Determinate is not installed."
      echo "Download and install the Determinate package before activating the nix-darwin module."
      echo ""
      echo "https://docs.determinate.systems/get-started"
      exit 1
    fi
  '';
in {
  # Disable some modules that conflict with determinate-nixd.
  disabledModules = [
    # Wants to add an outdated Nix to the environment, manage nix.conf, manage the
    # NIX_PATH, manage the Nix build users and group
    "nix"

    # Wants to configure various Nix settings that want to write to nix.conf
    "nix/linux-builder.nix"

    # Wants to configure NIX_PATH
    "nix/nixpkgs-flake.nix"

    # Wants to add to nix.conf
    "services/hercules-ci-agent"

    # Wants to configure the nix-daemon launchd unit, but determinate-nixd has its own
    "services/nix-daemon.nix"
  ];

  ### Setup bogus options so that some things still work as expected.

  # determinate-nixd manages the Nix daemon.
  options.nix.useDaemon = lib.mkOption {
    type = lib.types.bool;
    default = true;
    internal = true;
  };

  # Necessary for darwin-rebuild, etc. tools.
  # https://github.com/LnL7/nix-darwin/blob/55d07816a0944f06a9df5ef174999a72fa4060c7/pkgs/nix-tools/default.nix#L8
  options.nix.package = lib.mkOption {
    type = lib.types.package;
    default = {
      type = "derivation";
      outPath = "/nix/var/nix/profiles/default";
    };
    internal = true;
  };

  # Necessary system/checks
  # https://github.com/LnL7/nix-darwin/blob/a35b08d09efda83625bef267eb24347b446c80b8/modules/system/checks.nix#L350
  options.nix.configureBuildUsers = lib.mkOption {
    type = lib.types.bool;
    default = false;
    internal = true;
  };

  # Unconditionally set in the nix-darwin flake[1], but we disable the nixpkgs-flake
  # module[2] since it would interfere with determinate-nixd.
  # [1]: https://github.com/LnL7/nix-darwin/blob/55d07816a0944f06a9df5ef174999a72fa4060c7/flake.nix#L36
  # [2]: https://github.com/LnL7/nix-darwin/blob/55d07816a0944f06a9df5ef174999a72fa4060c7/modules/nix/nixpkgs-flake.nix
  options.nixpkgs.flake = lib.mkOption {
    internal = true;
  };

  ### Modify config settings to prevent darwin-rebuild errors caused by determinate-nixd
  ### doing things differently.

  # Disable the activation script that attempts to reload the nix-daemon on config change
  # -- it does it by name (org.nixos.nix-daemon) which is wrong for us, and
  # determinate-nixd manages the nix.conf and can make decisions about reloading /
  # restarting when it needs to[1][2].
  # [1]: https://github.com/LnL7/nix-darwin/blob/55d07816a0944f06a9df5ef174999a72fa4060c7/modules/nix/default.nix#L827-L836
  # [2]: https://github.com/LnL7/nix-darwin/blob/55d07816a0944f06a9df5ef174999a72fa4060c7/modules/system/activation-scripts.nix#L67
  config.system.activationScripts.nix-daemon.text = "";

  # determinate-nixd does not support nix-channels. Thus, don't try to verify them[1][2].
  # [1]: https://github.com/LnL7/nix-darwin/blob/55d07816a0944f06a9df5ef174999a72fa4060c7/modules/system/checks.nix#L321C5-L325
  # [2]: https://github.com/LnL7/nix-darwin/blob/55d07816a0944f06a9df5ef174999a72fa4060c7/modules/system/checks.nix#L158-L175
  config.system.checks.verifyNixChannels = false;

  # Determinate.pkg can handle fixing build users itself.
  config.system.checks.verifyBuildUsers = false;


  ### Help the user migrate from managed to unmanaged

  # Scenario: user has an upstream Nix installation that they want to transition to Determinate
  config.system.activationScripts.preActivation.text = lib.mkBefore failWithoutDeterminateMessage;
  config.system.activationScripts.preUserActivation.text = lib.mkBefore failWithoutDeterminateMessage;

  # Scenario: user has previously used the "default" determinate module before we went to an unmanaged nix.
  #
  # The symlinks defeat nix-darwin's activation-time unload/update/reload logic for launchd services.
  # Because the symlink points to the file, they have the same content, nix-darwin won't try to update or reload the service.
  #
  # It also defeats nix-darwin's deletion logic, which will delete any LaunchDaemon that was managed by the previously active generation and is not present in the now-activating generation.
  # Since the file will now exist in the new profile's LaunchDaemons directory, it will not be deleted.
  config.environment.launchDaemons."systems.determinate.nix-store.plist".source = pkgs.runCommand "nix-store-ln" {} ''
    ln -s /Library/LaunchDaemons/systems.determinate.nix-store.plist $out
  '';
  config.environment.launchDaemons."systems.determinate.nix-daemon.plist".source = pkgs.runCommand "nix-daemon-ln" {} ''
    ln -s /Library/LaunchDaemons/systems.determinate.nix-daemon.plist $out
  '';
}
