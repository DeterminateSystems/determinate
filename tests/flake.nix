{
  inputs = {
    determinate.url = "path:../";
    nixpkgs.follows = "determinate/nix/nixpkgs";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      ...
    }@inputs:
    {
      checks.x86_64-linux.nixos =
        (inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            inputs.determinate.nixosModules.default
            {
              fileSystems."/" = {
                device = "/dev/bogus";
                fsType = "ext4";
              };
              boot.loader.grub.devices = [ "/dev/bogus" ];
              system.stateVersion = "24.11";
            }
          ];
        }).config.system.build.toplevel;

      checks.aarch64-darwin.nix-darwin =
        (inputs.nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";

          modules = [
            inputs.determinate.darwinModules.default
            {
              determinateNix.enable = true;
              system.stateVersion = 5;
            }
          ];
        }).system;

      checks.aarch64-darwin.nix-darwin-custom-config =
        (inputs.nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";

          modules = [
            inputs.determinate.darwinModules.default
            {
              determinateNix = {
                enable = true;
                customSettings = {
                  auto-optimise-store = true;
                  extra-experimental-features = [ "build-time-fetch-tree" ];
                  flake-registry = "/etc/nix/flake-registry.json";
                };
                determinateNixd = {
                  builder.state = "disabled";
                  authentication.additionalNetrcSources = [ "/etc/extra/netrc" ];
                  garbageCollector.strategy = "disabled";
                };
              };
              system.stateVersion = 5;
            }
          ];
        }).system;
    };
}
