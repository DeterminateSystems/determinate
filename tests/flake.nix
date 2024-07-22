{
  inputs = {
    determinate.url = "path:../";
    nixpkgs.follows = "determinate/nix/nixpkgs";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, determinate, home-manager, nix-darwin, ... }: {
    checks.x86_64-linux.nixos = (nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        determinate.nixosModules.default
        {
          fileSystems."/" = {
            device = "/dev/bogus";
            fsType = "ext4";
          };
          boot.loader.grub.devices = [ "/dev/bogus" ];
        }
      ];
    }).config.system.build.toplevel;

    checks.x86_64-linux.home-manager = (home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      modules = [
        determinate.homeManagerModules.default
        {
          home.stateVersion = "23.11";
          home.username = "example";
          home.homeDirectory = "/no-such/directory";
        }
      ];
    }).activation-script;

    checks.aarch64-darwin.nix-darwin = (nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";

      modules = [{
          imports = [
            determinate.darwinModules.default
          ];

          determinate.nix.primaryUser = "grahamc";
        }
      ];
    }).system;
  };
}