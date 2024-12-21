{ config, options, pkgs, lib, ... }:

let
  cfg = config.shb.authelia;
  opt = options.shb.authelia;

  contracts = pkgs.callPackage ../contracts {};
  shblib = pkgs.callPackage ../../lib {};

  fqdn = "${cfg.subdomain}.${cfg.domain}";
  fqdnWithPort = if isNull cfg.port then fqdn else "${fqdn}:${toString cfg.port}";

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

    port = lib.mkOption {
      description = "If given, adds a port to the `<subdomain>.<domain>` endpoint.";
      type = lib.types.nullOr lib.types.port;
      default = null;
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    ldapHostname = lib.mkOption {
      type = lib.types.str;
      description = "Hostname of the LDAP authentication backend.";
      example = "ldap.example.com";
    };

    ldapPort = lib.mkOption {
      type = lib.types.port;
      description = "Port of the LDAP authentication backend.";
      example = "389";
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
          jwtSecret = lib.mkOption {
            description = "JWT secret.";
            type = lib.types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}" ];
              };
            };
          };
          ldapAdminPassword = lib.mkOption {
            description = "LDAP admin user password.";
            type = lib.types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}" ];
              };
            };
          };
          sessionSecret = lib.mkOption {
            description = "Session secret.";
            type = lib.types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}" ];
              };
            };
          };
          storageEncryptionKey = lib.mkOption {
            description = "Storage encryption key.";
            type = lib.types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}" ];
              };
            };
          };
          identityProvidersOIDCHMACSecret = lib.mkOption {
            description = "Identity provider OIDC HMAC secret.";
            type = lib.types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}" ];
              };
            };
          };
          identityProvidersOIDCIssuerPrivateKey = lib.mkOption {
            description = ''
              Identity provider OIDC issuer private key.

              Generate one with `nix run nixpkgs#openssl -- genrsa -out keypair.pem 2048`
            '';
            type = lib.types.submodule {
              options = contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}" ];
              };
            };
          };
        };
      };
    };

    oidcClients = lib.mkOption {
      description = "OIDC clients";
      default = [
        {
          client_id = "dummy_client";
          client_name = "Dummy Client so Authelia can start";
          client_secret.source = pkgs.writeText "dummy.secret" "dummy_client_secret";
          public = false;
          authorization_policy = "one_factor";
          redirect_uris = [];
        }
      ];
      type = lib.types.listOf (lib.types.submodule {
        freeformType = lib.types.attrsOf lib.types.anything;

        options = {
          client_id = lib.mkOption {
            type = lib.types.str;
            description = "Unique identifier of the OIDC client.";
          };

          client_name = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Human readable description of the OIDC client.";
            default = null;
          };

          client_secret = lib.mkOption {
            type = shblib.secretFileType;
            description = ''
            File containing the shared secret with the OIDC client.

            Generate with:

            ```
            nix run nixpkgs#authelia -- \
                crypto hash generate pbkdf2 \
                --variant sha512 \
                --random \
                --random.length 72 \
                --random.charset rfc3986
            ```
            '';
          };

          public = lib.mkOption {
            type = lib.types.bool;
            description = "If the OIDC client is public or not.";
            default = false;
            apply = v: if v then "true" else "false";
          };

          authorization_policy = lib.mkOption {
            type = lib.types.enum [ "one_factor" "two_factor" ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };

          redirect_uris = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "List of uris that are allowed to be redirected to.";
          };

          scopes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Scopes to ask for";
            example = [ "openid" "profile" "email" "groups" ];
            default = [];
          };
        };
      });
    };

    smtp = lib.mkOption {
      description = ''
        If a string is given, writes notifications to the given path.Otherwise, send notifications
        by smtp.

        https://www.authelia.com/configuration/notifications/introduction/
      '';
      default = "/tmp/authelia-notifications";
      type = lib.types.oneOf [
        lib.types.str
        (lib.types.nullOr (lib.types.submodule {
          options = {
            from_address = lib.mkOption {
              type = lib.types.str;
              description = "SMTP address from which the emails originate.";
              example = "authelia@mydomain.com";
            };
            from_name = lib.mkOption {
              type = lib.types.str;
              description = "SMTP name from which the emails originate.";
              default = "Authelia";
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
                options = contracts.secret.mkRequester {
                  mode = "0400";
                  owner = cfg.autheliaUser;
                  restartUnits = [ "authelia-${fqdn}" ];
                };
              };
            };
          };
        }))
      ];
    };

    rules = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      description = "Rule based clients";
      default = [];
    };

    mount = lib.mkOption {
      type = contracts.mount;
      description = ''
        Mount configuration. This is an output option.

        Use it to initialize a block implementing the "mount" contract.
        For example, with a zfs dataset:

        ```
        shb.zfs.datasets."authelia" = {
          poolName = "root";
        } // config.shb.authelia.mount;
        ```
      '';
      readOnly = true;
      default = { path = "/var/lib/authelia-authelia.${cfg.domain}"; };
      defaultText = { path = "/var/lib/authelia-authelia.example.com"; };
    };

    mountRedis = lib.mkOption {
      type = contracts.mount;
      description = ''
        Mount configuration for Redis. This is an output option.

        Use it to initialize a block implementing the "mount" contract.
        For example, with a zfs dataset:

        ```
        shb.zfs.datasets."redis-authelia" = {
          poolName = "root";
        } // config.shb.authelia.mountRedis;
        ```
      '';
      readOnly = true;
      default = { path = "/var/lib/redis-authelia"; };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.length cfg.oidcClients > 0;
        message = "Must have at least one oidc client otherwise Authelia refuses to start.";
      }
    ];

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
        jwtSecretFile = cfg.secrets.jwtSecret.result.path;
        storageEncryptionKeyFile = cfg.secrets.storageEncryptionKey.result.path;
      };
      # See https://www.authelia.com/configuration/methods/secrets/
      environmentVariables = {
        AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = toString cfg.secrets.ldapAdminPassword.result.path;
        AUTHELIA_SESSION_SECRET_FILE = toString cfg.secrets.sessionSecret.result.path;
        # Not needed since we use peer auth.
        # AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE = "/run/secrets/authelia/postgres_password";
        AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE = toString cfg.secrets.storageEncryptionKey.result.path;
        AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE = toString cfg.secrets.identityProvidersOIDCHMACSecret.result.path;
        AUTHELIA_IDENTITY_PROVIDERS_OIDC_ISSUER_PRIVATE_KEY_FILE = toString cfg.secrets.identityProvidersOIDCIssuerPrivateKey.result.path;

        AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = lib.mkIf (!(builtins.isString cfg.smtp)) (toString cfg.smtp.password.result.path);
      };
      settings = {
        server.address = "tcp://127.0.0.1:9091";

        # Inspired from https://github.com/lldap/lldap/blob/7d1f5abc137821c500de99c94f7579761fc949d8/example_configs/authelia_config.yml
        authentication_backend = {
          refresh_interval = "5m";
          password_reset = {
            disable = "false";
          };
          ldap = {
            implementation = "custom";
            address = "ldap://${cfg.ldapHostname}:${toString cfg.ldapPort}";
            timeout = "5s";
            start_tls = "false";
            base_dn = cfg.dcdomain;
            additional_users_dn = "ou=people";
            # Sign in with username or email.
            users_filter = "(&(|({username_attribute}={input})({mail_attribute}={input}))(objectClass=person))";
            additional_groups_dn = "ou=groups";
            groups_filter = "(member={dn})";
            user = "uid=admin,ou=people,${cfg.dcdomain}";
            attributes = {
              username = "uid";
              group_name = "cn";
              mail = "mail";
              display_name = "displayName";
            };
          };
        };
        totp = {
          disable = "false";
          issuer = fqdnWithPort;
          algorithm = "sha1";
          digits = "6";
          period = "30";
          skew = "1";
          secret_size = "32";
        };
        # Inspired from https://www.authelia.com/configuration/session/introduction/ and https://www.authelia.com/configuration/session/redis
        session = {
          name = "authelia_session";
          cookies = [{
            domain = if isNull cfg.port then cfg.domain else "${cfg.domain}:${toString cfg.port}";
            authelia_url = "https://${cfg.subdomain}.${cfg.domain}";
          }];
          same_site = "lax";
          expiration = "1h";
          inactivity = "5m";
          remember_me = "1M";
          redis = {
            host = config.services.redis.servers.authelia.unixSocket;
            port = 0;
          };
        };
        storage = {
          postgres = {
            address = "unix:///run/postgresql";
            username = autheliaCfg.user;
            database = autheliaCfg.user;
            # Uses peer auth for local users, so we don't need a password.
            password = "test";
          };
        };
        notifier = {
          filesystem = lib.mkIf (builtins.isString cfg.smtp) {
            filename = cfg.smtp;
          };
          smtp = lib.mkIf (!(builtins.isString cfg.smtp)) {
            host = cfg.smtp.host;
            port = cfg.smtp.port;
            username = cfg.smtp.username;
            sender = "${cfg.smtp.from_name} <${cfg.smtp.from_address}>";
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
              domain = fqdnWithPort;
              policy = "bypass";
              resources = [
                "^/api/.*"
              ];
            }
          ] ++ cfg.rules;
        };
        telemetry = {
          metrics = {
            enabled = true;
            address = "tcp://127.0.0.1:9959";
          };
        };
      };

      settingsFiles = [ "/var/lib/authelia-${fqdn}/oidc_clients.yaml" ];
    };

    systemd.services."authelia-${fqdn}".preStart =
      let
        mkCfg = clients:
          shblib.replaceSecrets {
            userConfig = {
              identity_providers.oidc.clients = clients;
            };
            resultPath = "/var/lib/authelia-${fqdn}/oidc_clients.yaml";
            generator = shblib.replaceSecretsGeneratorAdapter (lib.generators.toYAML {});
          };
      in
        lib.mkBefore (mkCfg cfg.oidcClients + ''
        ${pkgs.bash}/bin/bash -c '(while ! ${pkgs.netcat-openbsd}/bin/nc -z -v -w1 ${cfg.ldapHostname} ${toString cfg.ldapPort}; do echo "Waiting for port ${cfg.ldapHostname}:${toString cfg.ldapPort} to open..."; sleep 2; done); sleep 2'
          '');

    services.nginx.virtualHosts.${fqdn} = {
      forceSSL = !(isNull cfg.ssl);
      sslCertificate = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.cert;
      sslCertificateKey = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.key;
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

        proxy_pass http://127.0.0.1:9091;
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
        proxy_pass http://127.0.0.1:9091;
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
