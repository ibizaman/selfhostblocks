{
  description = "SelfHostBlocks module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    nix-flake-tests.url = "github:antifuchs/nix-flake-tests";
    flake-utils.url = "github:numtide/flake-utils";
    nmdsrc = {
      url = "git+https://git.sr.ht/~rycee/nmd";
      flake = false;
    };
  };

  outputs = { nixpkgs, nix-flake-tests, flake-utils, nmdsrc, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      patches = [
      ];
      originPkgs = nixpkgs.legacyPackages.${system};
      patchedNixpkgs = originPkgs.applyPatches {
        name = "nixpkgs-patched";
        src = nixpkgs;
        patches = map (p: originPkgs.writeText "patch" p) patches;
      };

      pkgs = import patchedNixpkgs {
        inherit system;
      };

      allModules = [
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
    in
      {
        nixosModules.default = { config, ... }: {
          imports = allModules;
        };

        packages.manualHtml = pkgs.callPackage ./docs {
          inherit allModules nmdsrc;
          release = "0.0.1";
        };

        checks =
          let
            importFiles = files:
              map (m: pkgs.callPackage m {}) files;

            mergeTests = pkgs.lib.lists.foldl pkgs.lib.trivial.mergeAttrs {};

            flattenAttrs = root: attrset: pkgs.lib.attrsets.foldlAttrs (acc: name: value: acc // {
              "${root}_${name}" = value;
            }) {} attrset;

            vm_test = name: path: flattenAttrs "vm_${name}" (
              import path {
                inherit pkgs;
                inherit (pkgs) lib;
              }
            );
          in (rec {
            all = mergeTests [
              modules
            ];

            modules = nix-flake-tests.lib.check {
              inherit pkgs;
              tests =
                mergeTests (importFiles [
                  ./test/modules/arr.nix
                  ./test/modules/davfs.nix
                  ./test/modules/nginx.nix
                  ./test/modules/postgresql.nix
                ]);
            };
          }
          // (vm_test "ldap" ./test/vm/ldap.nix)
          // (vm_test "postgresql" ./test/vm/postgresql.nix)
          // (vm_test "monitoring" ./test/vm/monitoring.nix)
          );
      }
  );
}
