{ config, pkgs, lib, ... }:

let
  cfg = config.shb.vaultwarden;

  contracts = pkgs.callPackage ../contracts {};
  shblib = pkgs.callPackage ../../lib {};

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
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

    databasePasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the password to connect to the postgresql database.";
    };

    smtp = lib.mkOption {
      description = "SMTP options.";
      default = null;
      type = lib.types.nullOr (lib.types.submodule {
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
            type = lib.types.enum [ "starttls" "force_tls" "off" ];
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
          passwordFile = lib.mkOption {
            type = lib.types.str;
            description = "File containing the password to connect to the SMTP host.";
          };
        };
      });
    };

    backupConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.anything;
      description = "Backup configuration of Vaultwarden.";
      default = null;
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
        DATA_FOLDER = "/var/lib/bitwarden_rs";
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
      } // lib.optionalAttrs (cfg.smtp != null) {
        SMTP_FROM = cfg.smtp.from_address;
        SMTP_FROM_NAME = cfg.smtp.from_name;
        SMTP_HOST = cfg.smtp.host;
        SMTP_SECURITY = cfg.smtp.security;
        SMTP_USERNAME = cfg.smtp.username;
        SMTP_PORT = cfg.smtp.port;
        SMTP_AUTH_MECHANISM = cfg.smtp.auth_mechanism;
      };
      environmentFile = "/var/lib/bitwarden_rs/vaultwarden.env";
    };
    # We create a blank environment file for the service to start. Then, ExecPreStart kicks in and
    # fills out the environment file for ExecStart to pick it up.
    systemd.tmpfiles.rules = [
      "d /var/lib/bitwarden_rs 0750 vaultwarden vaultwarden"
      "f /var/lib/bitwarden_rs/vaultwarden.env 0640 vaultwarden vaultwarden"
    ];
    systemd.services.vaultwarden.preStart =
      shblib.replaceSecrets {
        userConfig = {
          DATABASE_URL.source = cfg.databasePasswordFile;
          DATABASE_URL.transform = v: "postgresql://vaultwarden:${v}@127.0.0.1:5432/vaultwarden";
        } // lib.optionalAttrs (cfg.smtp != null) {
          SMTP_PASSWORD.source = cfg.smtp.passwordFile;
        };
        resultPath = "/var/lib/bitwarden_rs/vaultwarden.env";
        generator = name: v: pkgs.writeText "template" (lib.generators.toINIWithGlobalSection {} { globalSection = v; });
      };

    shb.nginx.vhosts = [
      {
        inherit (cfg) subdomain domain authEndpoint ssl;
        upstream = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
        autheliaRules = lib.mkIf (cfg.authEndpoint != null) [
          {
            domain = "${fqdn}";
            policy = "two_factor";
            subject = ["group:vaultwarden_admin"];
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
        passwordFile = builtins.toString cfg.databasePasswordFile;
      }
    ];

    systemd.services.vaultwarden.serviceConfig.UMask = lib.mkForce "0027";
    # systemd.services.vaultwarden.serviceConfig.Group = lib.mkForce "media";
    users.users.vaultwarden = {
      extraGroups = [ "media" ];
    };

    users.groups.vaultwarden = {
      members = [ "backup" ];
    };

    shb.backup.instances.vaultwarden =
      cfg.backupConfig //
      {
        sourceDirectories = [
          config.services.vaultwarden.config.DATA_FOLDER
        ];
      };
  };
}
