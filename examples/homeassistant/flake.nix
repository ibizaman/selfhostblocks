{
  description = "Home Assistant example for Self Host Blocks";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";

    selfhostblocks.url = "/home/timi/Projects/selfhostblocks";
    selfhostblocks.inputs.nixpkgs.follows = "nixpkgs";
    selfhostblocks.inputs.sops-nix.follows = "sops-nix";
  };

  outputs = inputs@{ self, nixpkgs, sops-nix, selfhostblocks, ... }: {
    colmena = {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
        };
        specialArgs = inputs;
      };

      myserver = {
        deployment = {
          targetHost = "localhost";
          targetPort = 2222;
          targetUser = "nixos";
        };

        imports = [
          ./configuration.nix
          sops-nix.nixosModules.default
          selfhostblocks.nixosModules.default
        ];

        shb.home-assistant = {
          enable = true;
          subdomain = "ha";
          sopsFile = ./secrets.yaml;
        };
      };
    };
  };
}
