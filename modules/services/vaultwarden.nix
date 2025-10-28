{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.shb.vaultwarden;

  contracts = pkgs.callPackage ../contracts { };

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  dataFolder =
    if lib.versionOlder (config.system.stateVersion or "24.11") "24.11" then
      "/var/lib/bitwarden_rs"
    else
      "/var/lib/vaultwarden";
in
{
  imports = [
    ../blocks/nginx.nix
  ];

  options.shb.vaultwarden = {
    enable = lib.mkEnableOption "selfhostblocks.vaultwarden";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which Authelia will be served.";
      example = "ha";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which Authelia will be served.";
      example = "mydomain.com";
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port on which vaultwarden service listens.";
      default = 8222;
    };

    authEndpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "OIDC endpoint for SSO";
      default = null;
      example = "https://authelia.example.com";
    };

    databasePassword = lib.mkOption {
      description = "File containing the Vaultwarden database password.";
      type = lib.types.submodule {
        options = contracts.secret.mkRequester {
          mode = "0440";
          owner = "vaultwarden";
          group = "postgres";
          restartUnits = [
            "vaultwarden.service"
            "postgresql.service"
          ];
        };
      };
    };

    smtp = lib.mkOption {
      description = "SMTP options.";
      default = null;
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            from_address = lib.mkOption {
              type = lib.types.str;
              description = "SMTP address from which the emails originate.";
              example = "vaultwarden@mydomain.com";
            };
            from_name = lib.mkOption {
              type = lib.types.str;
              description = "SMTP name from which the emails originate.";
              default = "Vaultwarden";
            };
            host = lib.mkOption {
              type = lib.types.str;
              description = "SMTP host to send the emails to.";
            };
            security = lib.mkOption {
              type = lib.types.enum [
                "starttls"
                "force_tls"
                "off"
              ];
              description = "Security expected by SMTP host.";
              default = "starttls";
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
            auth_mechanism = lib.mkOption {
              type = lib.types.enum [ "Login" ];
              description = "Auth mechanism.";
              default = "Login";
            };
            password = lib.mkOption {
              description = "File containing the password to connect to the SMTP host.";
              type = lib.types.submodule {
                options = contracts.secret.mkRequester {
                  mode = "0400";
                  owner = "vaultwarden";
                  restartUnits = [ "vaultwarden.service" ];
                };
              };
            };
          };
        }
      );
    };

    mount = lib.mkOption {
      type = contracts.mount;
      description = ''
        Mount configuration. This is an output option.

        Use it to initialize a block implementing the "mount" contract.
        For example, with a zfs dataset:

        ```
        shb.zfs.datasets."vaultwarden" = {
          poolName = "root";
        } // config.shb.vaultwarden.mount;
        ```
      '';
      readOnly = true;
      default = {
        path = dataFolder;
      };
    };

    backup = lib.mkOption {
      description = ''
        Backup configuration.
      '';
      default = { };
      type = lib.types.submodule {
        options = contracts.backup.mkRequester {
          user = "vaultwarden";
          sourceDirectories = [
            dataFolder
          ];
        };
      };
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      description = "Set to true to enable debug logging.";
      default = false;
      example = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.vaultwarden = {
      enable = true;
      dbBackend = "postgresql";
      config = {
        IP_HEADER = "X-Real-IP";
        SIGNUPS_ALLOWED = false;
        # Disabled because the /admin path is protected by SSO
        DISABLE_ADMIN_TOKEN = true;
        INVITATIONS_ALLOWED = true;
        DOMAIN = "https://${fqdn}";
        USE_SYSLOG = true;
        EXTENDED_LOGGING = cfg.debug;
        LOG_LEVEL = if cfg.debug then "trace" else "info";
        ROCKET_LOG = if cfg.debug then "trace" else "info";
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = cfg.port;
      }
      // lib.optionalAttrs (cfg.smtp != null) {
        SMTP_FROM = cfg.smtp.from_address;
        SMTP_FROM_NAME = cfg.smtp.from_name;
        SMTP_HOST = cfg.smtp.host;
        SMTP_SECURITY = cfg.smtp.security;
        SMTP_USERNAME = cfg.smtp.username;
        SMTP_PORT = cfg.smtp.port;
        SMTP_AUTH_MECHANISM = cfg.smtp.auth_mechanism;
      };
      environmentFile = "${dataFolder}/vaultwarden.env";
    };
    # We create a blank environment file for the service to start. Then, ExecPreStart kicks in and
    # fills out the environment file for ExecStart to pick it up.
    systemd.tmpfiles.rules = [
      "d ${dataFolder} 0750 vaultwarden vaultwarden"
      "f ${dataFolder}/vaultwarden.env 0640 vaultwarden vaultwarden"
    ];
    # Needed to be able to write template config.
    systemd.services.vaultwarden.serviceConfig.ProtectHome = lib.mkForce false;
    systemd.services.vaultwarden.preStart = lib.shb.replaceSecrets {
      userConfig = {
        DATABASE_URL.source = cfg.databasePassword.result.path;
        DATABASE_URL.transform = v: "postgresql://vaultwarden:${v}@127.0.0.1:5432/vaultwarden";
      }
      // lib.optionalAttrs (cfg.smtp != null) {
        SMTP_PASSWORD.source = cfg.smtp.password.result.path;
      };
      resultPath = "${dataFolder}/vaultwarden.env";
      generator = lib.shb.toEnvVar;
    };

    shb.nginx.vhosts = [
      {
        inherit (cfg)
          subdomain
          domain
          authEndpoint
          ssl
          ;
        upstream = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
        autheliaRules = lib.mkIf (cfg.authEndpoint != null) [
          {
            domain = "${fqdn}";
            policy = "two_factor";
            subject = [ "group:vaultwarden_admin" ];
            resources = [
              "^/admin"
            ];
          }
          # There's no way to protect the webapp using Authelia this way, see
          # https://github.com/dani-garcia/vaultwarden/discussions/3188
          {
            domain = fqdn;
            policy = "bypass";
          }
        ];
      }
    ];

    shb.postgresql.enableTCPIP = true;
    shb.postgresql.ensures = [
      {
        username = "vaultwarden";
        database = "vaultwarden";
        passwordFile = cfg.databasePassword.result.path;
      }
    ];
    # TODO: make this work.
    # It does not work because it leads to infinite recursion.
    # ${cfg.mount}.path = dataFolder;
  };
}
