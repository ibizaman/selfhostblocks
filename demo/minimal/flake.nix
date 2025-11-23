{
  description = "Minimal example to setup SelfHostBlocks";

  inputs = {
    selfhostblocks.url = "github:ibizaman/selfhostblocks";

    sops-nix = {
      url = "github:Mic92/sops-nix";
    };
  };

  outputs =
    {
      self,
      selfhostblocks,
      sops-nix,
    }:
    {
      nixosConfigurations =
        let
          system = "x86_64-linux";
          nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;

          # This module makes the assertions happy and the build succeed.
          # This is of course wrong and will not work on any real system.
          filesystemModule = {
            fileSystems."/".device = "/dev/null";
            boot.loader.grub.devices = [ "/dev/null" ];
          };
        in
        {
          # Test with:
          #   nix build .#nixosConfigurations.minimal.config.system.build.toplevel
          minimal = nixpkgs'.nixosSystem {
            inherit system;
            modules = [
              selfhostblocks.nixosModules.default
              filesystemModule
              {
                nixpkgs.overlays = [
                  selfhostblocks.overlays.${system}.default
                ];
              }
              # This modules showcases the use of SHB's lib.
              (
                {
                  config,
                  lib,
                  shb,
                  ...
                }:
                {
                  options.myOption = lib.mkOption {
                    # Using provided nixosSystem directly.
                    # SHB's lib is available under `shb` thanks to the overlay.
                    type = shb.secretFileType;
                  };
                  config = {
                    myOption.source = "/a/path";
                    # Use the option.
                    environment.etc.myOption.text = config.myOption.source;
                  };
                }
              )
            ];
          };

          # Test with:
          #   nix build .#nixosConfigurations.sops.config.system.build.toplevel
          #   nix eval .#nixosConfigurations.sops.config.myOption
          sops = nixpkgs'.nixosSystem {
            inherit system;
            modules = [
              selfhostblocks.nixosModules.default
              selfhostblocks.nixosModules.sops
              sops-nix.nixosModules.default
              filesystemModule
              {
                nixpkgs.overlays = [
                  selfhostblocks.overlays.${system}.default
                ];
              }
              # This modules showcases the use of SHB's lib.
              (
                {
                  config,
                  lib,
                  shb,
                  ...
                }:
                {
                  options.myOption = lib.mkOption {
                    # Using provided nixosSystem directly.
                    # SHB's lib is available under `shb` thanks to the overlay.
                    type = shb.secretFileType;
                  };
                  config = {
                    myOption.source = "/a/path";
                    # Use the option.
                    environment.etc.myOption.text = config.myOption.source;
                  };
                }
              )
            ];
          };

          # This example shows how to import the nixosSystem patches to nixpkgs manually.
          #
          # Test with:
          #   nix build .#nixosConfigurations.lowlevel.config.system.build.toplevel
          #   nix eval .#nixosConfigurations.lowlevel.config.myOption
          lowlevel =
            let
              # We must import nixosSystem directly from the patched nixpkgs
              # otherwise we do not get the patches.
              nixosSystem' = import "${nixpkgs'}/nixos/lib/eval-config.nix";
            in
            nixosSystem' {
              inherit system;
              modules = [
                selfhostblocks.nixosModules.default
                filesystemModule
                {
                  nixpkgs.overlays = [
                    selfhostblocks.overlays.${system}.default
                  ];
                }
                # This modules showcases the use of SHB's lib.
                (
                  {
                    config,
                    lib,
                    shb,
                    ...
                  }:
                  {
                    options.myOption = lib.mkOption {
                      # Using provided nixosSystem directly.
                      # SHB's lib is available under `shb` thanks to the overlay.
                      type = shb.secretFileType;
                    };
                    config = {
                      myOption.source = "/a/path";
                      # Use the option.
                      environment.etc.myOption.text = config.myOption.source;
                    };
                  }
                )
              ];
            };

          # This example shows how to apply patches to nixpkgs manually.
          #
          # Test with:
          #   nix build .#nixosConfigurations.manual.config.system.build.toplevel
          #   nix eval .#nixosConfigurations.manual.config.myOption
          manual =
            let
              pkgs = import selfhostblocks.inputs.nixpkgs {
                inherit system;
              };
              nixpkgs' = pkgs.applyPatches {
                name = "nixpkgs-patched";
                src = selfhostblocks.inputs.nixpkgs;
                patches = selfhostblocks.lib.${system}.patches;
              };
              # We must import nixosSystem directly from the patched nixpkgs
              # otherwise we do not get the patches.
              nixosSystem' = import "${nixpkgs'}/nixos/lib/eval-config.nix";
            in
            nixosSystem' {
              inherit system;
              modules = [
                selfhostblocks.nixosModules.default
                filesystemModule
                {
                  nixpkgs.overlays = [
                    selfhostblocks.overlays.${system}.default
                  ];
                }
                # This modules showcases the use of SHB's lib.
                (
                  {
                    config,
                    lib,
                    shb,
                    ...
                  }:
                  {
                    options.myOption = lib.mkOption {
                      # Using provided nixosSystem directly.
                      # SHB's lib is available under `shb` thanks to the overlay.
                      type = shb.secretFileType;
                    };
                    config = {
                      myOption.source = "/a/path";
                      # Use the option.
                      environment.etc.myOption.text = config.myOption.source;
                    };
                  }
                )
              ];
            };
        };
    };
}
