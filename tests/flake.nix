{
  inputs = {
    determinate.url = "path:../";
    nixpkgs.follows = "determinate/nix/nixpkgs";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, determinate, nix-darwin, ... }: {
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
          system.stateVersion = "24.11";
        }
      ];
    }).config.system.build.toplevel;

    checks.aarch64-darwin.nix-darwin = (nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";

      modules = [
        determinate.darwinModules.default
        {
          system.stateVersion = 5;
        }
      ];
    }).system;
  };
}
