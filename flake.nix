{
  description = "SelfHostBlocks module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    nix-flake-tests.url = "github:antifuchs/nix-flake-tests";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, sops-nix, nix-flake-tests, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      {
        nixosModules.default = { config, ... }: {
          imports = [
            modules/arr.nix
            modules/authelia.nix
            modules/backup.nix
            modules/deluge.nix
            modules/davfs.nix
            modules/hledger.nix
            modules/home-assistant.nix
            modules/jellyfin.nix
            modules/ldap.nix
            modules/monitoring.nix
            modules/nextcloud-server.nix
            modules/nginx.nix
            modules/postgresql.nix
            modules/ssl.nix
            modules/tinyproxy.nix
            modules/vaultwarden.nix
            modules/vpn.nix
          ];
        };

        checks = {
          tests = nix-flake-tests.lib.check {
            inherit pkgs;
            tests =
              let
                importFiles = files:
                  map (m: import m {
                    inherit pkgs;
                    inherit (pkgs) lib;
                  }) files;

                mergeTests = pkgs.lib.lists.foldl pkgs.lib.trivial.mergeAttrs {};
              in mergeTests (importFiles [
                ./test/modules/arr.nix
                ./test/modules/davfs.nix
                ./test/modules/postgresql.nix
              ]);
          };
        };
        # templates.default = {};  Would be nice to have a template
      }
  );
}
