{
  inputs = {
    determinate.url = "path:../";
    nixpkgs.follows = "determinate/nix/nixpkgs";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      determinate,
      nix-darwin,
      ...
    }:
    let
      mkNixOS =
        {
          modules ? [ ],
        }:
        (nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            determinate.nixosModules.default
            {
              fileSystems."/" = {
                device = "/dev/bogus";
                fsType = "ext4";
              };
              boot.loader.grub.devices = [ "/dev/bogus" ];
              system.stateVersion = "24.11";
            }
          ] ++ modules;
        }).config.system.build.toplevel;

      mkNixDarwin =
        {
          modules ? [ ],
        }:
        (nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";

          modules = [
            determinate.darwinModules.default
            {
              system.stateVersion = 5;
            }
          ] ++ modules;
        }).system;
    in
    {
      packages.x86_64-linux = {
        default = mkNixOS { };

        custom-conf = mkNixOS {
          modules = [
            {
              nix.settings = {
                substituters = [ "https://nix-community.cachix.org" ];
                trusted-substituters = [ "https://nix-community.cachix.org" ];
                trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
              };
            }
          ];
        };
      };

      packages.aarch64-darwin = {
        default = mkNixDarwin { };

        # custom-conf = mkNixDarwin {
        #   modules = [
        #     {
        #       nix.settings = {
        #         substituters = [ "https://nix-community.cachix.org" ];
        #         trusted-substituters = [ "https://nix-community.cachix.org" ];
        #         trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
        #       };
        #     }
        #   ];
        # };
      };
    };
}
