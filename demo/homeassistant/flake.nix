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

      myserver = { config, ... }: {
        imports = [
          ./configuration.nix
          sops-nix.nixosModules.default
          selfhostblocks.nixosModules.x86_64-linux.default
        ];

        shb.ldap = {
          enable = true;
          domain = "example.com";
          subdomain = "ldap";
          ldapPort = 3890;
          httpPort = 17170;
          dcdomain = "dc=example,dc=com";
          sopsFile = ./secrets.yaml;
        };

        shb.home-assistant = {
          enable = true;
          domain = "example.com";
          ldapEndpoint = "http://127.0.0.1:${builtins.toString config.shb.ldap.httpPort}";
          subdomain = "ha";
          sopsFile = ./secrets.yaml;
        };

        # Set to true for more debug info with `journalctl -f -u nginx`.
        shb.nginx.accessLog = false;
        shb.nginx.debugLog = false;
      };
    };
  };
}
