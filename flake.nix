{
  description = "SelfHostBlocks module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-flake-tests.url = "github:antifuchs/nix-flake-tests";
    flake-utils.url = "github:numtide/flake-utils";
    nmdsrc = {
      url = "git+https://git.sr.ht/~rycee/nmd";
      flake = false;
    };
  };

  outputs = { nixpkgs, nix-flake-tests, flake-utils, nmdsrc, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      originPkgs = nixpkgs.legacyPackages.${system};
      patches = [
        # Leaving commented out for an example.
        # (originPkgs.fetchpatch {
        #   url = "https://github.com/NixOS/nixpkgs/pull/317107.patch";
        #   hash = "sha256-hoLrqV7XtR1hP/m0rV9hjYUBtrSjay0qcPUYlKKuVWk=";
        # })
      ];
      patchedNixpkgs = originPkgs.applyPatches {
        name = "nixpkgs-patched";
        src = nixpkgs;
        inherit patches;
      };
      pkgs = import patchedNixpkgs {
        inherit system;
      };

      allModules = [
        modules/blocks/authelia.nix
        modules/blocks/davfs.nix
        modules/blocks/hardcodedsecret.nix
        modules/blocks/ldap.nix
        modules/blocks/monitoring.nix
        modules/blocks/nginx.nix
        modules/blocks/postgresql.nix
        modules/blocks/restic.nix
        modules/blocks/ssl.nix
        modules/blocks/sops.nix
        modules/blocks/tinyproxy.nix
        modules/blocks/vpn.nix
        modules/blocks/zfs.nix

        modules/services/arr.nix
        modules/services/audiobookshelf.nix
        modules/services/deluge.nix
        modules/services/forgejo.nix
        modules/services/grocy.nix
        modules/services/hledger.nix
        modules/services/home-assistant.nix
        modules/services/jellyfin.nix
        modules/services/nextcloud-server.nix
        modules/services/vaultwarden.nix
      ];

      # The contract dummies are used to show options for contracts.
      contractDummyModules = [
        modules/contracts/backup/dummyModule.nix
        modules/contracts/ssl/dummyModule.nix
      ];
    in
      {
        inherit patches;

        nixosModules.default = { config, ... }: {
          imports = allModules;
        };

        packages.manualHtml = pkgs.callPackage ./docs {
          inherit nmdsrc;
          allModules = allModules ++ contractDummyModules;
          release = builtins.readFile ./VERSION;
        };

        lib.contracts = pkgs.callPackage ./modules/contracts {};

        checks =
          let
            inherit (pkgs.lib) foldl foldlAttrs mergeAttrs optionalAttrs;

            importFiles = files:
              map (m: pkgs.callPackage m {}) files;

            mergeTests = foldl mergeAttrs {};

            flattenAttrs = root: attrset: foldlAttrs (acc: name: value: acc // {
              "${root}_${name}" = value;
            }) {} attrset;

            vm_test = name: path: flattenAttrs "vm_${name}" (
              import path {
                inherit pkgs;
                inherit (pkgs) lib;
              }
            );

            shblib = pkgs.callPackage ./lib {};
          in (optionalAttrs (system == "x86_64-linux") ({
            modules = shblib.check {
              inherit pkgs;
              tests =
                mergeTests (importFiles [
                  ./test/modules/arr.nix
                  ./test/modules/davfs.nix
                  # TODO: Make this not use IFD
                  ./test/modules/lib.nix
                  ./test/modules/nginx.nix
                  ./test/modules/postgresql.nix
                ]);
            };

            # TODO: Make this not use IFD
            lib = nix-flake-tests.lib.check {
              inherit pkgs;
              tests = pkgs.callPackage ./test/modules/lib.nix {};
            };
          }
          // (vm_test "arr" ./test/services/arr.nix)
          // (vm_test "audiobookshelf" ./test/services/audiobookshelf.nix)
          // (vm_test "deluge" ./test/services/deluge.nix)
          // (vm_test "forgejo" ./test/services/forgejo.nix)
          // (vm_test "grocy" ./test/services/grocy.nix)
          // (vm_test "hledger" ./test/services/hledger.nix)
          // (vm_test "homeassistant" ./test/services/home-assistant.nix)
          // (vm_test "jellyfin" ./test/services/jellyfin.nix)
          // (vm_test "monitoring" ./test/services/monitoring.nix)
          // (vm_test "nextcloud" ./test/services/nextcloud.nix)
          // (vm_test "vaultwarden" ./test/services/vaultwarden.nix)

          // (vm_test "authelia" ./test/blocks/authelia.nix)
          // (vm_test "ldap" ./test/blocks/ldap.nix)
          // (vm_test "lib" ./test/blocks/lib.nix)
          // (vm_test "postgresql" ./test/blocks/postgresql.nix)
          // (vm_test "restic" ./test/blocks/restic.nix)
          // (vm_test "ssl" ./test/blocks/ssl.nix)

          // (vm_test "contracts-backup" ./test/contracts/backup.nix)
          // (vm_test "contracts-databasebackup" ./test/contracts/databasebackup.nix)
          // (vm_test "contracts-secret" ./test/contracts/secret.nix)
          ));
      }
  ) // {
    herculesCI.ciSystems = [ "x86_64-linux" ];
  };
}
