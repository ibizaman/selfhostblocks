{
  config,
  pkgs,
  lib,
  shb,
  ...
}:

let
  cfg = config.shb.arr;

  apps = {
    radarr = {
      settingsFormat = shb.formatXML { enclosingRoot = "Config"; };
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for radarr.";
          default = { };
          type = lib.types.submodule {
            freeformType = apps.radarr.settingsFormat.type;
            options = {
              ApiKey = lib.mkOption {
                type = shb.secretFileType;
                description = "Path to api key secret file.";
              };
              LogLevel = lib.mkOption {
                type = lib.types.enum [
                  "debug"
                  "info"
                ];
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
      settingsFormat = shb.formatXML { enclosingRoot = "Config"; };
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for sonarr.";
          default = { };
          type = lib.types.submodule {
            freeformType = apps.sonarr.settingsFormat.type;
            options = {
              ApiKey = lib.mkOption {
                type = shb.secretFileType;
                description = "Path to api key secret file.";
              };
              LogLevel = lib.mkOption {
                type = lib.types.enum [
                  "debug"
                  "info"
                ];
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
      settingsFormat = shb.formatXML { enclosingRoot = "Config"; };
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for bazarr.";
          default = { };
          type = lib.types.submodule {
            freeformType = apps.bazarr.settingsFormat.type;
            options = {
              LogLevel = lib.mkOption {
                type = lib.types.enum [
                  "debug"
                  "info"
                ];
                description = "Log level.";
                default = "info";
              };
              ApiKey = lib.mkOption {
                type = shb.secretFileType;
                description = "Path to api key secret file.";
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
      settingsFormat = shb.formatXML { enclosingRoot = "Config"; };
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for readarr.";
          default = { };
          type = lib.types.submodule {
            freeformType = apps.readarr.settingsFormat.type;
            options = {
              LogLevel = lib.mkOption {
                type = lib.types.enum [
                  "debug"
                  "info"
                ];
                description = "Log level.";
                default = "info";
              };
              ApiKey = lib.mkOption {
                type = shb.secretFileType;
                description = "Path to api key secret file.";
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
      settingsFormat = shb.formatXML { enclosingRoot = "Config"; };
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for lidarr.";
          default = { };
          type = lib.types.submodule {
            freeformType = apps.lidarr.settingsFormat.type;
            options = {
              LogLevel = lib.mkOption {
                type = lib.types.enum [
                  "debug"
                  "info"
                ];
                description = "Log level.";
                default = "info";
              };
              ApiKey = lib.mkOption {
                type = shb.secretFileType;
                description = "Path to api key secret file.";
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
      settingsFormat = pkgs.formats.json { };
      moreOptions = {
        settings = lib.mkOption {
          description = "Specific options for jackett.";
          default = { };
          type = lib.types.submodule {
            freeformType = apps.jackett.settingsFormat.type;
            options = {
              ApiKey = lib.mkOption {
                type = shb.secretFileType;
                description = "Path to api key secret file.";
              };
              FlareSolverrUrl = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                description = "FlareSolverr endpoint.";
                default = null;
              };
              OmdbApiKey = lib.mkOption {
                type = lib.types.nullOr shb.secretFileType;
                description = "File containing the Open Movie Database API key.";
                default = null;
              };
              ProxyType = lib.mkOption {
                type = lib.types.enum [
                  "-1"
                  "0"
                  "1"
                  "2"
                ];
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

  vhosts =
    {
      extraBypassResources ? [ ],
    }:
    c: {
      inherit (c)
        subdomain
        domain
        authEndpoint
        ssl
        ;

      upstream = "http://127.0.0.1:${toString c.settings.Port}";
      autheliaRules = lib.optionals (!(isNull c.authEndpoint)) [
        {
          domain = "${c.subdomain}.${c.domain}";
          policy = "bypass";
          resources = extraBypassResources ++ [
            "^/api.*"
            "^/feed.*"
          ];
        }
        {
          domain = "${c.subdomain}.${c.domain}";
          policy = "two_factor";
          subject = [ "group:${c.ldapUserGroup}" ];
        }
      ];
    };

  appOption =
    name: c:
    lib.nameValuePair name (
      lib.mkOption {
        description = "Configuration for ${name}";
        default = { };
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
              type = lib.types.nullOr shb.contracts.ssl.certs;
              default = null;
            };

            ldapUserGroup = lib.mkOption {
              description = ''
                LDAP group a user must belong to be able to login.

                Note that all users are admins too.
              '';
              type = lib.types.str;
              default = "arr_user";
            };

            authEndpoint = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Endpoint to the SSO provider. Leave null to not have SSO configured.";
              example = "https://authelia.example.com";
            };

            backup = lib.mkOption {
              description = ''
                Backup configuration.
              '';
              default = { };
              type = lib.types.submodule {
                options = shb.contracts.backup.mkRequester {
                  user = name;
                  sourceDirectories = [
                    cfg.${name}.dataDir
                  ];
                  excludePatterns = [
                    ".db-shm"
                    ".db-wal"
                    ".mono"
                  ];
                };
              };
            };

            dashboard = lib.mkOption {
              description = ''
                Dashboard contract consumer
              '';
              default = { };
              type = lib.types.submodule {
                options = shb.contracts.dashboard.mkRequester {
                  externalUrl = "https://${cfg.${name}.subdomain}.${cfg.${name}.domain}";
                  externalUrlText = "https://\${config.shb.arr.${name}.subdomain}.\${config.shb.arr.${name}.domain}";
                  internalUrl = "http://127.0.0.1:${toString cfg.${name}.settings.Port}";
                };
              };
            };
          }
          // (c.moreOptions or { });
        };
      }
    );
in
{
  imports = [
    ../../lib/module.nix
    ../blocks/nginx.nix
    ../blocks/lldap.nix
  ];

  options.shb.arr = lib.listToAttrs (lib.mapAttrsToList appOption apps);

  config = lib.mkMerge [
    (lib.mkIf cfg.radarr.enable (
      let
        cfg' = cfg.radarr;
        isSSOEnabled = !(isNull cfg'.authEndpoint);
      in
      {
        services.nginx.enable = true;

        services.radarr = {
          enable = true;
          dataDir = cfg'.dataDir;
        };

        systemd.services.radarr.preStart = shb.replaceSecrets {
          userConfig =
            cfg'.settings
            // (lib.optionalAttrs isSSOEnabled {
              AuthenticationRequired = "DisabledForLocalAddresses";
              AuthenticationMethod = "External";
            });
          resultPath = "${cfg'.dataDir}/config.xml";
          generator = shb.replaceSecretsFormatAdapter apps.radarr.settingsFormat;
        };

        shb.nginx.vhosts = [ (vhosts { } cfg') ];

        shb.lldap.ensureGroups = {
          ${cfg'.ldapUserGroup} = { };
        };
      }
    ))

    (lib.mkIf cfg.sonarr.enable (
      let
        cfg' = cfg.sonarr;
        isSSOEnabled = !(isNull cfg'.authEndpoint);
      in
      {
        services.nginx.enable = true;

        services.sonarr = {
          enable = true;
          dataDir = cfg'.dataDir;
        };
        users.users.sonarr = {
          extraGroups = [ "media" ];
        };

        systemd.services.sonarr.preStart = shb.replaceSecrets {
          userConfig =
            cfg'.settings
            // (lib.optionalAttrs isSSOEnabled {
              AuthenticationRequired = "DisabledForLocalAddresses";
              AuthenticationMethod = "External";
            });
          resultPath = "${cfg'.dataDir}/config.xml";
          generator = apps.sonarr.settingsFormat.generate;
        };

        shb.nginx.vhosts = [ (vhosts { } cfg') ];

        shb.lldap.ensureGroups = {
          ${cfg'.ldapUserGroup} = { };
        };
      }
    ))

    (lib.mkIf cfg.bazarr.enable (
      let
        cfg' = cfg.bazarr;
        isSSOEnabled = !(isNull cfg'.authEndpoint);
      in
      {
        services.bazarr = {
          enable = true;
          dataDir = cfg'.dataDir;
          listenPort = cfg'.settings.Port;
        };
        users.users.bazarr = {
          extraGroups = [ "media" ];
        };
        # This is actually not working. Bazarr uses a config file in dataDir/config/config.yaml
        # which includes all configuration so we must somehow merge our declarative config with it.
        # It's doable but will take some time. Help is welcomed.
        #
        # systemd.services.bazarr.preStart = shb.replaceSecrets {
        #   userConfig =
        #     cfg'.settings
        #     // (lib.optionalAttrs isSSOEnabled {
        #       AuthenticationRequired = "DisabledForLocalAddresses";
        #       AuthenticationMethod = "External";
        #     });
        #   resultPath = "${cfg'.dataDir}/config.xml";
        #   generator = apps.bazarr.settingsFormat.generate;
        # };

        shb.nginx.vhosts = [ (vhosts { } cfg') ];

        shb.lldap.ensureGroups = {
          ${cfg'.ldapUserGroup} = { };
        };
      }
    ))

    (lib.mkIf cfg.readarr.enable (
      let
        cfg' = cfg.readarr;
        isSSOEnabled = !(isNull cfg'.authEndpoint);
      in
      {
        services.readarr = {
          enable = true;
          dataDir = cfg'.dataDir;
        };
        users.users.readarr = {
          extraGroups = [ "media" ];
        };
        systemd.services.readarr.preStart = shb.replaceSecrets {
          userConfig =
            cfg'.settings
            // (lib.optionalAttrs isSSOEnabled {
              AuthenticationRequired = "DisabledForLocalAddresses";
              AuthenticationMethod = "External";
            });
          resultPath = "${cfg'.dataDir}/config.xml";
          generator = apps.readarr.settingsFormat.generate;
        };

        shb.nginx.vhosts = [ (vhosts { } cfg') ];

        shb.lldap.ensureGroups = {
          ${cfg'.ldapUserGroup} = { };
        };
      }
    ))

    (lib.mkIf cfg.lidarr.enable (
      let
        cfg' = cfg.lidarr;
        isSSOEnabled = !(isNull cfg'.authEndpoint);
      in
      {
        services.lidarr = {
          enable = true;
          dataDir = cfg'.dataDir;
        };
        users.users.lidarr = {
          extraGroups = [ "media" ];
        };
        systemd.services.lidarr.preStart = shb.replaceSecrets {
          userConfig =
            cfg'.settings
            // (lib.optionalAttrs isSSOEnabled {
              AuthenticationRequired = "DisabledForLocalAddresses";
              AuthenticationMethod = "External";
            });
          resultPath = "${cfg'.dataDir}/config.xml";
          generator = apps.lidarr.settingsFormat.generate;
        };

        shb.nginx.vhosts = [ (vhosts { } cfg') ];

        shb.lldap.ensureGroups = {
          ${cfg'.ldapUserGroup} = { };
        };
      }
    ))

    (lib.mkIf cfg.jackett.enable (
      let
        cfg' = cfg.jackett;
      in
      {
        services.jackett = {
          enable = true;
          dataDir = cfg'.dataDir;
        };
        # TODO: avoid implicitly relying on the media group
        users.users.jackett = {
          extraGroups = [ "media" ];
        };
        systemd.services.jackett.preStart = shb.replaceSecrets {
          userConfig = shb.renameAttrName cfg'.settings "ApiKey" "APIKey";
          resultPath = "${cfg'.dataDir}/ServerConfig.json";
          generator = apps.jackett.settingsFormat.generate;
        };

        shb.nginx.vhosts = [
          (vhosts {
            extraBypassResources = [ "^/dl.*" ];
          } cfg')
        ];

        shb.lldap.ensureGroups = {
          ${cfg'.ldapUserGroup} = { };
        };
      }
    ))
  ];
}
