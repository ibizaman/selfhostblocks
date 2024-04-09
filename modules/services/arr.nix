{ config, pkgs, lib, ... }:

let
  cfg = config.shb.arr;

  contracts = pkgs.callPackage ../contracts {};
  shblib = pkgs.callPackage ../../lib {};

  apps = {
    radarr = {
      settingsFormat = formatXML {};
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for radarr.";
          default = {};
          type = lib.types.submodule {
            freeformType = apps.radarr.settingsFormat.type;
            options = {
              APIKey = lib.mkOption {
                type = shblib.secretFileType;
                description = "Path to api key secret file.";
              };
              LogLevel = lib.mkOption {
                type = lib.types.enum ["debug" "info"];
                description = "Log level.";
                default = "info";
              };
              Port = lib.mkOption {
                type = lib.types.port;
                description = "Port on which radarr listens to incoming requests.";
                default = 7878;
              };
              AnalyticsEnabled = lib.mkOption {
                type = lib.types.bool;
                description = "Wether to send anonymous data or not.";
                default = false;
              };
              BindAddress = lib.mkOption {
                type = lib.types.str;
                internal = true;
                default = "127.0.0.1";
              };
              UrlBase = lib.mkOption {
                type = lib.types.str;
                internal = true;
                default = "";
              };
              EnableSsl = lib.mkOption {
                type = lib.types.bool;
                internal = true;
                default = false;
              };
              AuthenticationMethod = lib.mkOption {
                type = lib.types.str;
                internal = true;
                default = "External";
              };
              AuthenticationRequired = lib.mkOption {
                type = lib.types.str;
                internal = true;
                default = "Enabled";
              };
            };
          };
        };
      };
    };
    sonarr = {
      settingsFormat = formatXML {};
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for sonarr.";
          default = {};
          type = lib.types.submodule {
            freeformType = apps.sonarr.settingsFormat.type;
            options = {
              APIKey = lib.mkOption {
                type = shblib.secretFileType;
                description = "Path to api key secret file.";
              };
              LogLevel = lib.mkOption {
                type = lib.types.enum ["debug" "info"];
                description = "Log level.";
                default = "info";
              };
              Port = lib.mkOption {
                type = lib.types.port;
                description = "Port on which sonarr listens to incoming requests.";
                default = 8989;
              };
              BindAddress = lib.mkOption {
                type = lib.types.str;
                internal = true;
                default = "127.0.0.1";
              };
              UrlBase = lib.mkOption {
                type = lib.types.str;
                internal = true;
                default = "";
              };
              EnableSsl = lib.mkOption {
                type = lib.types.bool;
                internal = true;
                default = false;
              };
              AuthenticationMethod = lib.mkOption {
                type = lib.types.str;
                internal = true;
                default = "External";
              };
              AuthenticationRequired = lib.mkOption {
                type = lib.types.str;
                internal = true;
                default = "Enabled";
              };
            };
          };
        };
      };
    };
    bazarr = {
      settingsFormat = formatXML {};
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for bazarr.";
          default = {};
          type = lib.types.submodule {
            freeformType = apps.bazarr.settingsFormat.type;
            options = {
              LogLevel = lib.mkOption {
                type = lib.types.enum ["debug" "info"];
                description = "Log level.";
                default = "info";
              };
              Port = lib.mkOption {
                type = lib.types.port;
                description = "Port on which bazarr listens to incoming requests.";
                default = 6767;
                readOnly = true;
              };
            };
          };
        };
      };
    };
    readarr = {
      settingsFormat = formatXML {};
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for readarr.";
          default = {};
          type = lib.types.submodule {
            freeformType = apps.readarr.settingsFormat.type;
            options = {
              LogLevel = lib.mkOption {
                type = lib.types.enum ["debug" "info"];
                description = "Log level.";
                default = "info";
              };
              Port = lib.mkOption {
                type = lib.types.port;
                description = "Port on which readarr listens to incoming requests.";
                default = 8787;
              };
            };
          };
        };
      };
    };
    lidarr = {
      settingsFormat = formatXML {};
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for lidarr.";
          default = {};
          type = lib.types.submodule {
            freeformType = apps.lidarr.settingsFormat.type;
            options = {
              LogLevel = lib.mkOption {
                type = lib.types.enum ["debug" "info"];
                description = "Log level.";
                default = "info";
              };
              Port = lib.mkOption {
                type = lib.types.port;
                description = "Port on which lidarr listens to incoming requests.";
                default = 8686;
              };
            };
          };
        };
      };
    };
    jackett = {
      settingsFormat = pkgs.formats.json {};
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for jackett.";
          default = {};
          type = lib.types.submodule {
            freeformType = apps.jackett.settingsFormat.type;
            options = {
              APIKey = lib.mkOption {
                type = shblib.secretFileType;
                description = "Path to api key secret file.";
              };
              FlareSolverrUrl = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                description = "FlareSolverr endpoint.";
                default = null;
              };
              OmdbApiKey = lib.mkOption {
                type = lib.types.nullOr shblib.secretFileType;
                description = "File containing the Open Movie Database API key.";
                default = null;
              };
              ProxyType = lib.mkOption {
                type = lib.types.enum [ "-1" "0" "1" "2" ];
                default = "-1";
                description = ''
                -1 = disabled
                0 = HTTP
                1 = SOCKS4
                2 = SOCKS5
                '';
              };
              ProxyUrl = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                description = "URL of the proxy. Ignored if ProxyType is set to -1";
                default = null;
              };
              ProxyPort = lib.mkOption {
                type = lib.types.nullOr lib.types.port;
                description = "Port of the proxy. Ignored if ProxyType is set to -1";
                default = null;
              };
              Port = lib.mkOption {
                type = lib.types.port;
                description = "Port on which jackett listens to incoming requests.";
                default = 9117;
                readOnly = true;
              };
              AllowExternal = lib.mkOption {
                type = lib.types.bool;
                internal = true;
                default = false;
              };
              UpdateDisabled = lib.mkOption {
                type = lib.types.bool;
                internal = true;
                default = true;
              };
            };
          };
        };
      };
    };
  };

  autheliaProtect = { extraBypassResources ? [] }: c: {
    inherit (c) subdomain domain authEndpoint ssl;

    upstream = "http://127.0.0.1:${toString c.settings.Port}";
    autheliaRules = lib.optionals (!(isNull c.authEndpoint)) [
      {
        domain = "${c.subdomain}.${c.domain}";
        policy = "bypass";
        resources = extraBypassResources ++ [
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

  backup = name: {
    systemd.tmpfiles.rules = [
      "d '${config.shb.arr.${name}.dataDir}' 0750 ${config.services.${name}.user} ${config.services.${name}.group} - -"
    ];
    users.groups.${name} = {
      members = [ "backup" ];
    };
    systemd.services.${name}.serviceConfig = {
      # Setup permissions needed for backups, as the backup user is member of the jellyfin group.
      UMask = lib.mkForce "0027";
      StateDirectoryMode = lib.mkForce "0750";
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

    generate = value: builtins.readFile (pkgs.callPackage ({ runCommand, python3 }: runCommand "config" {
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
    '')) {});

  };

  appOption = name: c: lib.nameValuePair name (lib.mkOption {
    description = "Configuration for ${name}";
    default = {};
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption name;

        subdomain = lib.mkOption {
          type = lib.types.str;
          description = "Subdomain under which ${name} will be served.";
          example = name;
        };

        domain = lib.mkOption {
          type = lib.types.str;
          description = "Domain under which ${name} will be served.";
          example = "example.com";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          description = "Directory where ${name} stores data.";
          default = "/var/lib/${name}";
        };

        ssl = lib.mkOption {
          description = "Path to SSL files";
          type = lib.types.nullOr contracts.ssl.certs;
          default = null;
        };

        authEndpoint = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Endpoint to the SSO provider. Leave null to not have SSO configured.";
          example = "https://authelia.example.com";
        };

        backupCfg = lib.mkOption {
          type = lib.types.anything;
          description = "Backup configuration for ${name}.";
          default = {};
          example = {
            backend = "restic";
            repositories = [];
          };
        };
      } // (c.moreOptions or {});
    };
  });
in
{
  options.shb.arr = lib.listToAttrs (lib.mapAttrsToList appOption apps);

  config = lib.mkMerge ([
    (lib.mkIf cfg.radarr.enable (
    let
      cfg' = cfg.radarr;
      isSSOEnabled = !(isNull cfg'.authEndpoint);
    in
    {
      services.nginx.enable = true;

      services.radarr = {
        enable = true;
        dataDir = "/var/lib/radarr";
      };

      users.users.radarr = {
        extraGroups = [ "media" ];
      };

      systemd.services.radarr.preStart = shblib.replaceSecrets {
        userConfig = cfg'.settings
                     // (lib.optionalAttrs isSSOEnabled {
                       AuthenticationRequired = "DisabledForLocalAddresses";
                       AuthenticationMethod = "External";
                     });
        resultPath = "${config.services.radarr.dataDir}/config.xml";
        generator = apps.radarr.settingsFormat.generate;
      };

      shb.nginx.autheliaProtect = [ (autheliaProtect {} cfg') ];

      shb.backup.instances.radarr = cfg'.backupCfg // {
        sourceDirectories = [
          cfg'.dataDir
        ];
        excludePatterns = [".db-shm" ".db-wal" ".mono"];
      };
    } // backup "radarr"))

    (lib.mkIf cfg.sonarr.enable (
    let
      cfg' = cfg.sonarr;
      isSSOEnabled = !(isNull cfg'.authEndpoint);
    in
    {
      services.nginx.enable = true;

      services.sonarr = {
        enable = true;
        dataDir = "/var/lib/sonarr";
      };
      users.users.sonarr = {
        extraGroups = [ "media" ];
      };

      systemd.services.sonarr.preStart = shblib.replaceSecrets {
        userConfig = cfg'.settings
                     // (lib.optionalAttrs isSSOEnabled {
                       AuthenticationRequired = "DisabledForLocalAddresses";
                       AuthenticationMethod = "External";
                     });
        resultPath = "${config.services.sonarr.dataDir}/config.xml";
        generator = apps.sonarr.settingsFormat.generate;
      };

      shb.nginx.autheliaProtect = [ (autheliaProtect {} cfg') ];

      shb.backup.instances.sonarr = cfg'.backupCfg // {
        sourceDirectories = [
          cfg'.dataDir
        ];
        excludePatterns = [".db-shm" ".db-wal" ".mono"];
      };
    } // backup "sonarr"))

    (lib.mkIf cfg.bazarr.enable (
    let
      cfg' = cfg.bazarr;
    in
    {
      services.bazarr = {
        enable = true;
        listenPort = cfg'.settings.Port;
      };
      users.users.bazarr = {
        extraGroups = [ "media" ];
      };
      systemd.services.bazarr.preStart = shblib.replaceSecrets {
        userConfig = cfg'.settings;
        resultPath = "/var/lib/${config.systemd.services.bazarr.serviceConfig.StateDirectory}/config.xml";
        generator = apps.bazarr.settingsFormat.generate;
      };

      shb.nginx.autheliaProtect = [ (autheliaProtect {} cfg') ];

      shb.backup.instances.bazarr = cfg'.backupCfg // {
        sourceDirectories = [
          cfg'.dataDir
        ];
        excludePatterns = [".db-shm" ".db-wal" ".mono"];
      };
    } // backup "bazarr"))

    (lib.mkIf cfg.readarr.enable (
    let
      cfg' = cfg.readarr;
    in
    {
      services.readarr = {
        enable = true;
        dataDir = "/var/lib/readarr";
      };
      users.users.readarr = {
        extraGroups = [ "media" ];
      };
      systemd.services.readarr.preStart = shblib.replaceSecrets {
        userConfig = cfg'.settings;
        resultPath = "${config.services.readarr.dataDir}/config.xml";
        generator = apps.readarr.settingsFormat.generate;
      };

      shb.nginx.autheliaProtect = [ (autheliaProtect {} cfg') ];

      shb.backup.instances.readarr = cfg'.backupCfg // {
        sourceDirectories = [
          cfg'.dataDir
        ];
        excludePatterns = [".db-shm" ".db-wal" ".mono"];
      };
    } // backup "readarr"))

    (lib.mkIf cfg.lidarr.enable (
    let
      cfg' = cfg.lidarr;
    in
    {
      services.lidarr = {
        enable = true;
        dataDir = "/var/lib/lidarr";
      };
      users.users.lidarr = {
        extraGroups = [ "media" ];
      };
      systemd.services.lidarr.preStart = shblib.replaceSecrets {
        userConfig = cfg'.settings;
        resultPath = "${config.services.lidarr.dataDir}/config.xml";
        generator = apps.lidarr.settingsFormat.generate;
      };

      shb.nginx.autheliaProtect = [ (autheliaProtect {} cfg') ];

      shb.backup.instances.lidarr = cfg'.backupCfg // {
        sourceDirectories = [
          cfg'.dataDir
        ];
        excludePatterns = [".db-shm" ".db-wal" ".mono"];
      };
    } // backup "lidarr"))

    (lib.mkIf cfg.jackett.enable (
    let
      cfg' = cfg.jackett;
    in
    {
      services.jackett = {
        enable = true;
        dataDir = "/var/lib/jackett";
      };
      users.users.jackett = {
        extraGroups = [ "media" ];
      };
      systemd.services.jackett.preStart = shblib.replaceSecrets {
        userConfig = cfg'.settings;
        resultPath = "${config.services.jackett.dataDir}/config.xml";
        generator = apps.jackett.settingsFormat.generate;
      };

      shb.nginx.autheliaProtect = [ (autheliaProtect {
        extraBypassResources = [ "^/dl.*" ];
      } cfg') ];

      shb.backup.instances.jackett = cfg'.backupCfg // {
        sourceDirectories = [
          cfg'.dataDir
        ];
        excludePatterns = [".db-shm" ".db-wal" ".mono"];
      };
    } // backup "jackett"))
  ]);
}
