{
  config,
  lib,
  shb,
  ...
}:

let
  cfg = config.shb.firefly-iii;
in
{
  imports = [
    ../../lib/module.nix
  ];

  options.shb.firefly-iii = {
    enable = lib.mkEnableOption "SHB's firefly-iii module";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = ''
        Subdomain under which firefly-iii will be served.

        ```
        <subdomain>.<domain>
        ```
      '';
      example = "firefly-iii";
    };

    domain = lib.mkOption {
      description = ''
        Domain under which firefly-iii is served.

        ```
        <subdomain>.<domain>[:<port>]
        ```
      '';
      type = lib.types.str;
      example = "domain.com";
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr shb.contracts.ssl.certs;
      default = null;
    };

    siteOwnerEmail = lib.mkOption {
      description = "Email of the site owner.";
      type = lib.types.str;
      example = "mail@example.com";
    };

    impermanence = lib.mkOption {
      description = ''
        Path to save when using impermanence setup.
      '';
      type = lib.types.str;
      default = config.services.firefly-iii.dataDir;
      defaultText = "services.firefly-iii.dataDir";
    };

    backup = lib.mkOption {
      description = ''
        Backup configuration.
      '';
      default = { };
      type = lib.types.submodule {
        options = shb.contracts.backup.mkRequester {
          user = config.services.firefly-iii.user;
          userText = "services.firefly-iii.user";
          sourceDirectories = [
            config.services.firefly-iii.dataDir
          ];
          sourceDirectoriesText = ''
            [
              config.services.firefly-iii.dataDir
            ]
          '';
        };
      };
    };

    appKey = lib.mkOption {
      description = "Encryption key used for sessions. Must be 32 characters long exactly.";
      type = lib.types.submodule {
        options = shb.contracts.secret.mkRequester {
          mode = "0400";
          owner = config.services.firefly-iii.user;
          ownerText = "services.firefly-iii.user";
          restartUnits = [ "firefly-iii-setup.service" ];
        };
      };
    };

    dbPassword = lib.mkOption {
      description = "DB password.";
      type = lib.types.submodule {
        options = shb.contracts.secret.mkRequester {
          mode = "0440";
          owner = config.services.firefly-iii.user;
          ownerText = "services.firefly-iii.user";
          group = "postgres";
          restartUnits = [
            "postgresql.service"
            "firefly-iii-setup.service"
          ];
        };
      };
    };

    ldap = lib.mkOption {
      description = ''
        LDAP Integration
      '';
      default = { };
      type = lib.types.submodule {
        options = {
          userGroup = lib.mkOption {
            type = lib.types.str;
            description = "Group users must belong to to be able to login to Firefly-iii.";
            default = "firefly-iii_user";
          };
          adminGroup = lib.mkOption {
            type = lib.types.str;
            description = "Group users must belong to to be able to import data user the Firefly-iii data importer.";
            default = "firefly-iii_admin";
          };
        };
      };
    };

    sso = lib.mkOption {
      description = ''
        SSO Integration
      '';
      default = { };
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "SSO integration.";

          authEndpoint = lib.mkOption {
            type = lib.types.str;
            description = "OIDC endpoint for SSO.";
            example = "https://authelia.example.com";
          };

          port = lib.mkOption {
            description = "If given, adds a port to the endpoint.";
            type = lib.types.nullOr lib.types.port;
            default = null;
          };

          provider = lib.mkOption {
            type = lib.types.enum [ "Authelia" ];
            description = "OIDC provider name, used for display.";
            default = "Authelia";
          };

          clientID = lib.mkOption {
            type = lib.types.str;
            description = "Client ID for the OIDC endpoint.";
            default = "firefly-iii";
          };

          authorization_policy = lib.mkOption {
            type = lib.types.enum [
              "one_factor"
              "two_factor"
            ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };

          adminGroup = lib.mkOption {
            type = lib.types.str;
            description = "Group admins must belong to to be able to login to Firefly-iii.";
            default = "firefly-iii_admin";
          };

          secret = lib.mkOption {
            description = "OIDC shared secret.";
            type = lib.types.submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = "firefly-iii";
                restartUnits = [ "firefly-iii-setup.service" ];
              };
            };
          };

          secretForAuthelia = lib.mkOption {
            description = "OIDC shared secret. Content must be the same as `secretFile` option.";
            type = lib.types.submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = "authelia";
              };
            };
          };
        };
      };
    };

    smtp = lib.mkOption {
      description = ''
        If set, send notifications through smtp.

        https://docs.firefly-iii.org/how-to/firefly-iii/advanced/notifications/
      '';
      default = null;
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            from_address = lib.mkOption {
              type = lib.types.str;
              description = "SMTP address from which the emails originate.";
              example = "authelia@mydomain.com";
            };
            host = lib.mkOption {
              type = lib.types.str;
              description = "SMTP host to send the emails to.";
            };
            port = lib.mkOption {
              type = lib.types.port;
              description = "SMTP port to send the emails to.";
              default = 25;
            };
            username = lib.mkOption {
              type = lib.types.str;
              description = "Username to connect to the SMTP host.";
            };
            password = lib.mkOption {
              description = "File containing the password to connect to the SMTP host.";
              type = lib.types.submodule {
                options = shb.contracts.secret.mkRequester {
                  mode = "0400";
                  owner = config.services.firefly-iii.user;
                  ownerText = "services.firefly-iii.user";
                  restartUnits = [ "firefly-iii-setup.service" ];
                };
              };
            };
          };
        }
      );
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      description = "Enable more verbose logging.";
      default = false;
      example = true;
    };

    importer = lib.mkOption {
      description = ''
        Configuration for Firefly-iii data importer.
      '';
      default = { };
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Firefly-iii Data Importer." // {
            default = true;
          };

          subdomain = lib.mkOption {
            type = lib.types.str;
            description = ''
              Subdomain under which the firefly-iii data importer will be served.
            '';
            default = "${cfg.subdomain}-importer";
            defaultText = lib.literalExpression ''''${shb.firefly-iii.subdomain}-importer'';
          };

          firefly-iii-accessToken = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = shb.contracts.secret.mkRequester {
                  mode = "0400";
                  owner = config.services.firefly-iii-data-importer.user;
                  ownerText = "services.firefly-iii-data-importer.user";
                  restartUnits = [ "firefly-iii-data-importer-setup.service" ];
                };
              }
            );
            description = ''
              Create a Personal Access Token then set then token in this option.
            '';
            default = null;
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.firefly-iii = {
          enable = true;
          group = "nginx";

          virtualHost = "${cfg.subdomain}.${cfg.domain}";

          # https://github.com/firefly-iii/firefly-iii/blob/main/.env.example
          settings = {
            APP_ENV = "production";
            APP_URL = "https://${cfg.subdomain}.${cfg.domain}";

            APP_DEBUG = cfg.debug;
            APP_LOG_LEVEL = if cfg.debug then "debug" else "notice";
            LOG_CHANNEL = "stdout";

            APP_KEY_FILE = cfg.appKey.result.path;
            SITE_OWNER = cfg.siteOwnerEmail;
            DB_CONNECTION = "pgsql";
            DB_HOST = "localhost";
            DB_PORT = config.services.postgresql.settings.port;
            DB_DATABASE = "firefly-iii";
            DB_USERNAME = "firefly-iii";
            DB_PASSWORD_FILE = cfg.dbPassword.result.path;

            # MAP_DEFAULT_LAT = "51.983333";
            # MAP_DEFAULT_LONG = "5.916667";
            # MAP_DEFAULT_ZOOM = "6";
          };
        };
        shb.postgresql.enableTCPIP = true;
        shb.postgresql.ensures = [
          {
            username = "firefly-iii";
            database = "firefly-iii";
            passwordFile = cfg.dbPassword.result.path;
          }
        ];

        # This should be using a contract instead of setting the option directly.
        shb.lldap = lib.mkIf config.shb.lldap.enable {
          ensureGroups = {
            ${cfg.ldap.userGroup} = { };
            ${cfg.ldap.adminGroup} = { };
          };
        };

        # We enable the firefly-iii nginx integration and merge it with SHB's nginx configuration.
        services.firefly-iii.enableNginx = true;
        shb.nginx.vhosts = [
          {
            inherit (cfg) subdomain domain ssl;
          }
        ];
      }
      (lib.mkIf cfg.importer.enable {
        services.firefly-iii-data-importer = {
          enable = true;

          virtualHost = "${cfg.importer.subdomain}.${cfg.domain}";

          settings = {
            FIREFLY_III_URL = "https://${config.services.firefly-iii.virtualHost}";
          }
          // lib.optionalAttrs (cfg.importer.firefly-iii-accessToken != null) {
            FIREFLY_III_ACCESS_TOKEN_FILE = cfg.importer.firefly-iii-accessToken.result.path;
          };
        };

        # We enable the firefly-iii-data-importer nginx integration and merge it with SHB's nginx configuration.
        services.firefly-iii-data-importer.enableNginx = true;
        shb.nginx.vhosts = [
          {
            inherit (cfg) domain ssl;
            subdomain = cfg.importer.subdomain;
          }
        ];
      })
      (lib.mkIf (cfg.smtp != null) {
        services.firefly-iii.settings = {
          MAIL_MAILER = "smtp";
          MAIL_HOST = cfg.smtp.host;
          MAIL_PORT = cfg.smtp.port;
          MAIL_FROM = cfg.smtp.from_address;
          MAIL_USERNAME = cfg.smtp.username;
          MAIL_PASSWORD_FILE = cfg.smtp.password.result.path;
          MAIL_ENCRYPTION = "tls";
        };
      })
      (lib.mkIf cfg.sso.enable {
        services.firefly-iii.settings = {
          AUTHENTICATION_GUARD = "remote_user_guard";
          AUTHENTICATION_GUARD_HEADER = "HTTP_X_FORWARDED_USER";
        };

        shb.nginx.vhosts = [
          {
            inherit (cfg) subdomain domain ssl;
            inherit (cfg.sso) authEndpoint;

            phpForwardAuth = true;
            autheliaRules = [
              {
                domain = "${cfg.subdomain}.${cfg.domain}";
                policy = "bypass";
                resources = [ "^/api" ];
              }
              {
                domain = "${cfg.subdomain}.${cfg.domain}";
                policy = cfg.sso.authorization_policy;
                subject = [ "group:${cfg.ldap.userGroup}" ];
              }
            ];
          }
        ];
      })
      (lib.mkIf (cfg.sso.enable && cfg.importer.enable) {
        shb.nginx.vhosts = [
          {
            inherit (cfg.importer) subdomain;
            inherit (cfg) domain ssl;
            inherit (cfg.sso) authEndpoint;

            autheliaRules = [
              {
                domain = "${cfg.importer.subdomain}.${cfg.domain}";
                policy = cfg.sso.authorization_policy;
                subject = [ "group:${cfg.ldap.adminGroup}" ];
              }
            ];
          }
        ];
      })
    ]
  );
}
