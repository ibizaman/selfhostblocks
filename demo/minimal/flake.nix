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
          shb = selfhostblocks.lib.${system};

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
          minimal = shb.pkgs.nixosSystem {
            inherit system;
            modules = [
              selfhostblocks.nixosModules.default
              filesystemModule
              # This modules showcases the use of SHB's lib.
              (
                { config, lib, ... }:
                {
                  options.myOption = lib.mkOption {
                    # Using provided nixosSystem directly
                    # SHB's lib is available under `lib.shb`.
                    type = lib.shb.secretFileType;
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
          sops = shb.pkgs.nixosSystem {
            inherit system;
            modules = [
              selfhostblocks.nixosModules.default
              selfhostblocks.nixosModules.sops
              sops-nix.nixosModules.default
              filesystemModule
              # This modules showcases the use of SHB's lib.
              (
                { config, lib, ... }:
                {
                  options.myOption = lib.mkOption {
                    # Using provided nixosSystem directly
                    # SHB's lib is available under `lib.shb`.
                    type = lib.shb.secretFileType;
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

          # Note: this is just to show-off a common pitfall for more advanced user.
          # Prefer using the `shb.pkgs.nixosSystem` function directly.
          #
          # Test with:
          #   nix build .#nixosConfigurations.lowlevel.config.system.build.toplevel
          #   nix eval .#nixosConfigurations.lowlevel.config.myOption
          lowlevel =
            let
              # We must import nixosSystem directly from the patched nixpkgs
              # otherwise we do not get the patches.
              nixosSystem' = import "${shb.patchedNixpkgs}/nixos/lib/eval-config.nix";
            in
            nixosSystem' {
              inherit system;
              modules = [
                selfhostblocks.nixosModules.default
                filesystemModule
                # This modules showcases the use of SHB's lib.
                (
                  { config, lib, ... }:
                  {
                    options.myOption = lib.mkOption {
                      # lib.shb.secretFileType is not available here,
                      # so we must pass around the shb flake input.
                      # type = shb.secretFileType;
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
