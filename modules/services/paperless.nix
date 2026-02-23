{
  config,
  pkgs,
  lib,
  shb,
  ...
}:

let
  cfg = config.shb.paperless;
  dataFolder = cfg.dataDir;
  fqdn = "${cfg.subdomain}.${cfg.domain}";
  protocol = if !(isNull cfg.ssl) then "https" else "http";
  ssoFqdnWithPort =
    if isNull cfg.sso.port then cfg.sso.endpoint else "${cfg.sso.endpoint}:${toString cfg.sso.port}";

  ssoClientSettings = {
    openid_connect = {
      SCOPE = [
        "openid"
        "profile"
        "email"
        "groups"
      ];
      OAUTH_PKCE_ENABLED = true;
      APPS = [
        {
          provider_id = "${cfg.sso.provider}";
          name = "${cfg.sso.provider}";
          client_id = "${cfg.sso.clientID}";
          secret = "%SECRET_CLIENT_SECRET_PLACEHOLDER%";
          settings = {
            server_url = ssoFqdnWithPort;
            token_auth_method = "client_secret_basic";
          };
        }
      ];
    };
  };
  ssoClientSettingsFile = pkgs.writeText "paperless-sso-client.env" ''
    PAPERLESS_SOCIALACCOUNT_PROVIDERS=${builtins.toJSON ssoClientSettings}
  '';
  replacements = [
    {
      # Note: replaceSecretsScript prepends '%SECRET_' and appends '%'
      # when doing the replacement
      name = [ "CLIENT_SECRET_PLACEHOLDER" ];
      source = cfg.sso.sharedSecret.result.path;
    }
  ];
  replaceSecretsScript = shb.replaceSecretsScript {
    file = ssoClientSettingsFile;
    resultPath = "/run/paperless/paperless-sso-client.env";
    inherit replacements;
    user = "paperless";
  };
  inherit (lib)
    mkEnableOption
    mkIf
    lists
    mkOption
    ;
  inherit (lib.types)
    attrsOf
    bool
    enum
    listOf
    nullOr
    port
    submodule
    str
    path
    ;

in
{
  imports = [
    ../../lib/module.nix
    ../blocks/nginx.nix
  ];

  options.shb.paperless = {
    enable = mkEnableOption "selfhostblocks.paperless";

    subdomain = mkOption {
      type = str;
      description = ''
        Subdomain under which paperless will be served.

        ```
        <subdomain>.<domain>
        ```
      '';
      example = "photos";
    };

    domain = mkOption {
      description = ''
        Domain under which paperless is served.

        ```
        <subdomain>.<domain>
        ```
      '';
      type = str;
      example = "example.com";
    };

    port = mkOption {
      description = ''
        Port under which paperless will listen.
      '';
      type = port;
      default = 28981;
    };

    ssl = mkOption {
      description = "Path to SSL files";
      type = nullOr shb.contracts.ssl.certs;
      default = null;
    };

    dataDir = mkOption {
      description = "Directory where paperless will store data files.";
      type = str;
      default = "/var/lib/paperless";
    };

    mediaDir = mkOption {
      description = "Directory where paperless will store documents.";
      type = str;
      defaultText = lib.literalExpression ''"''${dataDir}/media"'';
      default = "${cfg.dataDir}/media";
    };

    consumptionDir = mkOption {
      description = "Directory from which new documents are imported.";
      type = str;
      defaultText = lib.literalExpression ''"''${dataDir}/consume"'';
      default = "${cfg.dataDir}/consume";
    };

    configureTika = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to configure Tika and Gotenberg to process Office and e-mail files with OCR.
      '';
    };

    adminPassword = mkOption {
      description = "Secret containing the superuser (admin) password.";
      type = submodule {
        options = shb.contracts.secret.mkRequester {
          mode = "0400";
          owner = "paperless";
          group = "paperless";
          restartUnits = [ "paperless-server.service" ];
        };
      };
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType =
          with lib.types;
          attrsOf (
            let
              typeList = [
                bool
                float
                int
                str
                path
                package
              ];
            in
            oneOf (
              typeList
              ++ [
                (listOf (oneOf typeList))
                (attrsOf (oneOf typeList))
              ]
            )
          );
      };
      default = { };
      description = ''
        Extra paperless config options.

        See [the documentation](https://docs.paperless-ngx.com/configuration/) for available options.

        Note that some settings such as `PAPERLESS_CONSUMER_IGNORE_PATTERN` expect JSON values.
        Settings declared as lists or attrsets will automatically be serialised into JSON strings for your convenience.
      '';
      example = {
        PAPERLESS_OCR_LANGUAGE = "deu+eng";
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          "desktop.ini"
        ];
        PAPERLESS_OCR_USER_ARGS = {
          optimize = 1;
          pdfa_image_compression = "lossless";
        };
      };
    };

    mount = mkOption {
      type = shb.contracts.mount;
      description = ''
        Mount configuration. This is an output option.

        Use it to initialize a block implementing the "mount" contract.
        For example, with a zfs dataset:

        ```
        shb.zfs.datasets."paperless" = {
          poolName = "root";
        } // config.shb.paperless.mount;
        ```
      '';
      readOnly = true;
      default = {
        path = dataFolder;
      };
    };

    backup = mkOption {
      description = ''
        Backup configuration for paperless media files and database.
      '';
      default = { };
      type = submodule {
        options = shb.contracts.backup.mkRequester {
          user = "paperless";
          sourceDirectories = [
            dataFolder
          ];
          excludePatterns = [
          ];
        };
      };
    };

    sso = mkOption {
      description = ''
        Setup SSO integration.
      '';
      default = { };
      type = submodule {
        options = {
          enable = mkEnableOption "SSO integration.";

          provider = mkOption {
            type = enum [
              "Authelia"
              "Keycloak"
              "Generic"
            ];
            description = "OIDC provider name, used for display.";
            default = "Authelia";
          };

          endpoint = mkOption {
            type = str;
            description = "OIDC endpoint for SSO.";
            example = "https://authelia.example.com";
          };

          clientID = mkOption {
            type = str;
            description = "Client ID for the OIDC endpoint.";
            default = "paperless";
          };

          adminUserGroup = lib.mkOption {
            type = lib.types.str;
            description = "OIDC admin group";
            default = "paperless_admin";
          };

          userGroup = lib.mkOption {
            type = lib.types.str;
            description = "OIDC user group";
            default = "paperless_user";
          };

          port = mkOption {
            description = "If given, adds a port to the endpoint.";
            type = nullOr port;
            default = null;
          };

          autoRegister = mkOption {
            type = bool;
            description = "Automatically register new users from SSO provider.";
            default = true;
          };

          autoLaunch = mkOption {
            type = bool;
            description = "Automatically redirect to SSO provider.";
            default = true;
          };

          passwordLogin = mkOption {
            type = bool;
            description = "Enable password login.";
            default = true;
          };

          sharedSecret = mkOption {
            description = "OIDC shared secret for paperless.";
            type = submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = "paperless";
                group = "paperless";
                restartUnits = [ "paperless-server.service" ];
              };
            };
          };

          sharedSecretForAuthelia = mkOption {
            description = "OIDC shared secret for Authelia. Content must be the same as `sharedSecret` option.";
            type = submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = "authelia";
              };
            };
            default = null;
          };

          authorization_policy = mkOption {
            type = enum [
              "one_factor"
              "two_factor"
            ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };
        };
      };
    };

    dashboard = lib.mkOption {
      description = ''
        Dashboard contract consumer
      '';
      default = { };
      type = lib.types.submodule {
        options = shb.contracts.dashboard.mkRequester {
          externalUrl = "https://${cfg.subdomain}.${cfg.domain}";
          externalUrlText = "https://\${config.shb.paperless.subdomain}.\${config.shb.paperless.domain}";
          internalUrl = "http://127.0.0.1:${toString cfg.port}";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(isNull cfg.ssl) -> !(isNull cfg.ssl.paths.cert) && !(isNull cfg.ssl.paths.key);
        message = "SSL is enabled for paperless but no cert or key is provided.";
      }
      {
        assertion = cfg.sso.enable -> cfg.ssl != null;
        message = "To integrate SSO, SSL must be enabled, set the shb.paperless.ssl option.";
      }
    ];

    # Configure paperless service
    services.paperless = {
      enable = true;
      address = "127.0.0.1";
      port = cfg.port;
      consumptionDirIsPublic = true;
      dataDir = cfg.dataDir;
      mediaDir = cfg.mediaDir;
      consumptionDir = cfg.consumptionDir;
      configureTika = cfg.configureTika;
      settings = {
        PAPERLESS_URL = "${protocol}://${fqdn}";
      }
      // cfg.settings
      // lib.optionalAttrs (cfg.sso.enable) {
        PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
        PAPERLESS_SOCIAL_AUTO_SIGNUP = cfg.sso.autoRegister;
        PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS = true;
        PAPERLESS_DISABLE_REGULAR_LOGIN = !cfg.sso.passwordLogin;
      };
    }
    // lib.optionalAttrs (cfg.sso.enable) {
      environmentFile = "/run/paperless/paperless-sso-client.env";
    };

    # Database defaults to local sqlite

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 paperless paperless"
      "d ${cfg.consumptionDir} 0700 paperless paperless"
      "d ${cfg.mediaDir} 0700 paperless paperless"
    ]
    ++ lib.optionals cfg.sso.enable [ "d '/run/paperless' 0750 root root - -" ];

    systemd.services.paperless-pre = lib.mkIf cfg.sso.enable {
      script = replaceSecretsScript;
      serviceConfig.Type = "oneshot";
      wantedBy = [ "multi-user.target" ];
      before = [ "paperless-scheduler.service" ];
      requiredBy = [ "paperless-scheduler.service" ];
    };

    shb.nginx.vhosts = [
      {
        inherit (cfg) subdomain domain ssl;
        upstream = "http://127.0.0.1:${toString cfg.port}";
        autheliaRules = lib.mkIf (cfg.sso.enable) [
          {
            domain = fqdn;
            policy = cfg.sso.authorization_policy;
            subject = [
              "group:paperless_user"
              "group:paperless_admin"
            ];
          }
        ];
        authEndpoint = lib.mkIf (cfg.sso.enable) cfg.sso.endpoint;
        extraConfig = ''
          # See https://github.com/paperless-ngx/paperless-ngx/wiki/Using-a-Reverse-Proxy-with-Paperless-ngx#nginx
          proxy_redirect off;
          proxy_set_header X-Forwarded-Host $server_name;
          add_header Referrer-Policy "strict-origin-when-cross-origin";
        '';
      }
    ];

    # Allow large uploads
    services.nginx.virtualHosts."${fqdn}".extraConfig = ''
      client_max_body_size 500M;
    '';

    shb.authelia.oidcClients = lists.optionals (cfg.sso.enable && cfg.sso.provider == "Authelia") [
      {
        client_id = cfg.sso.clientID;
        client_name = "paperless";
        client_secret.source = cfg.sso.sharedSecretForAuthelia.result.path;
        public = false;
        authorization_policy = cfg.sso.authorization_policy;
        token_endpoint_auth_method = "client_secret_basic";
        redirect_uris = [
          "${protocol}://${fqdn}/accounts/oidc/${cfg.sso.provider}/login/callback/"
        ];
      }
    ];
  };
}
