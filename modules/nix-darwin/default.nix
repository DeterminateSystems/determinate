{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.determinateNix;
  nixosVmBasedLinuxBuilderCfg = cfg.nixosVmBasedLinuxBuilder;

  inherit (lib) types;

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
          ${name}: accessed when `determinateNix.enable` is off; this is a bug in
          nix-darwin or a third-party module
        '';
    defaultText = default;
  };

  # Various constant values
  customConfFile = "nix/nix.custom.conf";
  registryFile = "nix/registry.json";
  builderIdentityFile = "/etc/nix/builder_ed25519";
in
{
  # Rename the `determinate-nix` attribute to `determinateNix` to standardize on dromedary case.
  imports = [
    (lib.mkRenamedOptionModule [ "determinate-nix" ] [ "determinateNix" ])
  ];

  options = {
    determinateNix = {
      enable = lib.mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to enable configuring Determinate Nix via nix-darwin.
          If you set `enable` to `true`, this module does two things:

          1. It prevents nix-darwin from managing Nix's configuration in {file}`/etc/nix/nix.conf`, leaving that configuration to Determinate Nixd.
          2. It enables you to manage any custom Nix settings in {file}`/etc/${customConfFile}` using the `determinateNix.customSettings` attribute.

          Like the standard nix-darwin module, this Determinate module enables you to configure:

          1. VM-based Nix builders using the `buildMachines` setting.
          2. A local VM-based Linux builder from Nixpkgs. Note that this is distinct from Determinate Nix's own native Linux builder, which uses macOS's built-in Virtualization framework. We recommend using this native Linux builder but still support the Nixpkgs builder.
        '';
      };

      # Local build machines specified in `/etc/nix/machines`.
      buildMachines = lib.mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              hostName = lib.mkOption {
                type = types.str;
                example = "nixbuilder.example.org";
                description = ''
                  The hostname of the build machine.
                '';
              };
              protocol = lib.mkOption {
                type = types.nullOr (
                  types.enum [
                    "ssh"
                    "ssh-ng"
                  ]
                );
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
              system = lib.mkOption {
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
              systems = lib.mkOption {
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
              sshUser = lib.mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "builder";
                description = ''
                  The username to log in as on the remote host. This user must be
                  able to log in and run nix commands non-interactively. It must
                  also be privileged to build derivations, so must be included in
                  {option}`determinateNix.customSettings.trusted-users`.
                '';
              };
              sshKey = lib.mkOption {
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
              maxJobs = lib.mkOption {
                type = types.int;
                default = 1;
                description = ''
                  The number of concurrent jobs the build machine supports. The
                  build machine will enforce its own limits, but this allows hydra
                  to schedule better since there is no work-stealing between build
                  machines.
                '';
              };
              speedFactor = lib.mkOption {
                type = types.int;
                default = 1;
                description = ''
                  The relative speed of this builder. This is an arbitrary integer
                  that indicates the speed of this builder, relative to other
                  builders. Higher is faster.
                '';
              };
              mandatoryFeatures = lib.mkOption {
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
              supportedFeatures = lib.mkOption {
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
              publicHostKey = lib.mkOption {
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
        inherit (managedDefault "determinateNix.buildMachines" [ ]) default defaultText;
        description = ''
          This option lists the machines to be used if distributed builds are
          enabled (see {option}`determinateNix.distributedBuilds`).
          Nix will perform derivations on those machines via SSH by copying the
          inputs to the Nix store on the remote machine, starting the build,
          then copying the output back to the local Nix store.
        '';
      };

      # Determinate Nixd configuration: https://docs.determinate.systems/determinate-nix#determinate-nixd-configuration
      determinateNixd = lib.mkOption {
        type = types.submodule {
          options = {
            authentication.additionalNetrcSources = lib.mkOption {
              type = types.nullOr (
                types.listOf (
                  types.oneOf [
                    types.path
                    types.str
                  ]
                )
              );
              default = null;
              description = ''
                A list of paths to `netrc` files that are combined by Determinate Nixd and used by Determinate Nix. These files must exist and not be in `/nix/store` or the daemon refuses to start.
              '';
            };
            builder.state = lib.mkOption {
              type = types.nullOr (
                types.enum [
                  "disabled"
                  "enabled"
                ]
              );
              default = null;
              description = ''
                Whether Determinate Nix's native Linux builder is enabled.
              '';
            };
            garbageCollector.strategy = lib.mkOption {
              type = types.nullOr (
                types.enum [
                  "automatic"
                  "disabled"
                ]
              );
              default = null;
              description = ''
                The garbage collection strategy used by Determinate Nixd. `automatic` means that Determinate Nixd automatically collects garbage in the background while `disabled` means no garbage collection.
              '';
            };
          };
        };
        default = { };
        description = ''
          Configuration for Determinate Nixd. See: https://docs.determinate.systems/determinate-nix#determinate-nixd-configuration.
        '';
      };

      distributedBuilds = lib.mkOption {
        type = types.bool;
        inherit (managedDefault "determinateNix.distributedBuilds" false) default defaultText;
        description = ''
          Whether to distribute builds to the machines listed in
          {option}`determinateNix.buildMachines`.
        '';
      };

      # Environment variables for running Nix
      envVars = lib.mkOption {
        type = types.attrs;
        internal = true;
        inherit (managedDefault "determinateNix.envVars" { }) default defaultText;
        description = "Environment variables used by Nix.";
      };

      nixosVmBasedLinuxBuilder = {
        enable = lib.mkEnableOption "NixOS-VM-based Linux builder for macOS (distinct from Determinate Nix's native Linux builder, which we recommend)";

        hostName = lib.mkOption {
          type = types.str;
          default = "linux-builder";
          description = ''
            The hostname for the NixOS-VM-based Linux builder.
          '';
        };

        package = lib.mkOption {
          type = types.package;
          default = pkgs.darwin.linux-builder;
          defaultText = "pkgs.darwin.linux-builder";
          apply =
            pkg:
            pkg.override (old: {
              # the linux-builder package requires `modules` as an argument, so it's
              # always non-null.
              modules = old.modules ++ [ nixosVmBasedLinuxBuilderCfg.config ];
            });
          description = ''
            This option specifies the NixOS-VM-based Linux builder to use.
          '';
        };

        config = lib.mkOption {
          type = types.deferredModule;
          default = { };
          example = lib.literalExpression ''
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

        ephemeral = lib.mkEnableOption ''
          Wipe the builder's filesystem on every restart.

          This is disabled by default because maintaining the builder's Nix store means fewer
          rebuilds. You can enable this if you don't want your builder to accumulate
          state.
        '';

        mandatoryFeatures = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          defaultText = lib.literalExpression ''[]'';
          example = lib.literalExpression ''[ "big-parallel" ]'';
          description = ''
            A list of features mandatory for the Nixpkgs Linux builder. The builder is
            ignored for derivations that don't require all features in
            this list. All mandatory features are automatically included in
            {var}`supportedFeatures`.

            This sets the corresponding `determinateNix.buildMachines.*.mandatoryFeatures` option.
          '';
        };

        maxJobs = lib.mkOption {
          type = types.ints.positive;
          default = nixosVmBasedLinuxBuilderCfg.package.nixosConfig.virtualisation.cores;
          defaultText = ''
            The `virtualisation.cores` of the build machine's final NixOS configuration.
          '';
          example = 2;
          description = ''
            Instead of setting this directly, you should set
            {option}`determinateNix.nixosVmBasedLinuxBuilder.config.virtualisation.cores` to configure
            the amount of cores the Linux builder should have.

            The number of concurrent jobs the Linux builder machine supports. The
            build machine will enforce its own limits, but this allows hydra
            to schedule better since there is no work-stealing between build
            machines.

            This sets the corresponding `determinateNix.buildMachines.*.maxJobs` option.
          '';
        };

        protocol = lib.mkOption {
          type = types.str;
          default = "ssh-ng";
          defaultText = lib.literalExpression ''"ssh-ng"'';
          example = lib.literalExpression ''"ssh"'';
          description = ''
            The protocol used for communicating with the build machine.  Use
            `ssh-ng` if your remote builder and your local Nix version support that
            improved protocol.

            Use `null` when trying to change the special localhost builder without a
            protocol which is for example used by hydra.
          '';
        };

        speedFactor = lib.mkOption {
          type = types.ints.positive;
          default = 1;
          defaultText = lib.literalExpression ''1'';
          description = ''
            The relative speed of the Nixpkgs Linux builder. This is an arbitrary integer
            that indicates the speed of this builder, relative to other
            builders. Higher is faster.

            This sets the corresponding `determinateNix.buildMachines.*.speedFactor` option.
          '';
        };

        supportedFeatures = lib.mkOption {
          type = types.listOf types.str;
          default = [
            "kvm"
            "benchmark"
            "big-parallel"
          ];
          defaultText = lib.literalExpression ''[ "kvm" "benchmark" "big-parallel" ]'';
          example = lib.literalExpression ''[ "kvm" "big-parallel" ]'';
          description = ''
            A list of features supported by the Nixpkgs Linux builder. The builder will
            be ignored for derivations that require features not in this
            list.

            This sets the corresponding `determinateNix.buildMachines.*.supportedFeatures` option.
          '';
        };

        systems = lib.mkOption {
          type = types.listOf types.str;
          default = [ nixosVmBasedLinuxBuilderCfg.package.nixosConfig.nixpkgs.hostPlatform.system ];
          defaultText = ''
            The `nixpkgs.hostPlatform.system` of the build machine's final NixOS configuration.
          '';
          example = lib.literalExpression ''
            [
              "x86_64-linux"
              "aarch64-linux"
            ]
          '';
          description = ''
            This option specifies system types the build machine can execute derivations on.

            This sets the corresponding `determinateNix.buildMachines.*.systems` option.
          '';
        };

        workingDirectory = lib.mkOption {
          type = types.str;
          default = "/var/lib/${nixosVmBasedLinuxBuilderCfg.hostName}";
          description = ''
            The working directory of the Linux builder daemon process.
          '';
        };
      };

      registry = lib.mkOption {
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
                from = lib.mkOption {
                  type = referenceAttrs;
                  example = {
                    type = "indirect";
                    id = "nixpkgs";
                  };
                  description = "The flake reference to be rewritten.";
                };
                to = lib.mkOption {
                  type = referenceAttrs;
                  example = {
                    type = "github";
                    owner = "my-org";
                    repo = "my-nixpkgs";
                  };
                  description = "The flake reference {option}`from` is rewritten to.";
                };
                flake = lib.mkOption {
                  type = types.nullOr types.attrs;
                  default = null;
                  example = lib.literalExpression "nixpkgs";
                  description = ''
                    The flake input {option}`from` is rewritten to.
                  '';
                };
                exact = lib.mkOption {
                  type = types.bool;
                  default = true;
                  description = ''
                    Whether the {option}`from` reference needs to match exactly. If set,
                    a {option}`from` reference like `nixpkgs` does not
                    match with a reference like `nixpkgs/nixos-25.05`.
                  '';
                };
              };
              config = {
                from = lib.mkDefault {
                  type = "indirect";
                  id = name;
                };
                to = lib.mkIf (config.flake != null) (
                  lib.mkDefault (
                    {
                      type = "path";
                      path = config.flake.outPath;
                    }
                    // lib.filterAttrs (
                      n: _: n == "lastModified" || n == "rev" || n == "revCount" || n == "narHash"
                    ) config.flake
                  )
                );
              };
            }
          )
        );
        inherit (managedDefault "determinateNix.registry" { }) default defaultText;
        description = ''
          The system-wide flake registry. We recommend using the registry only for CLI commands, such as
          `nix search nixpkgs ponysay` or `nix build nixpkgs#cowsay`, and not for flake references in Nix code.
        '';
      };

      customSettings = lib.mkOption {
        type = types.submodule {
          freeformType = semanticConfType;
            cores = lib.mkOption {
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

            extra-sandbox-paths = lib.mkOption {
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

            sandbox = lib.mkOption {
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

            trusted-users = lib.mkOption {
              type = types.listOf types.str;
              inherit (managedDefault "determinateNix.trusted-users" [ ]) default defaultText;
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

  config = lib.mkIf (cfg.enable) (
    lib.mkMerge [
      # Nixpkgs Linux builder enabled
      (lib.mkIf (nixosVmBasedLinuxBuilderCfg.enable) {
        assertions = [
          {
            assertion = config.determinateNix.enable;
            message = ''
              Setting `determinateNix.nixosVmBasedLinuxBuilder.enable = true` requires you to set `determinateNix.enable = true` as well.
            '';
          }
        ];

        system.activationScripts.preActivation.text =
          let
            directory = nixosVmBasedLinuxBuilderCfg.workingDirectory;
          in
          ''
            # Migrate if using the old working directory
            if [ -e /var/lib/darwin-builder ] && [ ! -e ${directory} ]; then
              mv /var/lib/darwin-builder ${directory}
            fi

            mkdir -p ${directory}
          '';

        launchd.daemons.${nixosVmBasedLinuxBuilderCfg.hostName} = {
          environment.NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

          # create-builder uses TMPDIR to share files with the builder, notably certs.
          # macOS will clean up files in /tmp automatically that haven't been accessed in 3+ days.
          # If we let it use /tmp, leaving the computer asleep for 3 days makes the certs vanish.
          # So we'll use /run/org.nixos.linux-builder instead and clean it up ourselves.
          script = ''
            export TMPDIR=/run/org.nixos.${nixosVmBasedLinuxBuilderCfg.hostName} USE_TMPDIR=1
            rm -rf $TMPDIR
            mkdir -p $TMPDIR
            trap "rm -rf $TMPDIR" EXIT
            ${lib.optionalString nixosVmBasedLinuxBuilderCfg.ephemeral ''
              rm -f ${nixosVmBasedLinuxBuilderCfg.workingDirectory}/${nixosVmBasedLinuxBuilderCfg.package.nixosConfig.networking.hostName}.qcow2
            ''}
            ${lib.getExe' nixosVmBasedLinuxBuilderCfg.package "create-builder"}
          '';

          serviceConfig =
            let
              logFile = "/var/log/nixos-based-vm-builder.log";
            in
            {
              KeepAlive = true;
              RunAtLoad = true;
              StandardErrorPath = logFile;
              StandardOutPath = logFile;
              WorkingDirectory = nixosVmBasedLinuxBuilderCfg.workingDirectory;
            };
        };

        environment.etc."ssh/ssh_config.d/100-${nixosVmBasedLinuxBuilderCfg.hostName}.conf".text = ''
          Host ${nixosVmBasedLinuxBuilderCfg.hostName}
            User builder
            Hostname localhost
            HostKeyAlias ${nixosVmBasedLinuxBuilderCfg.hostName}
            Port 31022
            IdentityFile ${builderIdentityFile}
        '';

        # Override Determinate Nix config
        determinateNix = {
          buildMachines = [
            {
              hostName = nixosVmBasedLinuxBuilderCfg.hostName;
              sshUser = "builder";
              sshKey = builderIdentityFile;
              publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQkorVXVFV2RWQ2Igcm9vdEBuaXhvcwo=";
              inherit (nixosVmBasedLinuxBuilderCfg)
                mandatoryFeatures
                maxJobs
                protocol
                speedFactor
                supportedFeatures
                systems
                ;
            }
          ];
          # Override Determinate Nixd config to disable the native Linux builder
          determinateNixd.builder.state = "disabled";
          distributedBuilds = true;
          customSettings.builders-use-substitutes = true;
        };
      })

      # Nixpkgs Linux builder disabled
      (lib.mkIf (!nixosVmBasedLinuxBuilderCfg.enable) {
        system.activationScripts.preActivation.text = ''
          rm -rf ${nixosVmBasedLinuxBuilderCfg.workingDirectory}
        '';
      })

      {
        assertions = [
          {
            assertion = lib.all (key: !lib.hasAttr key cfg.customSettings) disallowedOptions;
            message = ''
              These settings are not allowed in `determinateNix.customSettings`:
                ${lib.concatStringsSep ", " disallowedOptions}
            '';
          }
        ];

        warnings = [
          (lib.mkIf (
            !cfg.distributedBuilds && cfg.buildMachines != [ ]
          ) "`determinateNix.distributedBuilds` is not enabled, thus build machines aren't configured.")
        ];

        # Disable nix-darwin's internal mechanisms for handling Nix configuration
        nix.enable = lib.mkForce false;

        environment.etc.${customConfFile}.text = lib.concatStringsSep "\n" (
          [
            "# This custom configuration file for Determinate Nix is generated by the determinate module for nix-darwin."
            "# Update your custom settings by changing your nix-darwin configuration, not by modifying this file directly."
            ""
          ]
          ++ mkCustomConfig cfg.customSettings
        );

        # Set up the environment variables for running Nix
        environment.variables = cfg.envVars;

        # Create the Nix flake registry
        environment.etc.${registryFile} = lib.mkIf (cfg.registry != { }) {
          text = builtins.toJSON {
            version = 2;
            flakes = lib.mapAttrsToList (n: v: { inherit (v) from to exact; }) cfg.registry;
          };
        };

        # Determinate Nixd configuration
        environment.etc."determinate/config.json" =
          let
            dnixd = cfg.determinateNixd;

            # Only include non-null attributes in the config file
            explicitlySetAttrs =
              let
                fragmentFor =
                  path:
                  let
                    v = lib.getAttrFromPath path dnixd;
                  in
                  lib.optionalAttrs (v != null) (lib.setAttrByPath path v);
              in
              builtins.foldl' lib.recursiveUpdate { } (
                # Keep this list up to date with the structure of the Determinate Nixd config file
                map fragmentFor [
                  [
                    "authentication"
                    "additionalNetrcSources"
                  ]
                  [
                    "builder"
                    "state"
                  ]
                  [
                    "garbageCollector"
                    "strategy"
                  ]
                ]
              );
          in
          lib.mkIf (explicitlySetAttrs != { }) {
            text = builtins.toJSON explicitlySetAttrs;
          };

        # List of machines for distributed Nix builds in the format
        # expected by build-remote.pl.
        environment.etc."nix/machines" = lib.mkIf (cfg.buildMachines != [ ]) {
          text = lib.concatMapStrings (
            machine:
            (lib.concatStringsSep " " ([
              "${lib.optionalString (machine.protocol != null) "${machine.protocol}://"}${
                lib.optionalString (machine.sshUser != null) "${machine.sshUser}@"
              }${machine.hostName}"
              (
                if machine.system != null then
                  machine.system
                else if machine.systems != [ ] then
                  lib.concatStringsSep "," machine.systems
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
                if (res == [ ]) then "-" else (lib.concatStringsSep "," res)
              )
              (
                let
                  res = machine.mandatoryFeatures;
                in
                if (res == [ ]) then "-" else (lib.concatStringsSep "," machine.mandatoryFeatures)
              )
              (if machine.publicHostKey != null then machine.publicHostKey else "-")
            ]))
            + "\n"
          ) cfg.buildMachines;
        };

        determinateNix.customSettings = lib.mkMerge [
          (lib.mkIf (cfg.registry != { }) { flake-registry = "/etc/${registryFile}"; })
          (lib.mkIf (nixosVmBasedLinuxBuilderCfg.enable) {
            # To enable fetching the cached NixOS VM
            trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
            trusted-users = [ "root" ];
            substituters = lib.mkAfter [ "https://cache.nixos.org/" ];
          })
        ];
      }
    ]
  );
}
