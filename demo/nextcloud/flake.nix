{
  description = "Home Assistant example for Self Host Blocks";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";

    selfhostblocks.url = "github:ibizaman/selfhostblocks";
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

        # Used by colmena to know which target host to deploy to.
        deployment = {
          targetHost = "example";
          targetUser = "nixos";
          targetPort = 2222;
        };

        shb.nextcloud = {
          enable = true;
          domain = "example.com";
          subdomain = "n";
          dataDir = "/var/lib/nextcloud";
          tracing = null;

          # This option is only needed because we do not access Nextcloud at the default port in the VM.
          externalFqdn = "n.example.com:8080";

          adminPassFile = config.sops.secrets."nextcloud/adminpass".path;
        };

        # Secret needed for services.nextcloud.config.adminpassFile.
        sops.secrets."nextcloud/adminpass" = {
          sopsFile = ./secrets.yaml;
          mode = "0440";
          owner = "nextcloud";
          group = "nextcloud";
          restartUnits = [ "phpfpm-nextcloud.service" ];
        };

        # Set to true for more debug info with `journalctl -f -u nginx`.
        shb.nginx.accessLog = true;
        shb.nginx.debugLog = false;
      };
    };
  };
}
