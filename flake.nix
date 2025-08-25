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

  outputs = inputs@{ self, nixpkgs, nix-flake-tests, flake-utils, nmdsrc, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      originPkgs = nixpkgs.legacyPackages.${system};
      shbPatches = originPkgs.lib.optionals (system == "x86_64-linux") [
        # Get rid of lldap patches when https://github.com/NixOS/nixpkgs/pull/425923 is merged.
        ./patches/0001-lldap-add-options-to-set-important-secrets.patch
        ./patches/0002-lldap-lldap-0.6.1-0.6.2.patch
        ./patches/0003-lldap-bootstrap-init-0.6.2.patch
        ./patches/0004-lldap-add-ensure-options.patch

        # Leaving commented out as an example.
        # (originPkgs.fetchpatch {
        #   url = "https://github.com/NixOS/nixpkgs/pull/317107.patch";
        #   hash = "sha256-hoLrqV7XtR1hP/m0rV9hjYUBtrSjay0qcPUYlKKuVWk=";
        # })
      ];
      patchNixpkgs = {
        nixpkgs,
        patches,
        system,
      }: nixpkgs.legacyPackages.${system}.applyPatches {
        name = "nixpkgs-patched";
        src = nixpkgs;
        inherit patches;
      };
      patchedNixpkgs = (patchNixpkgs {
        nixpkgs = inputs.nixpkgs;
        patches = shbPatches;
        inherit system;
      });
      pkgs = import patchedNixpkgs {
        inherit system;
      };

      # The contract dummies are used to show options for contracts.
      contractDummyModules = [
        modules/contracts/backup/dummyModule.nix
        modules/contracts/ssl/dummyModule.nix
      ];
    in
      {
        nixosModules.default = self.nixosModules.${system}.all;
        nixosModules.all = {
          imports = [
            self.nixosModules.${system}.insecure

            # blocks
            self.nixosModules.${system}.authelia
            self.nixosModules.${system}.davfs
            self.nixosModules.${system}.hardcodedsecret
            self.nixosModules.${system}.lldap
            self.nixosModules.${system}.mitmdump
            self.nixosModules.${system}.monitoring
            self.nixosModules.${system}.nginx
            self.nixosModules.${system}.postgresql
            self.nixosModules.${system}.restic
            self.nixosModules.${system}.ssl
            self.nixosModules.${system}.sops
            self.nixosModules.${system}.tinyproxy
            self.nixosModules.${system}.vpn
            self.nixosModules.${system}.zfs

            # services
            self.nixosModules.${system}.arr
            self.nixosModules.${system}.audiobookshelf
            self.nixosModules.${system}.deluge
            self.nixosModules.${system}.forgejo
            self.nixosModules.${system}.grocy
            self.nixosModules.${system}.hledger
            self.nixosModules.${system}.assistant
            self.nixosModules.${system}.jellyfin
            self.nixosModules.${system}.nextcloud-server
            self.nixosModules.${system}.vaultwarden
          ];
        };

        nixosModules.insecure = {
          nixpkgs.config.permittedInsecurePackages = [
          ];
        };

        nixosModules.authelia = modules/blocks/authelia.nix;
        nixosModules.davfs = modules/blocks/davfs.nix;
        nixosModules.hardcodedsecret = modules/blocks/hardcodedsecret.nix;
        nixosModules.lldap = modules/blocks/lldap.nix;
        nixosModules.mitmdump = modules/blocks/mitmdump.nix;
        nixosModules.monitoring = modules/blocks/monitoring.nix;
        nixosModules.nginx = modules/blocks/nginx.nix;
        nixosModules.postgresql = modules/blocks/postgresql.nix;
        nixosModules.restic = modules/blocks/restic.nix;
        nixosModules.ssl = modules/blocks/ssl.nix;
        nixosModules.sops = modules/blocks/sops.nix;
        nixosModules.tinyproxy = modules/blocks/tinyproxy.nix;
        nixosModules.vpn = modules/blocks/vpn.nix;
        nixosModules.zfs = modules/blocks/zfs.nix;

        nixosModules.arr = modules/services/arr.nix;
        nixosModules.audiobookshelf = modules/services/audiobookshelf.nix;
        nixosModules.deluge = modules/services/deluge.nix;
        nixosModules.forgejo = modules/services/forgejo.nix;
        nixosModules.grocy = modules/services/grocy.nix;
        nixosModules.hledger = modules/services/hledger.nix;
        nixosModules.assistant = modules/services/home-assistant.nix;
        nixosModules.jellyfin = modules/services/jellyfin.nix;
        nixosModules.nextcloud-server = modules/services/nextcloud-server.nix;
        nixosModules.vaultwarden = modules/services/vaultwarden.nix;

        packages.manualHtml = pkgs.callPackage ./docs {
          inherit nmdsrc;
          allModules = self.nixosModules.${system}.all.imports ++ contractDummyModules;
          release = builtins.readFile ./VERSION;

          substituteVersionIn = [
            "./manual.md"
            "./usage.md"
          ];
          modules = {
            "blocks/authelia" = ./modules/blocks/authelia.nix;
            "blocks/lldap" = ./modules/blocks/lldap.nix;
            "blocks/ssl" = ./modules/blocks/ssl.nix;
            "blocks/mitmdump" = ./modules/blocks/mitmdump.nix;
            "blocks/monitoring" = ./modules/blocks/monitoring.nix;
            "blocks/postgresql" = ./modules/blocks/postgresql.nix;
            "blocks/restic" = ./modules/blocks/restic.nix;
            "blocks/sops" = ./modules/blocks/sops.nix;
            "services/arr" = ./modules/services/arr.nix;
            "services/forgejo" = [
              ./modules/services/forgejo.nix
              (pkgs.path + "/nixos/modules/services/misc/forgejo.nix")
            ];
            "services/home-assistant" = ./modules/services/home-assistant.nix;
            "services/jellyfin" = ./modules/services/jellyfin.nix;
            "services/nextcloud-server" = ./modules/services/nextcloud-server.nix;
            "services/vaultwarden" = ./modules/services/vaultwarden.nix;
            "contracts/backup" = ./modules/contracts/backup/dummyModule.nix;
            "contracts/databasebackup" = ./modules/contracts/databasebackup/dummyModule.nix;
            "contracts/secret" = ./modules/contracts/secret/dummyModule.nix;
            "contracts/ssl" = ./modules/contracts/ssl/dummyModule.nix;
          };
        };

        # Documentation redirect generation tool - scans HTML files for anchor mappings
        packages.generateRedirects = 
        let
          # Python patch to inject redirect collector
          pythonPatch = pkgs.writeText "nixos-render-docs-patch.py" ''
            # Load redirect collector patch
            try:
                import sys, os
                sys.path.insert(0, os.path.dirname(__file__) + '/..')
                import missing_refs_collector
            except Exception as e:
                print(f"Warning: Failed to load redirect collector: {e}", file=sys.stderr)
          '';

          # Patched nixos-render-docs that collects redirects during HTML generation
          nixos-render-docs-patched = pkgs.writeShellApplication {
            name = "nixos-render-docs";
            runtimeInputs = [ pkgs.nixos-render-docs ];
            text = ''
              TEMP_DIR=$(mktemp -d); trap 'rm -rf "$TEMP_DIR"' EXIT
              
              cp -r ${pkgs.nixos-render-docs}/${pkgs.python3.sitePackages}/nixos_render_docs "$TEMP_DIR/"
              chmod -R +w "$TEMP_DIR"
              cp ${./docs/generate-redirects-nixos-render-docs.py} "$TEMP_DIR/missing_refs_collector.py"
              echo '{}' > "$TEMP_DIR/empty_redirects.json"
              cat ${pythonPatch} >> "$TEMP_DIR/nixos_render_docs/__init__.py"
              
              ARGS=()
              while [[ $# -gt 0 ]]; do
                case $1 in
                  --redirects) ARGS+=("$1" "$TEMP_DIR/empty_redirects.json"); shift 2 ;;
                  *) ARGS+=("$1"); shift ;;
                esac
              done
              
              export PYTHONPATH="$TEMP_DIR:''${PYTHONPATH:-}"
              nixos-render-docs "''${ARGS[@]}"
            '';
          };
        in
        (self.packages.${system}.manualHtml.override {
          nixos-render-docs = nixos-render-docs-patched;
        }).overrideAttrs (old: {
          installPhase = ''
            ${old.installPhase}
            ln -sf share/doc/selfhostblocks/redirects.json $out/redirects.json
          '';
        });

        lib =
          (pkgs.callPackage ./lib {})
          // {
            contracts = pkgs.callPackage ./modules/contracts {};
            patches = shbPatches;
            inherit patchNixpkgs patchedNixpkgs;
          };

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
          // (vm_test "lldap" ./test/blocks/lldap.nix)
          // (vm_test "lib" ./test/blocks/lib.nix)
          // (vm_test "mitmdump" ./test/blocks/mitmdump.nix)
          // (vm_test "postgresql" ./test/blocks/postgresql.nix)
          // (vm_test "restic" ./test/blocks/restic.nix)
          // (vm_test "ssl" ./test/blocks/ssl.nix)

          // (vm_test "contracts-backup" ./test/contracts/backup.nix)
          // (vm_test "contracts-databasebackup" ./test/contracts/databasebackup.nix)
          // (vm_test "contracts-secret" ./test/contracts/secret.nix)
          ));

        # To see the traces, run:
        #   nix run .#playwright -- show-trace $(nix eval .#checks.x86_64-linux.vm_grocy_basic --raw)/trace/0.zip
        packages.playwright =
          pkgs.callPackage ({ stdenvNoCC, makeWrapper, playwright }: stdenvNoCC.mkDerivation {
            name = "playwright";

            src = playwright;

            nativeBuildInputs = [
              makeWrapper
            ];

            # No quotes around the value for LLDAP_PASSWORD because we want the value to not be enclosed in quotes.
            installPhase = ''
              makeWrapper ${pkgs.python3Packages.playwright}/bin/playwright $out/bin/playwright \
                --set PLAYWRIGHT_BROWSERS_PATH ${pkgs.playwright-driver.browsers} \
                --set PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS true
            '';
          }) {};

        # Run "nix run .#update-redirects" to regenerate docs/redirects.json
        apps.update-redirects = {
          type = "app";
          program = "${pkgs.writeShellApplication {
            name = "update-redirects";
            runtimeInputs = [ pkgs.nix pkgs.jq ];
            text = ''
              echo "=== SelfHostBlocks Redirects Updater ==="
              echo "Generating fresh ./docs/redirects.json..."
              
              nix build .#generateRedirects || { echo "Error: Failed to generate redirects" >&2; exit 1; }
              [[ -f result/redirects.json ]] || { echo "Error: Generated redirects file not found" >&2; exit 1; }
              
              echo "Generated $(jq 'keys | length' result/redirects.json) redirects"
              echo
              read -p "Update docs/redirects.json? This will backup the current file [y/N] " -r response
              [[ "$response" =~ ^[Yy] ]] || { echo "Aborted - no changes made"; exit 0; }
              
              [[ -f docs/redirects.json ]] && cp docs/redirects.json docs/redirects.json.backup && echo "Created backup"
              cp result/redirects.json docs/redirects.json
              echo "  Updated docs/redirects.json"
              echo "To verify: nix build .#manualHtml"
            '';
          }}/bin/update-redirects";
        };
      }
  ) // {
    herculesCI.ciSystems = [ "x86_64-linux" ];
  };
}
