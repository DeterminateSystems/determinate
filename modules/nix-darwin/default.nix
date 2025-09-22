{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.determinate-nix;

  inherit (lib)
    all
    concatMapStrings
    concatStringsSep
    filterAttrs
    hasAttr
    literalExpression
    mapAttrsToList
    mkDefault
    mkEnableOption
    mkForce
    mkIf
    mkMerge
    mkOption
    optionalString
    types
    ;

  inherit (import ./config/config.nix { inherit lib; }) mkCustomConfig;

  semanticConfType =
    with types;
    let
      confAtom =
        nullOr (oneOf [
          bool
          int
          float
          str
          path
          package
        ])
        // {
          description = "Nix configuration atom (null, Boolean, integer, float, list, derivation, path, attribute set)";
        };
    in
    attrsOf (either confAtom (listOf confAtom));

  # Settings that Determinate Nix handles for you
  disallowedOptions = [
    "always-allow-substitutes"
    "bash-prompt-prefix"
    "external-builders"
    "extra-nix-path"
    "netrc-file"
    "ssl-cert-file"
    "upgrade-nix-store-path-url"
  ];

  managedDefault = name: default: {
    default =
      if cfg.enable then
        default
      else
        throw ''
          ${name}: accessed when `determinate-nix.enable` is off; this is a bug in
          nix-darwin or a third-party module
        '';
    defaultText = default;
  };

  # Various constant values
  customConfFile = "nix/nix.custom.conf";
in
{
  options = {
    determinate-nix = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to enable configuring Determinate Nix via nix-darwin.

          Disabling this stops nix-darwin from managing:

          1. Custom Determinate Nix settings in {file}`/etc/${customConfFile}`.
          2. Remote Nix builders
          3. A local Linux builder (distinct from Determinate Nix's native Linux builder).
        '';
      };

      buildMachines = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              hostName = mkOption {
                type = types.str;
                example = "nixbuilder.example.org";
                description = ''
                  The hostname of the build machine.
                '';
              };
              protocol = mkOption {
                type = types.enum [
                  null
                  "ssh"
                  "ssh-ng"
                ];
                default = "ssh";
                example = "ssh-ng";
                description = ''
                  The protocol used for communicating with the build machine.
                  Use `ssh-ng` if your remote builder and your
                  local Nix version support that improved protocol.

                  Use `null` when trying to change the special localhost builder
                  without a protocol which is for example used by hydra.
                '';
              };
              system = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "x86_64-linux";
                description = ''
                  The system type the build machine can execute derivations on.
                  Either this attribute or {var}`systems` must be
                  present, where {var}`system` takes precedence if
                  both are set.
                '';
              };
              systems = mkOption {
                type = types.listOf types.str;
                default = [ ];
                example = [
                  "x86_64-linux"
                  "aarch64-linux"
                ];
                description = ''
                  The system types the build machine can execute derivations on.
                  Either this attribute or {var}`system` must be
                  present, where {var}`system` takes precedence if
                  both are set.
                '';
              };
              sshUser = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "builder";
                description = ''
                  The username to log in as on the remote host. This user must be
                  able to log in and run nix commands non-interactively. It must
                  also be privileged to build derivations, so must be included in
                  {option}`determinate-nix.settings.trusted-users`.
                '';
              };
              sshKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "/root/.ssh/id_buildhost_builduser";
                description = ''
                  The path to the SSH private key with which to authenticate on
                  the build machine. The private key must not have a passphrase.
                  If null, the building user (root on NixOS machines) must have an
                  appropriate ssh configuration to log in non-interactively.

                  Note that for security reasons, this path must point to a file
                  in the local filesystem, *not* to the nix store.
                '';
              };
              maxJobs = mkOption {
                type = types.int;
                default = 1;
                description = ''
                  The number of concurrent jobs the build machine supports. The
                  build machine will enforce its own limits, but this allows hydra
                  to schedule better since there is no work-stealing between build
                  machines.
                '';
              };
              speedFactor = mkOption {
                type = types.int;
                default = 1;
                description = ''
                  The relative speed of this builder. This is an arbitrary integer
                  that indicates the speed of this builder, relative to other
                  builders. Higher is faster.
                '';
              };
              mandatoryFeatures = mkOption {
                type = types.listOf types.str;
                default = [ ];
                example = [ "big-parallel" ];
                description = ''
                  A list of features mandatory for this builder. The builder will
                  be ignored for derivations that don't require all features in
                  this list. All mandatory features are automatically included in
                  {var}`supportedFeatures`.
                '';
              };
              supportedFeatures = mkOption {
                type = types.listOf types.str;
                default = [ ];
                example = [
                  "kvm"
                  "big-parallel"
                ];
                description = ''
                  A list of features supported by this builder. The builder will
                  be ignored for derivations that require features not in this
                  list.
                '';
              };
              publicHostKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  The (base64-encoded) public host key of this builder. The field
                  is calculated via {command}`base64 -w0 /etc/ssh/ssh_host_type_key.pub`.
                  If null, SSH will use its regular known-hosts file when connecting.
                '';
              };
            };
          }
        );
        default = [ ];
        description = ''
          This option lists the machines to be used if distributed builds are
          enabled (see {option}`determinate-nix.distributedBuilds`).
          Nix will perform derivations on those machines via SSH by copying the
          inputs to the Nix store on the remote machine, starting the build,
          then copying the output back to the local Nix store.
        '';
      };

      distributedBuilds = mkOption {
        type = types.bool;
        inherit (managedDefault "determinate-nix.distributedBuilds" false) default defaultText;
        description = ''
          Whether to distribute builds to the machines listed in
          {option}`determinate-nix.buildMachines`.
        '';
      };

      # Environment variables for running Nix.
      envVars = mkOption {
        type = types.attrs;
        internal = true;
        inherit (managedDefault "determinate-nix.envVars" { }) default defaultText;
        description = "Environment variables used by Nix.";
      };

      nixpkgs-linux-builder =
        let
          linuxBuilderCfg = cfg.nixpkgs-linux-builder;
        in
        {
          enable = mkEnableOption "Nixpkgs Linux builder (distinct from Determinate Nix's native Linux builder)";

          package = mkOption {
            type = types.package;
            default = pkgs.darwin.linux-builder;
            defaultText = "pkgs.darwin.linux-builder";
            apply =
              pkg:
              pkg.override (old: {
                # the linux-builder package requires `modules` as an argument, so it's
                # always non-null.
                modules = old.modules ++ [ linuxBuilderCfg.config ];
              });
            description = ''
              This option specifies the non-native Linux builder to use.
            '';
          };

          config = mkOption {
            type = types.deferredModule;
            default = { };
            example = literalExpression ''
              ({ pkgs, ... }:

              {
                environment.systemPackages = [ pkgs.neovim ];
              })
            '';
            description = ''
              This option specifies extra NixOS configuration for the Nixpkgs Linux builder.
              You should first use the Nixpkgs Linux builder without changing the builder configuration, otherwise you may not be able to build the Linux builder (unless you're using the native Linux builder).
            '';
          };

          ephemeral = mkEnableOption ''
            wipe the builder's filesystem on every restart.

            This is disabled by default as maintaining the builder's Nix Store reduces
            rebuilds. You can enable this if you don't want your builder to accumulate
            state.
          '';

          mandatoryFeatures = mkOption {
            type = types.listOf types.str;
            default = [ ];
            defaultText = literalExpression ''[]'';
            example = literalExpression ''[ "big-parallel" ]'';
            description = ''
              A list of features mandatory for the Nixpkgs Linux builder. The builder is
              ignored for derivations that don't require all features in
              this list. All mandatory features are automatically included in
              {var}`supportedFeatures`.

              This sets the corresponding `determinate-nix.buildMachines.*.mandatoryFeatures` option.
            '';
          };

          maxJobs = mkOption {
            type = types.ints.positive;
            default = linuxBuilderCfg.package.nixosConfig.virtualisation.cores;
            defaultText = ''
              The `virtualisation.cores` of the build machine's final NixOS configuration.
            '';
            example = 2;
            description = ''
              Instead of setting this directly, you should set
              {option}`determinate-nix.linux-builder.config.virtualisation.cores` to configure
              the amount of cores the Linux builder should have.

              The number of concurrent jobs the Linux builder machine supports. The
              build machine will enforce its own limits, but this allows hydra
              to schedule better since there is no work-stealing between build
              machines.

              This sets the corresponding `determinate-nix.buildMachines.*.maxJobs` option.
            '';
          };

          protocol = mkOption {
            type = types.str;
            default = "ssh-ng";
            defaultText = literalExpression ''"ssh-ng"'';
            example = literalExpression ''"ssh"'';
            description = ''
              The protocol used for communicating with the build machine.  Use
              `ssh-ng` if your remote builder and your local Nix version support that
              improved protocol.

              Use `null` when trying to change the special localhost builder without a
              protocol which is for example used by hydra.
            '';
          };

          speedFactor = mkOption {
            type = types.ints.positive;
            default = 1;
            defaultText = literalExpression ''1'';
            description = ''
              The relative speed of the Nixpkgs Linux builder. This is an arbitrary integer
              that indicates the speed of this builder, relative to other
              builders. Higher is faster.

              This sets the corresponding `determinate-nix.buildMachines.*.speedFactor` option.
            '';
          };

          supportedFeatures = mkOption {
            type = types.listOf types.str;
            default = [
              "kvm"
              "benchmark"
              "big-parallel"
            ];
            defaultText = literalExpression ''[ "kvm" "benchmark" "big-parallel" ]'';
            example = literalExpression ''[ "kvm" "big-parallel" ]'';
            description = ''
              A list of features supported by the Nixpkgs Linux builder. The builder will
              be ignored for derivations that require features not in this
              list.

              This sets the corresponding `determinate-nix.buildMachines.*.supportedFeatures` option.
            '';
          };

          systems = mkOption {
            type = types.listOf types.str;
            default = [ linuxBuilderCfg.package.nixosConfig.nixpkgs.hostPlatform.system ];
            defaultText = ''
              The `nixpkgs.hostPlatform.system` of the build machine's final NixOS configuration.
            '';
            example = literalExpression ''
              [
                "x86_64-linux"
                "aarch64-linux"
              ]
            '';
            description = ''
              This option specifies system types the build machine can execute derivations on.

              This sets the corresponding `nix.buildMachines.*.systems` option.
            '';
          };

          workingDirectory = mkOption {
            type = types.str;
            default = "/var/lib/linux-builder";
            description = ''
              The working directory of the Linux builder daemon process.
            '';
          };
        };

      registry = mkOption {
        type = types.attrsOf (
          types.submodule (
            let
              referenceAttrs =
                with types;
                attrsOf (oneOf [
                  str
                  int
                  bool
                  package
                ]);
            in
            { config, name, ... }:
            {
              options = {
                from = mkOption {
                  type = referenceAttrs;
                  example = {
                    type = "indirect";
                    id = "nixpkgs";
                  };
                  description = "The flake reference to be rewritten.";
                };
                to = mkOption {
                  type = referenceAttrs;
                  example = {
                    type = "github";
                    owner = "my-org";
                    repo = "my-nixpkgs";
                  };
                  description = "The flake reference {option}`from` is rewritten to.";
                };
                flake = mkOption {
                  type = types.nullOr types.attrs;
                  default = null;
                  example = literalExpression "nixpkgs";
                  description = ''
                    The flake input {option}`from` is rewritten to.
                  '';
                };
                exact = mkOption {
                  type = types.bool;
                  default = true;
                  description = ''
                    Whether the {option}`from` reference needs to match exactly. If set,
                    a {option}`from` reference like `nixpkgs` does not
                    match with a reference like `nixpkgs/nixos-20.03`.
                  '';
                };
              };
              config = {
                from = mkDefault {
                  type = "indirect";
                  id = name;
                };
                to = mkIf (config.flake != null) (
                  mkDefault (
                    {
                      type = "path";
                      path = config.flake.outPath;
                    }
                    // filterAttrs (
                      n: _: n == "lastModified" || n == "rev" || n == "revCount" || n == "narHash"
                    ) config.flake
                  )
                );
              };
            }
          )
        );
        inherit (managedDefault "nix.registry" { }) default defaultText;
        description = ''
          The system-wide flake registry. We recommend using the registry only for CLI commands, such as
          `nix search nixpkgs ponysay` or `nix build nixpkgs#cowsay`, and not for flake references in Nix code.
        '';
      };

      settings = mkOption {
        type = types.submodule {
          freeformType = semanticConfType;

          options = {
            auto-optimise-store = mkOption {
              type = types.bool;
              default = false;
              example = true;
              description = ''
                If set to `true`, Determinate Nix automatically detects files in the store
                that have identical contents and replaces them with hard links to a single copy.
                This saves disk space. If set to `false` (the default), you can enable
                {option}`determinate-nix.optimise.automatic` to run {command}`nix-store --optimise`
                periodically to get rid of duplicate files. You can also run
                {command}`nix-store --optimise` manually.
              '';
            };

            cores = mkOption {
              type = types.int;
              default = 0;
              example = 64;
              description = ''
                This option defines the maximum number of concurrent tasks during
                one build. It affects, e.g., -j option for make.
                The special value 0 means that the builder should use all
                available CPU cores in the system. Some builds may become
                non-deterministic with this option; use with care! Packages will
                only be affected if enableParallelBuilding is set for them.
              '';
            };

            extra-sandbox-paths = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [
                "/dev"
                "/proc"
              ];
              description = ''
                Directories from the host filesystem to be included
                in the sandbox.
              '';
            };

            sandbox = mkOption {
              type = types.either types.bool (types.enum [ "relaxed" ]);
              default = false;
              description = ''
                If set, Nix performs builds in a sandboxed environment that it
                sets up automatically for each build. This prevents impurities
                in builds by disallowing access to dependencies outside of the Nix
                store by using network and mount namespaces in a chroot environment. It
                doesn't affect derivation hashes, so changing this option doesn't cause
                Nix to trigger a rebuild of packages.
              '';
            };

            trusted-users = mkOption {
              type = types.listOf types.str;
              inherit (managedDefault "determinate-nix.trusted-users" [ ]) default defaultText;
              example = [
                "root"
                "alice"
                "@admin"
              ];
              description = ''
                A list of names of users that have additional rights when
                connecting to the Nix daemon, such as the ability to specify
                additional binary caches, or to import unsigned NARs. You
                can also specify groups by prefixing them with
                `@`; for instance,
                `@admin` means all users in the wheel
                group.
              '';
            };
          };
        };
        default = { };
      };
    };
  };

  config = mkIf (cfg.enable) (mkMerge [
    # Nixpkgs Linux builder not enabled
    (mkIf (!cfg.nixpkgs-linux-builder.enable) {
      system.activationScripts.preActivation.text = ''
        rm -rf ${cfg.nixpkgs-linux-builder.workingDirectory}
      '';
    })

    # Nixpkgs Linux builder enabled
    (mkIf (cfg.nixpkgs-linux-builder.enable) {
      assertions = [
        {
          assertion = cfg.enable;
          message = ''`determinate-nix.linux-builder.enable` requires `determinate-nix.enable`'';
        }
      ];

      system.activationScripts.preActivation.text = ''
        # Migrate if using the old working directory
        if [ -e /var/lib/darwin-builder ] && [ ! -e ${cfg.nixpkgs-linux-builder.workingDirectory} ]; then
          mv /var/lib/darwin-builder ${cfg.nixpkgs-linux-builder.workingDirectory}
        fi

        mkdir -p ${cfg.nixpkgs-linux-builder.workingDirectory}
      '';

      launchd.daemons.linux-builder = {
        environment = {
          inherit (cfg.environment.variables) NIX_SSL_CERT_FILE;
        };

        # create-builder uses TMPDIR to share files with the builder, notably certs.
        # macOS will clean up files in /tmp automatically that haven't been accessed in 3+ days.
        # If we let it use /tmp, leaving the computer asleep for 3 days makes the certs vanish.
        # So we'll use /run/org.nixos.linux-builder instead and clean it up ourselves.
        script = ''
          export TMPDIR=/run/org.nixos.linux-builder USE_TMPDIR=1
          rm -rf $TMPDIR
          mkdir -p $TMPDIR
          trap "rm -rf $TMPDIR" EXIT
          ${optionalString cfg.nixpkgs-linux-builder.ephemeral ''
            rm -f ${cfg.nixpkgs-linux-builder.workingDirectory}/${cfg.nixpkgs-linux-builder.package.nixosConfig.networking.hostName}.qcow2
          ''}
          ${cfg.nixpkgs-linux-builder.package}/bin/create-builder
        '';

        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          WorkingDirectory = cfg.nixpkgs-linux-builder.workingDirectory;
        };
      };

      environment.etc."ssh/ssh_config.d/100-linux-builder.conf".text = ''
        Host linux-builder
          User builder
          Hostname localhost
          HostKeyAlias linux-builder
          Port 31022
          IdentityFile /etc/nix/builder_ed25519
      '';

      determinate-nix.distributedBuilds = true;

      determinate-nix.buildMachines = [
        {
          hostName = "linux-builder";
          sshUser = "builder";
          sshKey = "/etc/nix/builder_ed25519";
          publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQkorVXVFV2RWQ2Igcm9vdEBuaXhvcwo=";
          inherit (cfg)
            mandatoryFeatures
            maxJobs
            protocol
            speedFactor
            supportedFeatures
            systems
            ;
        }
      ];

      determinate-nix.settings.builders-use-substitutes = true;
    })

    {
      assertions = [
        {
          assertion = all (key: !hasAttr key cfg.settings) disallowedOptions;
          message = ''
            These settings are not allowed in `determinate-nix.settings`:
              ${concatStringsSep ", " disallowedOptions}
          '';
        }
      ];

      warnings = [
        (mkIf (
          !cfg.distributedBuilds && cfg.buildMachines != [ ]
        ) "determinate-nix.distributedBuilds is not enabled, thus build machines aren't configured.")
      ];

      # Disable nix-darwin's internal mechanisms for handling Nix configuration
      nix.enable = mkForce false;

      environment.etc.${customConfFile}.text = concatStringsSep "\n" (
        [
          "# This custom configuration file for Determinate Nix is generated by the determinate module for nix-darwin."
          "# Update your custom settings by changing your nix-darwin configuration, not by modifying this file directly."
          ""
        ]
        ++ mkCustomConfig cfg.settings
      );

      # Set up the environment variables for running Nix
      environment.variables = cfg.envVars;

      # Create the Nix flake registry
      environment.etc."nix/registry.json" = mkIf (cfg.registry != [ ]) {
        text = builtins.toJSON {
          version = 2;
          flakes = mapAttrsToList (n: v: { inherit (v) from to exact; }) cfg.registry;
        };
      };

      # List of machines for distributed Nix builds in the format
      # expected by build-remote.pl.
      environment.etc."nix/machines" = mkIf (cfg.buildMachines != [ ]) {
        text = concatMapStrings (
          machine:
          (concatStringsSep " " ([
            "${optionalString (machine.protocol != null) "${machine.protocol}://"}${
              optionalString (machine.sshUser != null) "${machine.sshUser}@"
            }${machine.hostName}"
            (
              if machine.system != null then
                machine.system
              else if machine.systems != [ ] then
                concatStringsSep "," machine.systems
              else
                "-"
            )
            (if machine.sshKey != null then machine.sshKey else "-")
            (toString machine.maxJobs)
            (toString machine.speedFactor)
            (
              let
                res = (machine.supportedFeatures ++ machine.mandatoryFeatures);
              in
              if (res == [ ]) then "-" else (concatStringsSep "," res)
            )
            (
              let
                res = machine.mandatoryFeatures;
              in
              if (res == [ ]) then "-" else (concatStringsSep "," machine.mandatoryFeatures)
            )
            (if machine.publicHostKey != null then machine.publicHostKey else "-")
          ]))
          + "\n"
        ) cfg.buildMachines;
      };

      determinate-nix.settings = mkMerge [
        (mkIf (!cfg.distributedBuilds) { builders = null; })
      ];
    }
  ]);
}
