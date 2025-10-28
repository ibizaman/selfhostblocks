{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.shb.karakeep;

  contracts = pkgs.callPackage ../contracts { };
in
{
  imports = [
    ../blocks/nginx.nix
  ];

  options.shb.karakeep = {
    enable = lib.mkEnableOption "the Karakeep service";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which Karakeep will be served.";
      default = "karakeep";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which Karakeep will be served.";
      example = "mydomain.com";
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port Karakeep listens to incoming requests.";
      default = 3000;
    };

    environment = lib.mkOption {
      default = { };
      type = lib.types.attrsOf lib.types.str;
      description = "Extra environment variables. See https://docs.karakeep.app/configuration/";
      example = ''
        {
          OLLAMA_BASE_URL = "http://127.0.0.1:''${toString config.services.ollama.port}";
          INFERENCE_TEXT_MODEL = "deepseek-r1:1.5b";
          INFERENCE_IMAGE_MODEL = "llava";
          EMBEDDING_TEXT_MODEL = "nomic-embed-text:v1.5";
          INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";
          INFERENCE_JOB_TIMEOUT_SEC = "200";
        }
      '';
    };

    ldap = lib.mkOption {
      description = ''
        Setup LDAP integration.
      '';
      default = { };
      type = lib.types.submodule {
        options = {
          userGroup = lib.mkOption {
            type = lib.types.str;
            description = "Group users must belong to to be able to login.";
            default = "karakeep_user";
          };
        };
      };
    };

    sso = lib.mkOption {
      description = ''
        Setup SSO integration.
      '';
      default = { };
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
            default = "karakeep";
          };

          authorization_policy = lib.mkOption {
            type = lib.types.enum [
              "one_factor"
              "two_factor"
            ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };

          sharedSecret = lib.mkOption {
            description = "OIDC shared secret for Karakeep.";
            type = lib.types.submodule {
              options = contracts.secret.mkRequester {
                owner = "karakeep";
                # These services are the ones relying on the environment file containing the secrets.
                restartUnits = [
                  "karakeep-init.service"
                  "karakeep-workers.service"
                  "karakeep-workers.service"
                ];
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
      default = { };
      type = lib.types.submodule {
        options = contracts.backup.mkRequester {
          user = "karakeep";
          sourceDirectories = [
            "/var/lib/karakeep"
          ];
        };
      };
    };

    nextauthSecret = lib.mkOption {
      description = "NextAuth secret.";
      type = lib.types.submodule {
        options = contracts.secret.mkRequester {
          owner = "karakeep";
          # These services are the ones relying on the environment file containing the secrets.
          restartUnits = [
            "karakeep-init.service"
            "karakeep-workers.service"
            "karakeep-workers.service"
          ];
        };
      };
    };

    meilisearchMasterKey = lib.mkOption {
      description = "Master key used to secure communication with Meilisearch.";
      type = lib.types.submodule {
        options = contracts.secret.mkRequester {
          owner = "karakeep";
          # These services are the ones relying on the environment file containing the secrets.
          restartUnits = [
            "karakeep-init.service"
            "karakeep-workers.service"
            "karakeep-workers.service"
          ];
        };
      };
    };
  };

  config = (
    lib.mkMerge [
      (lib.mkIf cfg.enable {
        services.karakeep = {
          enable = true;
          meilisearch.enable = true;

          extraEnvironment = {
            PORT = toString cfg.port;
            DISABLE_NEW_RELEASE_CHECK = "true"; # These are handled by NixOS
          }
          // cfg.environment;
        };

        shb.nginx.vhosts = [
          {
            inherit (cfg) subdomain domain ssl;
            upstream = "http://127.0.0.1:${toString cfg.port}/";
          }
        ];

        # Piggybacking onto the upstream karakeep-init and replacing its script by ours.
        # This is needed otherwise the MEILI_MASTER_KEY is generated randomly on first start
        # instead of using the value from the cfg.meilisearchMasterKey option.
        systemd.services.karakeep-init = {
          script = lib.mkForce (
            (lib.shb.replaceSecrets {
              userConfig = {
                MEILI_MASTER_KEY.source = cfg.meilisearchMasterKey.result.path;
                NEXTAUTH_SECRET.source = cfg.nextauthSecret.result.path;
              }
              // lib.optionalAttrs cfg.sso.enable {
                OAUTH_CLIENT_SECRET.source = cfg.sso.sharedSecret.result.path;
              };
              resultPath = "/var/lib/karakeep/settings.env";
              generator = lib.shb.toEnvVar;
            })
            + ''
              export DATA_DIR="$STATE_DIRECTORY"
              exec ${config.services.karakeep.package}/lib/karakeep/migrate
            ''
          );
        };
      })
      (lib.mkIf cfg.enable {
        services.meilisearch = {
          dumplessUpgrade = true;
          environment = "production";
          masterKeyFile = cfg.meilisearchMasterKey.result.path;
        };
      })
      (lib.mkIf (cfg.enable && cfg.sso.enable) {
        shb.lldap.ensureGroups = {
          ${cfg.ldap.userGroup} = { };
        };

        shb.authelia.extraOidcAuthorizationPolicies.karakeep = {
          default_policy = "deny";
          rules = [
            {
              subject = [ "group:${cfg.ldap.userGroup}" ];
              policy = cfg.sso.authorization_policy;
            }
          ];
        };
        shb.authelia.oidcClients = [
          {
            client_id = cfg.sso.clientID;
            client_secret.source = cfg.sso.sharedSecretForAuthelia.result.path;
            scopes = [
              "openid"
              "email"
              "profile"
            ];
            authorization_policy = "karakeep";
            redirect_uris = [
              "https://${cfg.subdomain}.${cfg.domain}/api/auth/callback/custom"
            ];
          }
        ];
        services.karakeep = {
          extraEnvironment = {
            DISABLE_SIGNUPS = "false";
            DISABLE_PASSWORD_AUTH = "true";
            NEXTAUTH_URL = "https://${cfg.subdomain}.${cfg.domain}";
            OAUTH_WELLKNOWN_URL = "${cfg.sso.authEndpoint}/.well-known/openid-configuration";
            OAUTH_PROVIDER_NAME = "Single Sign-On";
            OAUTH_CLIENT_ID = cfg.sso.clientID;
            OAUTH_SCOPE = "openid email profile";
          };
        };
      })
    ]
  );
}
