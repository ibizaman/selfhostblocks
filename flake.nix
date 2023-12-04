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
        ''
        From a4d67df38628eaa3e1823af7b7613af3d7ff7555 Mon Sep 17 00:00:00 2001
        From: ibizaman <ibizapeanut@gmail.com>
        Date: Sun, 3 Dec 2023 21:09:30 -0800
        Subject: [PATCH] fix for nixos-render-docs media path
        
        ---
         .../tools/nix/nixos-render-docs/src/nixos_render_docs/manual.py | 2 +-
         1 file changed, 1 insertion(+), 1 deletion(-)
        
        diff --git a/pkgs/tools/nix/nixos-render-docs/src/nixos_render_docs/manual.py b/pkgs/tools/nix/nixos-render-docs/src/nixos_render_docs/manual.py
        index d605dd88b37d..3482cc02c4d1 100644
        --- a/pkgs/tools/nix/nixos-render-docs/src/nixos_render_docs/manual.py
        +++ b/pkgs/tools/nix/nixos-render-docs/src/nixos_render_docs/manual.py
        @@ -506,7 +506,7 @@ class ManualHTMLRenderer(RendererMixin, HTMLRenderer):
                 in_dir = self._in_dir
                 for included, path in fragments:
                     try:
        -                self._in_dir = (in_dir / path).parent
        +                self._in_dir = path.parent
                         inner.append(self.render(included))
                     except Exception as e:
                         raise RuntimeError(f"rendering {path}") from e
        -- 
        2.42.0
        ''
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
