{ pkgs, lib, ... }:
let
  anyOpt = default: lib.mkOption {
    type = lib.types.anything;
    inherit default;
  };

  testConfig = m:
    let
      cfg = (lib.evalModules {
        specialArgs = { inherit pkgs; };
        modules = [
          {
            options = {
              systemd = anyOpt {};
              services = anyOpt {};
            };
          }
          ../../modules/blocks/davfs.nix
          m
        ];
      }).config;
    in {
      inherit (cfg) systemd services;
    };
in
{
  testDavfsNoOptions = {
    expected = {
      services.davfs2.enable = false;
      systemd.mounts = [];
    };
    expr = testConfig {};
  };
}
