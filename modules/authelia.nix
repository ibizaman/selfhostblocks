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
      example = "ha";
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

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file location.";
      example = "secrets/authelia.yaml";
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
    sops.secrets =
      let
        names = [
          "jwt_secret"
          "ldap_admin_password"
          "session_secret"
          "smtp_password"
          "storage_encryption_key"
          "hmac_secret"
          "private_key"
        ];

        mkSecret = name:
          lib.attrsets.nameValuePair "authelia/${name}" {
            inherit (cfg) sopsFile;
            mode = "0400";
            owner = autheliaCfg.user;
            group = autheliaCfg.group;
          };
      in
        builtins.listToAttrs (map mkSecret names);

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
      user = "authelia_" + builtins.replaceStrings ["-" "."] ["_" "_"] fqdn;

      secrets = {
        jwtSecretFile = "/run/secrets/authelia/jwt_secret";
        storageEncryptionKeyFile = "/run/secrets/authelia/storage_encryption_key";
      };
      # See https://www.authelia.com/configuration/methods/secrets/
      environmentVariables = {
        AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = "/run/secrets/authelia/ldap_admin_password";
        AUTHELIA_SESSION_SECRET_FILE = "/run/secrets/authelia/session_secret";
        # Not needed since we use peer auth.
        # AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE = "/run/secrets/authelia/postgres_password";
        AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE = "/run/secrets/authelia/storage_encryption_key";
        AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = "/run/secrets/authelia/smtp_password";
        AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE = "/run/secrets/authelia/hmac_secret";
        AUTHELIA_IDENTITY_PROVIDERS_OIDC_ISSUER_PRIVATE_KEY_FILE = "/run/secrets/authelia/private_key";
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
      locations."/" = {
        # Taken from https://matwick.ca/authelia-nginx-sso/
        extraConfig = ''
          # Basic Proxy Config
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $http_host;
          proxy_set_header X-Forwarded-Uri $request_uri;
          proxy_set_header X-Forwarded-Ssl on;
          proxy_set_header Connection "";
          proxy_redirect http:// $scheme://;
          proxy_http_version 1.1;
          proxy_cache_bypass $cookie_session;
          proxy_no_cache $cookie_session;
          proxy_buffers 64 256k;

          # If behind reverse proxy, forwards the correct IP
          set_real_ip_from 10.0.0.0/8;
          set_real_ip_from 172.0.0.0/8;
          set_real_ip_from 192.168.0.0/16;
          set_real_ip_from fc00::/7;
          real_ip_header X-Forwarded-For;
          real_ip_recursive on;
          '';
        proxyPass =
          let
            autheliaServerCfg = autheliaCfg.settings.server;
          in
            "http://${toString autheliaServerCfg.host}:${toString autheliaServerCfg.port}/";
      };
    };

    services.redis.servers.authelia = {
      enable = true;
      user = autheliaCfg.user;
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ autheliaCfg.user ];
      ensureUsers = [
        {
          name = autheliaCfg.user;
          ensurePermissions = {
            "DATABASE ${autheliaCfg.user}" = "ALL PRIVILEGES";
          };
          ensureClauses = {
            "login" = true;
          };
        }
      ];
    };

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
