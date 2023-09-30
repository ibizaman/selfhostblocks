{ config, pkgs, lib, ... }:

let
  cfg = config.shb.arr;

  apps = {
    radarr = {
      defaultPort = 7878;
    };
    sonarr = {
      defaultPort = 8989;
    };
    bazarr = {
      defaultPort = 6767;
    };
    readarr = {
      defaultPort = 8787;
    };
    lidarr = {
      defaultPort = 8686;
    };
  };

  appOption = name: c: lib.nameValuePair name (lib.mkOption {
    description = "Configuration for ${name}";
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "selfhostblocks.${name}";

        subdomain = lib.mkOption {
          type = lib.types.str;
          description = "Subdomain under which ${name} will be served.";
          example = name;
        };

        domain = lib.mkOption {
          type = lib.types.str;
          description = "Domain under which ${name} will be served.";
          example = "mydomain.com";
        };

        port = lib.mkOption {
          type = lib.types.port;
          description = "Port on which ${name} listens to incoming requests.";
          default = c.defaultPort;
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          description = "Directory where state of ${name} is stored.";
          default = "/var/lib/${name}";
        };

        oidcEndpoint = lib.mkOption {
          type = lib.types.str;
          description = "OIDC endpoint for SSO";
          example = "https://authelia.example.com";
        };
      };
    };
  });
in
{
  options.shb.arr = lib.listToAttrs (lib.mapAttrsToList appOption apps);

  config = lib.mkMerge ([
    {
      # Listens on port 7878
      services.radarr = lib.mkIf cfg.radarr.enable {
        enable = true;
        dataDir = "/var/lib/radarr";
      };
      users.users.radarr = {
        extraGroups = [ "media" ];
      };

      # Listens on port 8989
      services.sonarr = lib.mkIf cfg.sonarr.enable {
        enable = true;
        dataDir = "/var/lib/sonarr";
      };
      users.users.sonarr = {
        extraGroups = [ "media" ];
      };

      services.bazarr = lib.mkIf cfg.bazarr.enable {
        enable = true;
        listenPort = cfg.bazarr.port;
      };

      # Listens on port 8787
      services.readarr = lib.mkIf cfg.readarr.enable {
        enable = true;
        dataDir = "/var/lib/readarr";
      };
      users.users.readarr = {
        extraGroups = [ "media" ];
      };

      # Listens on port 8686
      services.lidarr = lib.mkIf cfg.lidarr.enable {
        enable = true;
        dataDir = "/var/lib/lidarr";
      };
      users.users.lidarr = {
        extraGroups = [ "media" ];
      };

      shb.nginx.autheliaProtect =
        let
          appProtectConfig = name: _defaults:
            let
              c = cfg.${name};
            in
              {
                inherit (c) subdomain domain oidcEndpoint;
                upstream = "http://127.0.0.1:${toString c.port}";
                autheliaRules = [
                  {
                    domain = "${c.subdomain}.${c.domain}";
                    policy = "bypass";
                    resources = [
                      "^/api.*"
                    ];
                  }
                  {
                    domain = "${c.subdomain}.${c.domain}";
                    policy = "two_factor";
                    subject = ["group:arr_user"];
                  }
                ];
              };
        in
          lib.mapAttrsToList appProtectConfig apps;

      shb.backup.instances =
        let
          backupConfig = name: _defaults: {
            ${name} = {
              sourceDirectories = [
                config.shb.arr.${name}.dataDir
              ];
              excludePatterns = [".db-shm" ".db-wal" ".mono"];
            };
          };
        in
          lib.mkMerge (lib.mapAttrsToList backupConfig apps);
    }
  ] ++ map (name: {
    systemd.tmpfiles.rules = lib.mkIf (lib.hasAttr "dataDir" config.services.${name}) [
      "d '${config.services.${name}.dataDir}' 0750 ${config.services.${name}.user} ${config.services.${name}.group} - -"
    ];
    users.groups.${name} = {
      members = [ "backup" ];
    };
    systemd.services.${name}.serviceConfig = {
      # Setup permissions needed for backups, as the backup user is member of the jellyfin group.
      UMask = lib.mkForce "0027";
      StateDirectoryMode = lib.mkForce "0750";
    };
  }) (lib.attrNames apps));
}
