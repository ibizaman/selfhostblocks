{
  description = "SelfHostBlocks module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs@{ self, nixpkgs, sops-nix, ... }: {
    nixosModules.default = { config, ... }: {
      imports = [
        modules/authelia.nix
        modules/backup.nix
        modules/deluge.nix
        modules/hledger.nix
        modules/home-assistant.nix
        modules/jellyfin.nix
        modules/ldap.nix
        modules/monitoring.nix
        modules/nextcloud-server.nix
        modules/nginx.nix
        modules/ssl.nix
        modules/tinyproxy.nix
        modules/vpn.nix
      ];
    };

    # templates.default = {};  Would be nice to have a template
  };
}
