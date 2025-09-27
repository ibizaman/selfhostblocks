{ config, lib, pkgs, ... }:
let
  cfg = config.shb.open-webui;

  contracts = pkgs.callPackage ../contracts {};
  shblib = pkgs.callPackage ../../lib {};
in
{
  options.shb.open-webui = {
    enable = lib.mkEnableOption "the Open-WebUI service";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which Open-WebUI will be served.";
      default = "open-webui";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which Open-WebUI will be served.";
      example = "mydomain.com";
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port Open-WebUI listens to incoming requests.";
      default = 12444;
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Extra environment variables. See https://docs.openwebui.com/getting-started/env-configuration";
      example = ''
      {
        WEBUI_NAME = "SelfHostBlocks";

        OLLAMA_BASE_URL = "http://127.0.0.1:''${toString config.services.ollama.port}";
        RAG_EMBEDDING_MODEL = "nomic-embed-text:v1.5";

        ENABLE_OPENAI_API = "True";
        OPENAI_API_BASE_URL = "http://127.0.0.1:''${toString config.services.llama-cpp.port}";
        ENABLE_WEB_SEARCH = "True";
        RAG_EMBEDDING_ENGINE = "openai";
      }
      '';
    };

    ldap = lib.mkOption {
      description = ''
        Setup LDAP integration.
      '';
      default = {};
      type = lib.types.submodule {
        options = {
          userGroup = lib.mkOption {
            type = lib.types.str;
            description = "Group users must belong to to be able to login.";
            default = "open-webui_user";
          };

          adminGroup = lib.mkOption {
            type = lib.types.str;
            description = "Group users must belong to to have administrator privileges.";
            default = "open-webui_admin";
          };
        };
      };
    };

    sso = lib.mkOption {
      description = ''
        Setup SSO integration.
      '';
      default = {};
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "SSO integration.";

          authEndpoint = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Endpoint to the SSO provider. Leave null to not have SSO configured.";
            example = "https://authelia.example.com";
          };

          clientID = lib.mkOption {
            type = lib.types.str;
            description = "Client ID for the OIDC endpoint.";
            default = "open-webui";
          };

          authorization_policy = lib.mkOption {
            type = lib.types.enum [ "one_factor" "two_factor" ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };

          sharedSecret = lib.mkOption {
            description = "OIDC shared secret for Open-WebUI.";
            type = lib.types.submodule {
              options = contracts.secret.mkRequester {
                owner = "open-webui";
                restartUnits = [ "open-webui.service" ];
              };
            };
          };

          sharedSecretForAuthelia = lib.mkOption {
            description = "OIDC shared secret for Authelia. Must be the same as `sharedSecret`";
            type = lib.types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0400";
                ownerText = "config.shb.authelia.autheliaUser";
                owner = config.shb.authelia.autheliaUser;
              };
            };
          };
        };
      };
    };

    backup = lib.mkOption {
      description = ''
        Backup state directory.
      '';
      default = {};
      type = lib.types.submodule {
        options = contracts.backup.mkRequester {
          user = "open-webui";
          sourceDirectories = [
            config.services.open-webui.stateDir
          ];
          sourceDirectoriesText = "[ config.services.open-webui.stateDir ]";
        };
      };
    };
  };

  config = (lib.mkMerge [
    (lib.mkIf cfg.enable {
      users.users.open-webui = {
        isSystemUser = true;
        group = "open-webui";
      };
      users.groups.open-webui = {};

      services.open-webui = {
        enable = true;

        host = "127.0.0.1";
        inherit (cfg) port;

        environment = {
          WEBUI_URL = "https://${cfg.subdomain}.${cfg.domain}";

          ENABLE_PERSISTENT_CONFIG = "False";

          ANONYMIZED_TELEMETRY = "False";
          DO_NOT_TRACK = "True";
          SCARF_NO_ANALYTICS = "True";

          ENABLE_VERSION_UPDATE_CHECK = "False";
        };
      };

      systemd.services.open-webui.path = [
        pkgs.ffmpeg-headless
      ];

      shb.nginx.vhosts = [
        {
          inherit (cfg) subdomain domain ssl;
          upstream = "http://127.0.0.1:${toString cfg.port}/";
          extraConfig = ''
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
          '';
        }
      ];
    })
    (lib.mkIf (cfg.enable && cfg.sso.enable) {
      shb.lldap.ensureGroups = {
        ${cfg.ldap.userGroup} = {};
        ${cfg.ldap.adminGroup} = {};
      };

      shb.authelia.oidcClients = [
        {
          client_id = cfg.sso.clientID;
          client_secret.source = cfg.sso.sharedSecretForAuthelia.result.path;
          scopes = [ "openid" "email" "profile" ];
          authorization_policy = cfg.sso.authorization_policy;
          redirect_uris = [
            "https://${cfg.subdomain}.${cfg.domain}/oauth/oidc/callback"
          ];
        }
      ];
      services.open-webui = {
        package = pkgs.open-webui.overrideAttrs (finalAttrs: {
          patches = [
            ../../patches/0001-selfhostblocks-never-onboard.patch
          ];
        });
        environment = {
          ENABLE_SIGNUP = "False";
          WEBUI_AUTH = "True";
          ENABLE_FORWARD_USER_INFO_HEADERS = "True";
          ENABLE_OAUTH_SIGNUP = "True";
          OAUTH_UPDATE_PICTURE_ON_LOGIN = "True";
          OAUTH_CLIENT_ID = cfg.sso.clientID;
          OPENID_PROVIDER_URL = "${cfg.sso.authEndpoint}/.well-known/openid-configuration";
          OAUTH_PROVIDER_NAME = "Single Sign-On";
          OAUTH_SCOPES = "openid email profile";
          OAUTH_ALLOWED_ROLES = cfg.ldap.userGroup;
          OAUTH_ADMIN_ROLES = cfg.ldap.adminGroup;
          ENABLE_OAUTH_ROLE_MANAGEMENT = "True";
        };
      };

      systemd.services.open-webui.serviceConfig.EnvironmentFile = "/run/open-webui/secrets.env";
      systemd.tmpfiles.rules = [
        "d '/run/open-webui' 0750 root root - -"
      ];
      systemd.services.open-webui-pre = {
        script = shblib.replaceSecrets {
          userConfig = {
            OAUTH_CLIENT_SECRET.source = cfg.sso.sharedSecret.result.path;
          };
          resultPath = "/run/open-webui/secrets.env";
          generator = shblib.toEnvVar;
        };
        serviceConfig.Type = "oneshot";
        wantedBy = [ "multi-user.target" ];
        before = [ "open-webui.service" ];
        requiredBy = [ "open-webui.service" ];
      };
    })
  ]);
}
