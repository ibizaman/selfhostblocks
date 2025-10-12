{ config, lib, pkgs, ... }:
let
  cfg = config.shb.pinchflat;

  inherit (lib) types;

  contracts = pkgs.callPackage ../contracts {};
in
{
  imports = [
    ../blocks/nginx.nix
  ];

  options.shb.pinchflat = {
    enable = lib.mkEnableOption "the Pinchflat service.";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which Pinchflat will be served.";
      default = "pinchflat";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which Pinchflat will be served.";
      example = "mydomain.com";
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port Pinchflat listens to incoming requests.";
      default = 8945;
    };

    secretKeyBase = lib.mkOption {
      description = ''
        Used to sign/encrypt cookies and other secrets.

        Make sure the secret is at least 64 characters long.
      '';
      type = types.submodule {
        options = contracts.secret.mkRequester {
          restartUnits = [ "pinchflat.service" ];
        };
      };
    };

    mediaDir = lib.mkOption {
      description = "Path where videos are stored.";
      type = lib.types.str;
    };

    timeZone = lib.mkOption {
      type = lib.types.oneOf [ lib.types.str lib.shb.secretFileType ];
      description = "Timezone of this instance.";
      example = "America/Los_Angeles";
    };

    ldap = lib.mkOption {
      description = ''
        Setup LDAP integration.
      '';
      default = {};
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption "LDAP integration." // {
            default = cfg.sso.enable;
          };

          userGroup = lib.mkOption {
            type = types.str;
            description = "Group users must belong to be able to login.";
            default = "pinchflat_user";
          };
        };
      };
    };

    sso = lib.mkOption {
      description = ''
        Setup SSO integration.
      '';
      default = {};
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption "SSO integration.";

          authEndpoint = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Endpoint to the SSO provider. Leave null to not have SSO configured.";
            example = "https://authelia.example.com";
          };

          authorization_policy = lib.mkOption {
            type = types.enum [ "one_factor" "two_factor" ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };
        };
      };
    };

    backup = lib.mkOption {
      description = ''
        Backup media directory `shb.mediaDir`.
      '';
      default = {};
      type = lib.types.submodule {
        options = contracts.backup.mkRequester {
          user = "pinchflat";
          sourceDirectories = [
            cfg.mediaDir
          ];
          sourceDirectoriesText = "[ config.shb.pinchflat.mediaDir ]";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '/run/pinchflat' 0750 root root - -"
    ];

    # Pinchflat relies on the global value so for now this is the only way to pass the option in.
    time.timeZone = lib.mkDefault cfg.timeZone;
    services.pinchflat = {
      inherit (cfg) enable port mediaDir;
      secretsFile = "/run/pinchflat/secrets.env";
      extraConfig = {
        ENABLE_PROMETHEUS = true;
        # TZ = "as"; # I consider where you live to be sensible so it should be passed as a secret.
      };
    };

    # This should be using a contract instead of setting the option directly.
    shb.lldap = lib.mkIf config.shb.lldap.enable {
      ensureGroups = { ${cfg.ldap.userGroup} = {}; };
    };

    systemd.services.pinchflat-pre = {
      script = lib.shb.replaceSecrets {
        userConfig = {
          SECRET_KEY_BASE.source = cfg.secretKeyBase.result.path;
          # TZ = cfg.secretKeyBase.result.path; # Uncomment when PR is merged.
        };
        resultPath = "/run/pinchflat/secrets.env";
        generator = lib.shb.toEnvVar;
      };
      serviceConfig.Type = "oneshot";
      wantedBy = [ "multi-user.target" ];
      before = [ "pinchflat.service" ];
      requiredBy = [ "pinchflat.service" ];
    };

    shb.nginx.vhosts = [ 
      {
        inherit (cfg) subdomain domain ssl;
        inherit (cfg.sso) authEndpoint;

        upstream = "http://127.0.0.1:${toString cfg.port}";
        autheliaRules = lib.optionals (cfg.sso.enable) [
          {
            domain = "${cfg.subdomain}.${cfg.domain}";
            policy = cfg.sso.authorization_policy;
            subject = [ "group:${cfg.ldap.userGroup}" ];
          }
        ];
      }
    ];

    services.prometheus.scrapeConfigs = [
      {
        job_name = "pinchflat";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString cfg.port}"];
            labels = {
              "hostname" = config.networking.hostName;
              "domain" = cfg.domain;
            };
          }
        ];
      }
    ];
  };
}
