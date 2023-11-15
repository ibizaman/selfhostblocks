{ config, pkgs, lib, ... }:

let
  cfg = config.shb.arr;

  apps = {
    radarr = {
      defaultPort = 7001;
      settingsFormat = formatXML {};
      moreOptions = {
        settings = lib.mkOption {
          default = {};
          type = lib.types.submodule {
            freeformType = apps.radarr.settingsFormat.type;
            options = {
              APIKeyFile = lib.mkOption {
                type = lib.types.path;
              };
              LogLevel = lib.mkOption {
                type = lib.types.enum ["debug" "info"];
                default = "info";
              };
            };
          };
        };
      };
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
    jackett = {
      defaultPort = 9117;
      settingsFormat = pkgs.formats.json {};
      moreOptions = {
        settings = lib.mkOption {
          default = {};
          type = lib.types.submodule {
            freeformType = apps.jackett.settingsFormat.type;
            options = {
              APIKeyFile = lib.mkOption {
                type = lib.types.path;
              };
              FlareSolverrUrl = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              OmdbApiKeyFile = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
              };
              ProxyType = lib.mkOption {
                type = lib.types.enum [ "-1" "0" "1" "2" ];
                default = "0";
                description = ''
                -1 = disabled
                0 = HTTP
                1 = SOCKS4
                2 = SOCKS5
                '';
              };
              ProxyUrl = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              ProxyPort = lib.mkOption {
                type = lib.types.nullOr lib.types.port;
                default = null;
              };
            };
          };
        };
      };
    };
  };

  formatXML = {}: {
    type = with lib.types; let
      valueType = nullOr (oneOf [
        bool
        int
        float
        str
        path
        (attrsOf valueType)
        (listOf valueType)
      ]) // {
        description = "XML value";
      };
    in valueType;

    generate = name: value: pkgs.callPackage ({ runCommand, python3 }: runCommand name {
      value = builtins.toJSON {Config = value;};
      passAsFile = [ "value" ];
    } (pkgs.writers.writePython3 "dict2xml" {
      libraries = with python3.pkgs; [ python dict2xml ];
    } ''
      import os
      import json
      from dict2xml import dict2xml

      with open(os.environ["valuePath"]) as f:
          content = json.loads(f.read())
          if content is None:
              print("Could not parse env var valuePath as json")
              os.exit(2)
          with open(os.environ["out"], "w") as out:
              out.write(dict2xml(content))
    '')) {};

  };

  appOption = name: c: lib.nameValuePair name (lib.mkOption {
    description = "Configuration for ${name}";
    default = {};
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
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "OIDC endpoint for SSO";
          example = "https://authelia.example.com";
        };
      } // (c.moreOptions or {});
    };
  });

  template = file: newPath: replacements:
    let
      templatePath = newPath + ".template";

      sedPatterns = lib.strings.concatStringsSep " " (lib.attrsets.mapAttrsToList (from: to: "-e \"s|${from}|${to}|\"") replacements);
    in
      ''
      ln -fs ${file} ${templatePath}
      rm ${newPath} || :
      sed ${sedPatterns} ${templatePath} > ${newPath}
      '';
in
{
  options.shb.arr = lib.listToAttrs (lib.mapAttrsToList appOption apps);

  config = lib.mkMerge ([
    {
      services.radarr = lib.mkIf cfg.radarr.enable {
        enable = true;
        dataDir = "/var/lib/radarr";
      };
      users.users.radarr = lib.mkIf cfg.radarr.enable {
        extraGroups = [ "media" ];
      };
      shb.arr.radarr.settings = lib.mkIf cfg.radarr.enable {
        Port = config.shb.arr.radarr.port;
        BindAddress = "127.0.0.1";
        UrlBase = "";
        EnableSsl = "false";
        AuthenticationMethod = "External";
        AuthenticationRequired = "Enabled";
      };
      systemd.services.radarr.preStart =
        let
          s = cfg.radarr.settings;
          templatedfileSettings =
            lib.optionalAttrs (!(isNull s.APIKeyFile)) {
              ApiKey = "%APIKEY%";
            };
          templatedSettings = (removeAttrs s [ "APIKeyFile" ]) // templatedfileSettings;

          t = template (apps.radarr.settingsFormat.generate "
config.xml" templatedSettings) "${config.services.radarr.dataDir}/config.xml" (
            lib.optionalAttrs (!(isNull s.APIKeyFile)) {
              "%APIKEY%" = "$(cat ${s.APIKeyFile})";
            }
          );
        in
          lib.mkIf cfg.radarr.enable t;

      # Listens on port 8989
      services.sonarr = lib.mkIf cfg.sonarr.enable {
        enable = true;
        dataDir = "/var/lib/sonarr";
      };
      users.users.sonarr = lib.mkIf cfg.sonarr.enable {
        extraGroups = [ "media" ];
      };

      services.bazarr = lib.mkIf cfg.bazarr.enable {
        enable = true;
        listenPort = cfg.bazarr.port;
      };
      users.users.bazarr = lib.mkIf cfg.bazarr.enable {
        extraGroups = [ "media" ];
      };

      # Listens on port 8787
      services.readarr = lib.mkIf cfg.readarr.enable {
        enable = true;
        dataDir = "/var/lib/readarr";
      };
      users.users.readarr = lib.mkIf cfg.readarr.enable {
        extraGroups = [ "media" ];
      };

      # Listens on port 8686
      services.lidarr = lib.mkIf cfg.lidarr.enable {
        enable = true;
        dataDir = "/var/lib/lidarr";
      };
      users.users.lidarr = lib.mkIf cfg.lidarr.enable {
        extraGroups = [ "media" ];
      };

      # Listens on port 9117
      services.jackett = lib.mkIf cfg.jackett.enable {
        enable = true;
        dataDir = "/var/lib/jackett";
      };
      shb.arr.jackett.settings = lib.mkIf cfg.jackett.enable {
        Port = config.shb.arr.jackett.port;
        AllowExternal = "false";
        UpdateDisabled = "true";
      };
      users.users.jackett = lib.mkIf cfg.jackett.enable {
        extraGroups = [ "media" ];
      };
      systemd.services.jackett.preStart =
        let
          s = cfg.jackett.settings;
          templatedfileSettings =
            lib.optionalAttrs (!(isNull s.APIKeyFile)) {
              APIKey = "%APIKEY%";
            } // lib.optionalAttrs (!(isNull s.OmdbApiKeyFile)) {
              OmdbApiKey = "%OMDBAPIKEY%";
            };
          templatedSettings = (removeAttrs s [ "APIKeyFile" "OmdbApiKeyFile" ]) // templatedfileSettings;

          t = template (apps.jackett.settingsFormat.generate "jackett.json" templatedSettings) "${config.services.jackett.dataDir}/ServerConfig.json" (
            lib.optionalAttrs (!(isNull s.APIKeyFile)) {
              "%APIKEY%" = "$(cat ${s.APIKeyFile})";
            } // lib.optionalAttrs (!(isNull s.OmdbApiKeyFile)) {
              "%OMDBAPIKEY%" = "$(cat ${s.OmdbApiKeyFile})";
            }
          );
        in
          lib.mkIf cfg.jackett.enable t;

      shb.nginx.autheliaProtect =
        let
          appProtectConfig = name: _defaults:
            let
              c = cfg.${name};
            in
              lib.mkIf (c.oidcEndpoint != null) {
                inherit (c) subdomain domain oidcEndpoint;
                upstream = "http://127.0.0.1:${toString c.port}";
                autheliaRules = [
                  {
                    domain = "${c.subdomain}.${c.domain}";
                    policy = "bypass";
                    resources = [
                      "^/api.*"
                    ] ++ lib.optionals (name == "jackett") [
                      "^/dl.*"
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
  ] ++ map (name: lib.mkIf cfg.${name}.enable {
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
