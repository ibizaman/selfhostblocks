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
            modules/blocks/authelia.nix
            modules/blocks/backup.nix
            modules/blocks/davfs.nix
            modules/blocks/ldap.nix
            modules/blocks/monitoring.nix
            modules/blocks/nginx.nix
            modules/blocks/postgresql.nix
            modules/blocks/ssl.nix
            modules/blocks/tinyproxy.nix
            modules/blocks/vpn.nix

            modules/services/arr.nix
            modules/services/deluge.nix
            modules/services/hledger.nix
            modules/services/home-assistant.nix
            modules/services/jellyfin.nix
            modules/services/nextcloud-server.nix
            modules/services/vaultwarden.nix
          ];
        };

        checks =
          let
            importFiles = files:
              map (m: import m {
                inherit pkgs;
                inherit (pkgs) lib;
              }) files;

            mergeTests = pkgs.lib.lists.foldl pkgs.lib.trivial.mergeAttrs {};
          in rec {
            all = mergeTests [
              modules
            ];

            modules = nix-flake-tests.lib.check {
              inherit pkgs;
              tests =
                mergeTests (importFiles [
                  ./test/modules/arr.nix
                  ./test/modules/davfs.nix
                  ./test/modules/postgresql.nix
                ]);
            };
          };
      }
  );
}
