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

  outputs = inputs@{ nixpkgs, nix-flake-tests, flake-utils, nmdsrc, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      originPkgs = nixpkgs.legacyPackages.${system};
      shbPatches = originPkgs.lib.optionals (system == "x86_64-linux") [
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

        config = {
          permittedInsecurePackages = [
            # TODO: https://github.com/NixOS/nixpkgs/issues/326335
            "dotnet-sdk-6.0.428"
          ];
        };

        overlays = [
          (final: prev: {
            exiftool = prev.exiftool.overrideAttrs (f: p: {
              version = "12.70";
              src = pkgs.fetchurl {
                url = "https://exiftool.org/Image-ExifTool-12.70.tar.gz";
                hash = "sha256-TLJSJEXMPj870TkExq6uraX8Wl4kmNerrSlX3LQsr/4=";
              };
            });

            jellyfin-cli = pkgs.buildDotnetModule rec {
              pname = "jellyfin-cli";
              version = "10.10.7";

              src = pkgs.fetchFromGitHub {
                owner = "ibizaman";
                repo = "jellyfin";
                rev = "0b1a5d929960f852dba90c1fc36f3a19dc094f8d";
                hash = "sha256-H9V65+886EYMn/xDEgmxvoEOrbZaI1wSfmkN9vAzGhw=";
              };

              propagatedBuildInputs = [ pkgs.sqlite ];

              projectFile = "Jellyfin.Cli/Jellyfin.Cli.csproj";
              executables = [ "jellyfin-cli" ];
              nugetDeps = "${pkgs.path}/pkgs/by-name/je/jellyfin/nuget-deps.json";
              runtimeDeps = [
                pkgs.jellyfin-ffmpeg
                pkgs.fontconfig
                pkgs.freetype
              ];
              dotnet-sdk = pkgs.dotnetCorePackages.sdk_8_0;
              dotnet-runtime = pkgs.dotnetCorePackages.aspnetcore_8_0;
              dotnetBuildFlags = [ "--no-self-contained" ];

              passthru.tests = {
                smoke-test = pkgs.nixosTests.jellyfin;
              };

              meta = with pkgs.lib; {
                description = "Free Software Media System";
                homepage = "https://jellyfin.org/";
                # https://github.com/jellyfin/jellyfin/issues/610#issuecomment-537625510
                license = licenses.gpl2Plus;
                maintainers = with maintainers; [
                  nyanloutre
                  minijackson
                  purcell
                  jojosch
                ];
                mainProgram = "jellyfin-cli";
                platforms = dotnet-runtime.meta.platforms;
              };
            };
          })
        ];
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
        nixosModules.default = { config, ... }: {
          imports = allModules;
        };

        packages.manualHtml = pkgs.callPackage ./docs {
          inherit nmdsrc;
          allModules = allModules ++ contractDummyModules;
          release = builtins.readFile ./VERSION;
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
        (pkgs.callPackage ./docs {
          inherit nmdsrc;
          allModules = allModules ++ contractDummyModules;
          release = builtins.readFile ./VERSION;
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
