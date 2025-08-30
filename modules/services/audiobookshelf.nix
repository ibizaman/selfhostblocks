{ config, pkgs, lib, ... }:

let
  cfg = config.shb.audiobookshelf;

  contracts = pkgs.callPackage ../contracts {};

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  roleClaim = "audiobookshelf_groups";
in
{
  options.shb.audiobookshelf = {
    enable = lib.mkEnableOption "selfhostblocks.audiobookshelf";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which audiobookshelf will be served.";
      example = "abs";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which audiobookshelf will be served.";
      example = "mydomain.com";
    };

    webPort = lib.mkOption {
      type = lib.types.int;
      description = "Audiobookshelf web port";
      default = 8113;
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    extraServiceConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Extra configuration given to the systemd service file.";
      default = {};
      example = lib.literalExpression ''
      {
        MemoryHigh = "512M";
        MemoryMax = "900M";
      }
      '';
    };

    sso = lib.mkOption {
      description = "SSO configuration.";
      default = {};
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "SSO";

          provider = lib.mkOption {
            type = lib.types.str;
            description = "OIDC provider name";
            default = "Authelia";
          };

          endpoint = lib.mkOption {
            type = lib.types.str;
            description = "OIDC endpoint for SSO";
            example = "https://authelia.example.com";
          };

          clientID = lib.mkOption {
            type = lib.types.str;
            description = "Client ID for the OIDC endpoint";
            default = "audiobookshelf";
          };

          adminUserGroup = lib.mkOption {
            type = lib.types.str;
            description = "OIDC admin group";
            default = "audiobookshelf_admin";
          };

          userGroup = lib.mkOption {
            type = lib.types.str;
            description = "OIDC user group";
            default = "audiobookshelf_user";
          };

          authorization_policy = lib.mkOption {
            type = lib.types.enum [ "one_factor" "two_factor" ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };

          sharedSecret = lib.mkOption {
            description = "OIDC shared secret for Audiobookshelf.";
            type = lib.types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0440";
                owner = "audiobookshelf";
                group = "audiobookshelf";
                restartUnits = [ "audiobookshelfd.service" ];
              };
            };
          };

          sharedSecretForAuthelia = lib.mkOption {
            description = "OIDC shared secret for Authelia.";
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
        Backup configuration.
      '';
      type = lib.types.submodule {
        options = contracts.backup.mkRequester {
          user = "audiobookshelf";
          sourceDirectories = [
            "/var/lib/audiobookshelf"
          ];
        };
      };
    };

    logLevel = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["critical" "error" "warning" "info" "debug"]);
      description = "Enable logging.";
      default = false;
      example = true;
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [{

    services.audiobookshelf = {
      enable = true;
      openFirewall = true;
      dataDir = "audiobookshelf";
      host = "127.0.0.1";
      port = cfg.webPort;
    };

    services.nginx.enable = true;
    services.nginx.virtualHosts."${fqdn}" = {
      http2 = true;
      forceSSL = !(isNull cfg.ssl);
      sslCertificate = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.cert;
      sslCertificateKey = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.key;

      # https://github.com/advplyr/audiobookshelf#nginx-reverse-proxy
      extraConfig = ''
        set $audiobookshelf 127.0.0.1;
        location / {
             proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
             proxy_set_header  X-Forwarded-Proto $scheme;
             proxy_set_header  Host              $host;
             proxy_set_header Upgrade            $http_upgrade;
             proxy_set_header Connection         "upgrade";

             proxy_http_version                  1.1;

             proxy_pass                          http://$audiobookshelf:${builtins.toString cfg.webPort};
             proxy_redirect                      http:// https://;
           }
      '';
    };


    shb.authelia.extraDefinitions = {
      user_attributes.${roleClaim}.expression = 
          ''"${cfg.sso.adminUserGroup}" in groups ? ["admin"] : ("${cfg.sso.userGroup}" in groups ? ["user"] : [""])'';
    };

    shb.authelia.extraOidcClaimsPolicies.${roleClaim} = {
      custom_claims = {
        "${roleClaim}" = {};
      };
    };

    shb.authelia.extraOidcScopes."${roleClaim}" = {
      claims = [ "${roleClaim}" ];
    };

    shb.authelia.oidcClients = lib.lists.optionals cfg.sso.enable [
      {
        client_id = cfg.sso.clientID;
        client_name = "Audiobookshelf";
        client_secret.source = cfg.sso.sharedSecretForAuthelia.result.path;
        claims_policy = "${roleClaim}";
        public = false;
        authorization_policy = cfg.sso.authorization_policy;
        redirect_uris = [ 
          "https://${cfg.subdomain}.${cfg.domain}/auth/openid/callback" 
          "https://${cfg.subdomain}.${cfg.domain}/auth/openid/mobile-redirect" 
        ];
        scopes = [ "openid" "profile" "email" "groups" "${roleClaim}" ];
        require_pkce = true;
        pkce_challenge_method = "S256";
        userinfo_signed_response_alg = "none";
        token_endpoint_auth_method = "client_secret_basic";
      }
    ];
  } {
    systemd.services.audiobookshelfd.serviceConfig = cfg.extraServiceConfig;
  }]);
}
