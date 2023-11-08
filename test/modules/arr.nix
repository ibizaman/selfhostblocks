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
              shb.backup = anyOpt {};
              shb.nginx = anyOpt {};
              users = anyOpt {};
              services.bazarr = anyOpt {};
              services.jackett = anyOpt {};
              services.lidarr = anyOpt {};
              services.radarr = anyOpt {};
              services.readarr = anyOpt {};
              services.sonarr = anyOpt {};
            };
          }
          ../../modules/arr.nix
          m
        ];
      }).config;
    in {
      inherit (cfg) systemd services users;
      shb = { inherit (cfg.shb) backup nginx; };
    };
in
{
  testArrNoOptions = {
    expected = {
      systemd.services.jackett = {};
      shb.backup = {};
      shb.nginx.autheliaProtect = [];
      users.users = {};
      services.bazarr = {};
      services.jackett = {};
      services.lidarr = {};
      services.radarr = {};
      services.readarr = {};
      services.sonarr = {};
    };
    expr = testConfig {};
  };
}
