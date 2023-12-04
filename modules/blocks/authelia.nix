{ config, pkgs, lib, ... }:

let
  cfg = config.shb.authelia;

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  autheliaCfg = config.services.authelia.instances.${fqdn};
in
{
  options.shb.authelia = {
    enable = lib.mkEnableOption "selfhostblocks.authelia";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which Authelia will be served.";
      example = "auth";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which Authelia will be served.";
      example = "mydomain.com";
    };

    ldapEndpoint = lib.mkOption {
      type = lib.types.str;
      description = "Endpoint for LDAP authentication backend.";
      example = "ldap.example.com";
    };

    dcdomain = lib.mkOption {
      type = lib.types.str;
      description = "dc domain for ldap.";
      example = "dc=mydomain,dc=com";
    };

    autheliaUser = lib.mkOption {
      type = lib.types.str;
      description = "System user for this Authelia instance.";
      default = "authelia";
    };

    secrets = lib.mkOption {
      description = "Secrets needed by Authelia";
      type = lib.types.submodule {
        options = {
          jwtSecretFile = lib.mkOption {
            type = lib.types.str;
            description = "File containing the JWT secret.";
          };
          ldapAdminPasswordFile = lib.mkOption {
            type = lib.types.str;
            description = "File containing the LDAP admin user password.";
          };
          sessionSecretFile = lib.mkOption {
            type = lib.types.str;
            description = "File containing the session secret.";
          };
          notifierSMTPPasswordFile = lib.mkOption {
            type = lib.types.str;
            description = "File containing the STMP password for the notifier.";
          };
          storageEncryptionKeyFile = lib.mkOption {
            type = lib.types.str;
            description = "File containing the storage encryption key.";
          };
          identityProvidersOIDCHMACSecretFile = lib.mkOption {
            type = lib.types.str;
            description = "File containing the identity provider OIDC HMAC secret.";
          };
          identityProvidersOIDCIssuerPrivateKeyFile = lib.mkOption {
            type = lib.types.str;
            description = "File containing the identity provider OIDC issuer private key.";
          };
        };
      };
    };

    oidcClients = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      description = "OIDC clients";
      default = [];
    };

    smtpHost = lib.mkOption {
      type = lib.types.str;
      description = "SMTP host.";
      example = "smtp.example.com";
    };

    smtpPort = lib.mkOption {
      type = lib.types.int;
      description = "SMTP port.";
      default = 587;
    };

    smtpUsername = lib.mkOption {
      type = lib.types.str;
      description = "SMTP username.";
      example = "postmaster@smtp.example.com";
    };

    rules = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      description = "Rule based clients";
      default = [];
    };
  };

  config = lib.mkIf cfg.enable {
    # Overriding the user name so we don't allow any weird characters anywhere. For example, postgres users do not accept the '.'.
    users = {
      groups.${autheliaCfg.user} = {};
      users.${autheliaCfg.user} = {
        isSystemUser = true;
        group = autheliaCfg.user;
      };
    };

    services.authelia.instances.${fqdn} = {
      enable = true;
      user = cfg.autheliaUser;

      secrets = {
        inherit (cfg.secrets) jwtSecretFile storageEncryptionKeyFile;
      };
      # See https://www.authelia.com/configuration/methods/secrets/
      environmentVariables = {
        AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = cfg.secrets.ldapAdminPasswordFile;
        AUTHELIA_SESSION_SECRET_FILE = cfg.secrets.sessionSecretFile;
        # Not needed since we use peer auth.
        # AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE = "/run/secrets/authelia/postgres_password";
        AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE = cfg.secrets.storageEncryptionKeyFile;
        AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = cfg.secrets.notifierSMTPPasswordFile;
        AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE = cfg.secrets.identityProvidersOIDCHMACSecretFile;
        AUTHELIA_IDENTITY_PROVIDERS_OIDC_ISSUER_PRIVATE_KEY_FILE = cfg.secrets.identityProvidersOIDCIssuerPrivateKeyFile;
      };
      settings = {
        server.host = "127.0.0.1";
        server.port = 9091;

        # Inspired from https://github.com/lldap/lldap/blob/7d1f5abc137821c500de99c94f7579761fc949d8/example_configs/authelia_config.yml
        authentication_backend = {
          refresh_interval = "5m";
          password_reset = {
            disable = "false";
          };
          ldap = {
            implementation = "custom";
            url = cfg.ldapEndpoint;
            timeout = "5s";
            start_tls = "false";
            base_dn = cfg.dcdomain;
            username_attribute = "uid";
            additional_users_dn = "ou=people";
            # Sign in with username or email.
            users_filter = "(&(|({username_attribute}={input})({mail_attribute}={input}))(objectClass=person))";
            additional_groups_dn = "ou=groups";
            groups_filter = "(member={dn})";
            group_name_attribute = "cn";
            mail_attribute = "mail";
            display_name_attribute = "displayName";
            user = "uid=admin,ou=people,${cfg.dcdomain}";
          };
        };
        totp = {
          disable = "false";
          issuer = fqdn;
          algorithm = "sha1";
          digits = "6";
          period = "30";
          skew = "1";
          secret_size = "32";
        };
        # Inspired from https://www.authelia.com/configuration/session/introduction/ and https://www.authelia.com/configuration/session/redis
        session = {
          name = "authelia_session";
          domain = cfg.domain;
          same_site = "lax";
          expiration = "1h";
          inactivity = "5m";
          remember_me_duration = "1M";
          redis = {
            host = config.services.redis.servers.authelia.unixSocket;
            port = 0;
          };
        };
        storage = {
          postgres = {
            host = "/run/postgresql";
            username = autheliaCfg.user;
            database = autheliaCfg.user;
            port = config.services.postgresql.port;
            # Uses peer auth for local users, so we don't need a password.
            password = "test";
          };
        };
        notifier = {
          smtp = {
            host = cfg.smtpHost;
            port = cfg.smtpPort;
            username = cfg.smtpUsername;
            sender = "Authelia <authelia@${cfg.domain}>";
            # identifier = "";
            subject = "[Authelia] {title}";
            startup_check_address = "test@authelia.com";
          };
        };
        access_control = {
          default_policy = "deny";
          networks = [
            {
              name = "internal";
              networks = [ "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/18" ];
            }
          ];
          rules = [
            {
              domain = fqdn;
              policy = "bypass";
              resources = [
                "^/api/.*"
              ];
            }
          ] ++ cfg.rules;
        };
        identity_providers.oidc.clients = cfg.oidcClients;
        telemetry = {
          metrics = {
            enabled = true;
            address = "tcp://127.0.0.1:9959";
          };
        };
      };
    };

    services.nginx.virtualHosts.${fqdn} = {
      sslCertificate = "/var/lib/acme/${cfg.domain}/cert.pem";
      sslCertificateKey = "/var/lib/acme/${cfg.domain}/key.pem";
      forceSSL = true;
      # Taken from https://github.com/authelia/authelia/issues/178
      # TODO: merge with config from https://matwick.ca/authelia-nginx-sso/
      locations."/".extraConfig = ''
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Content-Type-Options nosniff;
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Robots-Tag "noindex, nofollow, nosnippet, noarchive";
        add_header X-Download-Options noopen;
        add_header X-Permitted-Cross-Domain-Policies none;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_cache_bypass $http_upgrade;

        proxy_pass http://127.0.0.1:${toString autheliaCfg.settings.server.port};
        proxy_intercept_errors on;
        if ($request_method !~ ^(POST)$){
            error_page 401 = /error/401;
            error_page 403 = /error/403;
            error_page 404 = /error/404;
        }
        '';

      locations."/api/verify".extraConfig = ''
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Content-Type-Options nosniff;
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Robots-Tag "noindex, nofollow, nosnippet, noarchive";
        add_header X-Download-Options noopen;
        add_header X-Permitted-Cross-Domain-Policies none;

        proxy_set_header Host $http_x_forwarded_host;
        proxy_pass http://127.0.0.1:${toString autheliaCfg.settings.server.port};
        '';
    };

    services.redis.servers.authelia = {
      enable = true;
      user = autheliaCfg.user;
    };

    shb.postgresql.ensures = [
      {
        username = autheliaCfg.user;
        database = autheliaCfg.user;
      }
    ];

    services.prometheus.scrapeConfigs = [
      {
        job_name = "authelia";
        static_configs = [
          {
            targets = ["127.0.0.1:9959"];
          }
        ];
      }
    ];
  };
}
