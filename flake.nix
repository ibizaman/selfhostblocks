{
  description = "SelfHostBlocks module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    nix-flake-tests.url = "github:antifuchs/nix-flake-tests";
    flake-utils.url = "github:numtide/flake-utils";
    nmd.url = "git+https://git.sr.ht/~rycee/nmd";
    nmd.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nix-flake-tests, flake-utils, nmd, ... }: flake-utils.lib.eachDefaultSystem (system:
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

        # Inspiration from https://github.com/nix-community/nix-on-droid/blob/039379abeee67144d4094d80bbdaf183fb2eabe5/docs/default.nix#L22
        packages.manualHtml = let
          nmdlib = import nmd { inherit pkgs; };

          setupModule = {
            _module.args.pkgs = pkgs.lib.mkForce (nmdlib.scrubDerivations "pkgs" pkgs);
            _module.check = false;
          };

          modulesDocs = nmdlib.buildModulesDocs {
            modules = [
              setupModule
              ./modules/blocks/ssl.nix
            ];
            moduleRootPaths = [ ../. ];
            mkModuleUrl = path: "https://myproject.foo/${path}";
            channelName = "selfhostblocks";
            docBook = { id = "selfhostblocks-options"; optionIdPrefix = "shb-opt"; };
          };

          manual = nmdlib.buildDocBookDocs {
            pathName = "SelfHostBlocks";
            modulesDocs = [ modulesDocs ];
            documentsDirectory = ./docs;
            chunkToc = ''
              <toc>
                <d:tocentry xmlns:d="http://docbook.org/ns/docbook" linkend="book-manual">
                  <?dbhtml filename="index.html"?>
                </d:tocentry>
              </toc>
            '';
          };
        in
          manual.html;

        checks =
          let
            importFiles = files:
              map (m: import m {
                inherit pkgs;
                inherit (pkgs) lib;
              }) files;

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
                  ./test/modules/postgresql.nix
                ]);
            };
          }
          // (vm_test "postgresql" ./test/vm/postgresql.nix)
          // (vm_test "monitoring" ./test/vm/monitoring.nix)
          );
      }
  );
}
