{
  config,
  options,
  pkgs,
  lib,
  shb,
  ...
}:

let
  cfg = config.shb.authelia;
  opt = options.shb.authelia;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
  fqdnWithPort = if isNull cfg.port then fqdn else "${fqdn}:${toString cfg.port}";

  autheliaCfg = config.services.authelia.instances.${fqdn};

  inherit (lib) hasPrefix;

  listenPort = if cfg.debug then 9090 else 9091;
in
{
  imports = [
    ../../lib/module.nix
    ./lldap.nix
    ./mitmdump.nix
    ./postgresql.nix
  ];

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
      type = lib.types.nullOr shb.contracts.ssl.certs;
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
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}.service" ];
              };
            };
          };
          ldapAdminPassword = lib.mkOption {
            description = "LDAP admin user password.";
            type = lib.types.submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}.service" ];
              };
            };
          };
          sessionSecret = lib.mkOption {
            description = "Session secret.";
            type = lib.types.submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}.service" ];
              };
            };
          };
          storageEncryptionKey = lib.mkOption {
            description = "Storage encryption key.";
            type = lib.types.submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}.service" ];
              };
            };
          };
          identityProvidersOIDCHMACSecret = lib.mkOption {
            description = "Identity provider OIDC HMAC secret.";
            type = lib.types.submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}.service" ];
              };
            };
          };
          identityProvidersOIDCIssuerPrivateKey = lib.mkOption {
            description = ''
              Identity provider OIDC issuer private key.

              Generate one with `nix run nixpkgs#openssl -- genrsa -out keypair.pem 2048`
            '';
            type = lib.types.submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = cfg.autheliaUser;
                restartUnits = [ "authelia-${opt.subdomain}.${opt.domain}.service" ];
              };
            };
          };
        };
      };
    };

    extraOidcClaimsPolicies = lib.mkOption {
      description = "Extra OIDC claims policies.";
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
    };

    extraOidcScopes = lib.mkOption {
      description = "Extra OIDC scopes.";
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
    };

    extraOidcAuthorizationPolicies = lib.mkOption {
      description = "Extra OIDC authorization policies.";
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
    };

    extraDefinitions = lib.mkOption {
      description = "Extra definitions.";
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
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
          redirect_uris = [ ];
        }
      ];
      type = lib.types.listOf (
        lib.types.submodule {
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
              type = shb.secretFileType;
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
              type = lib.types.enum (
                [
                  "one_factor"
                  "two_factor"
                ]
                ++ lib.attrNames cfg.extraOidcAuthorizationPolicies
              );
              description = "Require one factor (password) or two factor (device) authentication.";
              default = "one_factor";
            };

            redirect_uris = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "List of uris that are allowed to be redirected to.";
            };

            scopes = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Scopes to ask for. See https://www.authelia.com/integration/openid-connect/openid-connect-1.0-claims";
              example = [
                "openid"
                "profile"
                "email"
                "groups"
              ];
              default = [ ];
            };

            claims_policy = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              description = ''
                Claim policy.

                Defaults to 'default' to provide a backwards compatible experience.
                Read [this document](https://www.authelia.com/integration/openid-connect/openid-connect-1.0-claims/#restore-functionality-prior-to-claims-parameter) for more information.
              '';
              default = "default";
            };
          };
        }
      );
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
        (lib.types.nullOr (
          lib.types.submodule {
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
              scheme = lib.mkOption {
                description = "The protocl must be smtp, submission, or submissions. The only difference between these schemes are the default ports and submissions requires a TLS transport per SMTP Ports Security Measures, whereas submission and smtp use a standard TCP transport and typically enforce StartTLS.";
                type = lib.types.enum [
                  "smtp"
                  "submission"
                  "submissions"
                ];
                default = "smtp";
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
                    owner = cfg.autheliaUser;
                    restartUnits = [ "authelia-${fqdn}.service" ];
                  };
                };
              };
            };
          }
        ))
      ];
    };

    rules = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      description = "Rule based clients";
      default = [ ];
    };

    mount = lib.mkOption {
      type = shb.contracts.mount;
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
      default = {
        path = "/var/lib/authelia-authelia.${cfg.domain}";
      };
      defaultText = {
        path = "/var/lib/authelia-authelia.example.com";
      };
    };

    mountRedis = lib.mkOption {
      type = shb.contracts.mount;
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
      default = {
        path = "/var/lib/redis-authelia";
      };
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Set logging level to debug and add a mitmdump instance
        to see exactly what Authelia receives and sends back.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.length cfg.oidcClients > 0;
        message = "Must have at least one oidc client otherwise Authelia refuses to start.";
      }
      {
        assertion = !(hasPrefix "ldap://" cfg.ldapHostname);
        message = "LDAP hostname should be the bare host name and not start with ldap://";
      }
    ];

    # Overriding the user name so we don't allow any weird characters anywhere. For example, postgres users do not accept the '.'.
    users = {
      groups.${autheliaCfg.user} = { };
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
        sessionSecretFile = cfg.secrets.sessionSecret.result.path;
        oidcIssuerPrivateKeyFile = cfg.secrets.identityProvidersOIDCIssuerPrivateKey.result.path;
        oidcHmacSecretFile = cfg.secrets.identityProvidersOIDCHMACSecret.result.path;
      };
      # See https://www.authelia.com/configuration/methods/secrets/
      environmentVariables = {
        AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = toString cfg.secrets.ldapAdminPassword.result.path;
        # Not needed since we use peer auth.
        # AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE = "/run/secrets/authelia/postgres_password";
        AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = lib.mkIf (!(builtins.isString cfg.smtp)) (
          toString cfg.smtp.password.result.path
        );
        X_AUTHELIA_CONFIG_FILTERS = "template";
      };
      settings = {
        server.address = "tcp://127.0.0.1:${toString listenPort}";

        # Inspired from https://github.com/lldap/lldap/blob/7d1f5abc137821c500de99c94f7579761fc949d8/example_configs/authelia_config.yml
        authentication_backend = {
          refresh_interval = "5m";
          # We allow password reset and change because the ldap user we use allows it.
          password_reset.disable = "false";
          password_change.disable = "false";
          ldap = {
            implementation = "lldap";
            address = "ldap://${cfg.ldapHostname}:${toString cfg.ldapPort}";
            timeout = "5s";
            start_tls = "false";
            base_dn = cfg.dcdomain;
            # TODO: use user with less privilege and with lldap_password_manager group to be able to change passwords.
            user = "uid=admin,ou=people,${cfg.dcdomain}";
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
          cookies = [
            {
              domain = if isNull cfg.port then cfg.domain else "${cfg.domain}:${toString cfg.port}";
              authelia_url = "https://${cfg.subdomain}.${cfg.domain}";
            }
          ];
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
            address = "${cfg.smtp.scheme}://${cfg.smtp.host}:${toString cfg.smtp.port}";
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
              networks = [
                "10.0.0.0/8"
                "172.16.0.0/12"
                "192.168.0.0/18"
              ];
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
          ]
          ++ cfg.rules;
        };
        telemetry = {
          metrics = {
            enabled = true;
            address = "tcp://127.0.0.1:9959";
          };
        };

        log.level = if cfg.debug then "debug" else "info";
      }
      // {
        identity_providers.oidc = {
          claims_policies = {
            # This default claim should go away at some point.
            # https://www.authelia.com/integration/openid-connect/openid-connect-1.0-claims/#restore-functionality-prior-to-claims-parameter
            default.id_token = [
              "email"
              "preferred_username"
              "name"
              "groups"
            ];
          }
          // cfg.extraOidcClaimsPolicies;
          scopes = cfg.extraOidcScopes;
          authorization_policies = cfg.extraOidcAuthorizationPolicies;
        };
      }
      // lib.optionalAttrs (cfg.extraDefinitions != { }) {
        definitions = cfg.extraDefinitions;
      };

      settingsFiles = [ "/var/lib/authelia-${fqdn}/oidc_clients.yaml" ];
    };

    systemd.services."authelia-${fqdn}".preStart =
      let
        mkCfg =
          clients:
          shb.replaceSecrets {
            userConfig = {
              identity_providers.oidc.clients = clients;
            };
            resultPath = "/var/lib/authelia-${fqdn}/oidc_clients.yaml";
            generator = shb.replaceSecretsGeneratorAdapter (lib.generators.toYAML { });
          };
      in
      lib.mkBefore (
        mkCfg cfg.oidcClients
        + ''
          ${pkgs.bash}/bin/bash -c '(while ! ${pkgs.netcat-openbsd}/bin/nc -z -v -w1 ${cfg.ldapHostname} ${toString cfg.ldapPort}; do echo "Waiting for port ${cfg.ldapHostname}:${toString cfg.ldapPort} to open..."; sleep 2; done); sleep 2'
        ''
      );

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
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-Uri $request_uri;
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

    # I would like this to live outside of the Authelia module.
    # This will require a reverse proxy contract.
    # Actually, not sure a full reverse proxy contract is needed.
    shb.mitmdump.instances."authelia-${fqdn}" = lib.mkIf cfg.debug {
      listenPort = 9091;
      upstreamPort = 9090;
      after = [ "authelia-${fqdn}.service" ];
      enabledAddons = [ config.shb.mitmdump.addons.logger ];
      extraArgs = [
        "--set"
        "verbose_pattern=/api"
      ];
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
            targets = [ "127.0.0.1:9959" ];
            labels = {
              "hostname" = config.networking.hostName;
              "domain" = cfg.domain;
            };
          }
        ];
      }
    ];

    systemd.targets."authelia-${fqdn}" =
      let
        services = [
          "authelia-${fqdn}.service"
        ]
        ++ lib.optionals cfg.debug [
          config.shb.mitmdump.instances."authelia-${fqdn}".serviceName
        ];
      in
      {
        after = services;
        requires = services;

        wantedBy = [ "multi-user.target" ];
      };
  };
}
