{ lib, options, ... }:

let
  postMigrationInstructions = ''
    You have successfully migrated your Determinate installation.
    Please remove `determinate.darwinModules.default` from your
    nix-darwin configuration, and ensure that you have nix-darwin’s own
    Nix installation management disabled by setting:

        nix.enable = false;

    Then run `darwin-rebuild switch` again.
  '';
in
{
  config =
    # Check if nix-darwin is new enough for the `nix.enable` option.
    if options.nix.enable.visible or true then
      {
        nix.enable = false;

        system.activationScripts.checks.text = lib.mkBefore ''
          if [[ ! -e /usr/local/bin/determinate-nixd ]]; then
            printf >&2 '\e[1;31merror: Determinate not installed, aborting activation\e[0m\n'
            printf >&2 'The Determinate nix-darwin module is no longer necessary. To install\n'
            printf >&2 'Determinate, remove `determinate.darwinModules.default` from your\n'
            printf >&2 'configuration and follow the installation installations at\n'
            printf >&2 '<https://docs.determinate.systems/getting-started/individuals>.\n'
            exit 2
          fi

          # Hack: Detect the version of the `.plist` set up by the old
          # version of the module.
          if grep -- '--nix-bin' /Library/LaunchDaemons/systems.determinate.nix-daemon.plist >/dev/null; then
            printf >&2 '\e[1;31merror: Determinate needs migration, aborting activation\e[0m\n'
            printf >&2 'Determinate now manages the Nix installation independently of the\n'
            printf >&2 'nix-darwin module.\n'
            printf >&2 '\n'
            printf >&2 'Please download and run the macOS installer from\n'
            printf >&2 '<https://docs.determinate.systems/getting-started/individuals> and then\n'
            printf >&2 'run `darwin-rebuild switch` again to migrate your installation.\n'
            exit 2
          fi

          if [[ ! -e /run/current-system/Library/LaunchDaemons/systems.determinate.nix-daemon.plist ]]; then
            printf >&2 '\e[1;31merror: deprecated Determinate module present, aborting activation\e[0m\n'
            printf >&2 '%s' ${lib.escapeShellArg postMigrationInstructions}
            exit 2
          fi
        '';

        system.activationScripts.extraActivation.text = lib.mkBefore ''
          # Hack: Make sure nix-darwin doesn’t clobber the Determinate
          # launchd daemons after they become unmanaged.

          determinateDaemonsStash=$(mktemp -d --suffix=determinate-daemons)
          cp -a /Library/LaunchDaemons/systems.determinate.{nix-daemon,nix-store}.plist "$determinateDaemonsStash"

          # shellcheck disable=SC2317
          restoreDeterminateDaemons() {
            printf >&2 'restoring Determinate daemons...\n'
            mv "$determinateDaemonsStash"/*.plist /Library/LaunchDaemons
            rmdir "$determinateDaemonsStash"
            launchctl load -w /Library/LaunchDaemons/systems.determinate.nix-daemon.plist
            launchctl load -w /Library/LaunchDaemons/systems.determinate.nix-store.plist
            printf >&2 '\n'
            printf >&2 '%s' ${lib.escapeShellArg postMigrationInstructions}
          }

          trap restoreDeterminateDaemons EXIT
        '';
      }
    else
      {
        assertions = [
          {
            assertion = false;
            message = ''
              Determinate now manages the Nix installation independently of
              the nix-darwin module.

              Please download and run the macOS installer from
              <https://docs.determinate.systems/getting-started>,
              update nix-darwin, and then run `darwin-rebuild switch`
              again to migrate your installation.
            '';
          }
        ];
      };
}
