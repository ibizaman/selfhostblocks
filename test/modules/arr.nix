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
          ../../modules/services/arr.nix
          m
        ];
      }).config;

      systemdRedacted = lib.filterAttrsRecursive (n: v: n != "preStart") cfg.systemd;
    in {
      inherit (cfg) services users;
      systemd = systemdRedacted;
      shb = { inherit (cfg.shb) backup nginx; };
    };
in
{
  testArrNoOptions = {
    expected = {
      systemd.services.radarr = {};
      systemd.services.jackett = {};
      shb.backup = {};
      shb.nginx.ssoProtect = [];
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

  testRadarr = {
    expected = {
      systemd.services.radarr = {
        serviceConfig = {
          StateDirectoryMode = "0750";
          UMask = "0027";
        };
      };
      systemd.services.jackett = {};
      systemd.tmpfiles.rules = [
        "d '/var/lib/radarr' 0750 radarr radarr - -"
      ];
      shb.backup = {};
      shb.nginx.ssoProtect = [
        {
          ssoRules = [
            {
              domain = "radarr.example.com";
              policy = "bypass";
              resources = [
                "^/api.*"
              ];
            }
            {
              domain = "radarr.example.com";
              policy = "two_factor";
              subject = [
                "group:arr_user"
              ];
            }
          ];
          domain = "example.com";
          authEndpoint = "https://oidc.example.com";
          subdomain = "radarr";
          upstream = "http://127.0.0.1:7001";
        }
      ];
      users.users.radarr.extraGroups = [ "media" ];
      users.groups.radarr.members = [ "backup" ];
      services.bazarr = {};
      services.jackett = {};
      services.lidarr = {};
      services.radarr = {
        enable = true;
        dataDir = "/var/lib/radarr";
        user = "radarr";
        group = "radarr";
      };
      services.readarr = {};
      services.sonarr = {};
    };
    expr = testConfig {
      services.radarr.user = "radarr";
      services.radarr.group = "radarr";

      shb.arr.radarr = {
        subdomain = "radarr";
        domain = "example.com";
        enable = true;
        authEndpoint = "https://oidc.example.com";
        settings = {
          APIKeyFile = "/run/radarr/apikey";
        };
      };
    };
  };

  testRadarrWithBackup = {
    expected = {
      systemd.services.radarr = {
        serviceConfig = {
          StateDirectoryMode = "0750";
          UMask = "0027";
        };
      };
      systemd.services.jackett = {};
      systemd.tmpfiles.rules = [
        "d '/var/lib/radarr' 0750 radarr radarr - -"
      ];
      shb.backup.instances = {
        radarr = {
          enable = true;
          sourceDirectories = [ "/var/lib/radarr" ];
          excludePatterns = [ ".db-shm" ".db-wal" ".mono" ];
        };
      };
      shb.nginx.ssoProtect = [
        {
          ssoRules = [
            {
              domain = "radarr.example.com";
              policy = "bypass";
              resources = [
                "^/api.*"
              ];
            }
            {
              domain = "radarr.example.com";
              policy = "two_factor";
              subject = [
                "group:arr_user"
              ];
            }
          ];
          domain = "example.com";
          authEndpoint = "https://oidc.example.com";
          subdomain = "radarr";
          upstream = "http://127.0.0.1:7001";
        }
      ];
      users.users.radarr.extraGroups = [ "media" ];
      users.groups.radarr.members = [ "backup" ];
      services.bazarr = {};
      services.jackett = {};
      services.lidarr = {};
      services.radarr = {
        enable = true;
        dataDir = "/var/lib/radarr";
        user = "radarr";
        group = "radarr";
      };
      services.readarr = {};
      services.sonarr = {};
    };
    expr = testConfig {
      services.radarr.user = "radarr";
      services.radarr.group = "radarr";

      shb.arr.radarr = {
        subdomain = "radarr";
        domain = "example.com";
        enable = true;
        authEndpoint = "https://oidc.example.com";
        settings = {
          APIKeyFile = "/run/radarr/apikey";
        };
        backupCfg = {
          enable = true;
        };
      };
    };
  };
}
