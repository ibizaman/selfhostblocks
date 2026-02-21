{
  config,
  pkgs,
  lib,
  shb,
  ...
}:

let
  cfg = config.shb.immich;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
  protocol = if !(isNull cfg.ssl) then "https" else "http";

  roleClaim = "immich_user";

  # TODO: Quota management, see https://github.com/ibizaman/selfhostblocks/pull/523#discussion_r2309421694
  #quotaClaim = "immich_quota";
  scopes = [
    "openid"
    "email"
    "profile"
    "groups"
    "immich_scope"
  ];

  dataFolder = cfg.mediaLocation;
  ssoFqdnWithPort =
    if isNull cfg.sso.port then cfg.sso.endpoint else "${cfg.sso.endpoint}:${toString cfg.sso.port}";
  # Generate Immich configuration file only for SHB-managed settings
  shbManagedSettings =
    lib.optionalAttrs (cfg.settings != { }) cfg.settings
    // lib.optionalAttrs (cfg.sso.enable) {
      oauth = {
        enabled = true;
        issuerUrl = "${ssoFqdnWithPort}";
        clientId = cfg.sso.clientID;
        roleClaim = roleClaim;
        clientSecret = {
          source = cfg.sso.sharedSecret.result.path;
        };
        scope = builtins.concatStringsSep " " scopes;
        storageLabelClaim = cfg.sso.storageLabelClaim;
        #storageQuotaClaim = quotaClaim; # TODO (commented out, otherwise defaults to 0 bytes!)
        defaultStorageQuota = 0;
        buttonText = cfg.sso.buttonText;
        autoRegister = cfg.sso.autoRegister;
        autoLaunch = cfg.sso.autoLaunch;
        passwordLogin = cfg.sso.passwordLogin;
        mobileOverrideEnabled = false;
        mobileRedirectUri = "";
      };
    }
    // lib.optionalAttrs (cfg.smtp != null) {
      notifications = {
        smtp = {
          enabled = true;
          from = cfg.smtp.from;
          replyTo = cfg.smtp.replyTo;
          transport = {
            host = cfg.smtp.host;
            port = cfg.smtp.port;
            username = cfg.smtp.username;
            password = {
              source = cfg.smtp.password.result.path;
            };
            ignoreTLS = cfg.smtp.ignoreTLS;
            secure = cfg.smtp.secure;
          };
        };
      };
    };

  configFile = "/var/lib/immich/config.json";

  # Use SHB's replaceSecrets function for loading secrets at runtime
  configSetupScript = lib.optionalString (cfg.sso.enable || cfg.smtp != null) (
    shb.replaceSecrets {
      userConfig = shbManagedSettings;
      resultPath = configFile;
      generator = shb.replaceSecretsFormatAdapter (pkgs.formats.json { });
      user = "immich";
      permissions = "u=r,g=,o=";
    }
  );
  inherit (lib)
    mkEnableOption
    mkIf
    lists
    mkOption
    optionals
    ;
  inherit (lib.types)
    attrs
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

  options.shb.immich = {
    enable = mkEnableOption "selfhostblocks.immich";

    subdomain = mkOption {
      type = str;
      description = ''
        Subdomain under which Immich will be served.

        ```
        <subdomain>.<domain>
        ```
      '';
      example = "photos";
    };

    domain = mkOption {
      description = ''
        Domain under which Immich is served.

        ```
        <subdomain>.<domain>
        ```
      '';
      type = str;
      example = "example.com";
    };

    port = mkOption {
      description = ''
        Port under which Immich will listen.
      '';
      type = port;
      default = 2283;
    };

    publicProxyEnable = mkOption {
      description = ''
        Enable Immich Public Proxy service for sharing media publically.
      '';
      type = bool;
      default = false;
    };

    publicProxyPort = mkOption {
      description = ''
        Port under which Immich Public Proxy will listen.
      '';
      type = port;
      default = 2284;
    };

    ssl = mkOption {
      description = "Path to SSL files";
      type = nullOr shb.contracts.ssl.certs;
      default = null;
    };

    mediaLocation = mkOption {
      description = "Directory where Immich will store media files.";
      type = str;
      default = "/var/lib/immich";
    };

    jwtSecretFile = mkOption {
      description = ''
        File containing Immich's JWT secret key for sessions.
        This is required for secure session management.
      '';
      type = nullOr (submodule {
        options = shb.contracts.secret.mkRequester {
          mode = "0400";
          owner = "immich";
          restartUnits = [ "immich-server.service" ];
        };
      });
      default = null;
    };

    mount = mkOption {
      type = shb.contracts.mount;
      description = ''
        Mount configuration. This is an output option.

        Use it to initialize a block implementing the "mount" contract.
        For example, with a zfs dataset:

        ```
        shb.zfs.datasets."immich" = {
          poolName = "root";
        } // config.shb.immich.mount;
        ```
      '';
      readOnly = true;
      default = {
        path = dataFolder;
      };
    };

    backup = mkOption {
      description = ''
        Backup configuration for Immich media files and database.
      '';
      default = { };
      type = submodule {
        options = shb.contracts.backup.mkRequester {
          user = "immich";
          sourceDirectories = [
            dataFolder
          ];
          excludePatterns = [
            "*.tmp"
            "cache/*"
            "encoded-video/*"
          ];
        };
      };
    };

    accelerationDevices = mkOption {
      description = ''
        Hardware acceleration devices for Immich.
        Set to null to allow access to all devices.
        Set to empty list to disable hardware acceleration.
      '';
      type = nullOr (listOf path);
      default = null;
      example = [ "/dev/dri" ];
    };

    machineLearning = mkOption {
      description = "Machine learning configuration.";
      default = { };
      type = submodule {
        options = {
          enable = mkOption {
            description = "Enable machine learning features.";
            type = bool;
            default = true;
          };

          environment = mkOption {
            description = "Extra environment variables for machine learning service.";
            type = attrsOf str;
            default = { };
            example = {
              MACHINE_LEARNING_WORKERS = "2";
              MACHINE_LEARNING_WORKER_TIMEOUT = "180";
            };
          };
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
            default = "immich";
          };

          adminUserGroup = lib.mkOption {
            type = lib.types.str;
            description = "OIDC admin group";
            default = "immich_admin";
          };

          userGroup = lib.mkOption {
            type = lib.types.str;
            description = "OIDC user group";
            default = "immich_user";
          };

          port = mkOption {
            description = "If given, adds a port to the endpoint.";
            type = nullOr port;
            default = null;
          };

          storageLabelClaim = mkOption {
            type = str;
            description = "Claim to use for user storage label.";
            default = "preferred_username";
          };

          buttonText = mkOption {
            type = str;
            description = "Text to display on the SSO login button.";
            default = "Login with SSO";
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
            description = "OIDC shared secret for Immich.";
            type = submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = "immich";
                group = "immich";
                restartUnits = [ "immich-server.service" ];
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

    settings = mkOption {
      type = attrs;
      description = ''
        Immich configuration settings.
        Only specify settings that you want SHB to manage declaratively.
        Other settings can be configured through Immich's admin UI.

        See https://immich.app/docs/install/config-file/ for available options.
      '';
      default = { };
      example = {
        ffmpeg.crf = 23;
        job.backgroundTask.concurrency = 5;
        storageTemplate = {
          enabled = true;
          template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
        };
      };
    };

    smtp = mkOption {
      description = ''
        SMTP configuration for sending notifications.
      '';
      default = null;
      type = nullOr (submodule {
        options = {
          from = mkOption {
            type = str;
            description = "SMTP address from which the emails originate.";
            example = "noreply@example.com";
          };

          replyTo = mkOption {
            type = str;
            description = "Reply-to address for emails.";
            example = "support@example.com";
          };

          host = mkOption {
            type = str;
            description = "SMTP host to send the emails to.";
            example = "smtp.example.com";
          };

          port = mkOption {
            type = port;
            description = "SMTP port to send the emails to.";
            default = 587;
          };

          username = mkOption {
            type = str;
            description = "Username to connect to the SMTP host.";
            example = "smtp-user";
          };

          password = mkOption {
            description = "File containing the password to connect to the SMTP host.";
            type = submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = "immich";
                restartUnits = [ "immich-server.service" ];
              };
            };
          };

          ignoreTLS = mkOption {
            type = bool;
            description = "Ignore TLS certificate errors.";
            default = false;
          };

          secure = mkOption {
            type = bool;
            description = "Use secure connection (SSL/TLS).";
            default = false;
          };
        };
      });
    };

    debug = mkOption {
      type = bool;
      description = "Set to true to enable debug logging.";
      default = false;
      example = true;
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(isNull cfg.ssl) -> !(isNull cfg.ssl.paths.cert) && !(isNull cfg.ssl.paths.key);
        message = "SSL is enabled for Immich but no cert or key is provided.";
      }
      {
        assertion = cfg.sso.enable -> cfg.ssl != null;
        message = "To integrate SSO, SSL must be enabled, set the shb.immich.ssl option.";
      }
    ];

    # Configure Immich service
    services.immich = {
      enable = true;
      host = "127.0.0.1";
      port = cfg.port;
      mediaLocation = cfg.mediaLocation;

      # Hardware acceleration configuration
      accelerationDevices = cfg.accelerationDevices;

      # Database configuration defaults to Unix socket /run/postgresql

      # Database configuration
      database = {
        # Disable pgvecto.rs, as it was deprecated before SHB integration
        enableVectors = false;
      };

      # Machine learning configuration
      machine-learning = mkIf cfg.machineLearning.enable {
        enable = true;
        environment = cfg.machineLearning.environment;
      };

      # Environment configuration
      environment = {
        IMMICH_LOG_LEVEL = if cfg.debug then "debug" else "log";
        REDIS_HOSTNAME = "127.0.0.1";
        REDIS_PORT = "6379";
        REDIS_DBINDEX = "0";
      }
      // lib.optionalAttrs (cfg.jwtSecretFile != null) {
        JWT_SECRET_FILE = cfg.jwtSecretFile.result.path;
      }
      // lib.optionalAttrs (cfg.settings != { } || cfg.sso.enable || cfg.smtp != null) {
        IMMICH_CONFIG_FILE = configFile;
      };
    };

    services.immich-public-proxy = mkIf (cfg.publicProxyEnable) {
      enable = true;
      port = cfg.publicProxyPort;
      immichUrl = "https://${fqdn}";
    };

    # Create basic directories for Immich
    systemd.tmpfiles.rules = [
      "d /var/lib/immich 0700 immich immich"
    ];

    # Configuration setup service - generates config only for SHB-managed settings
    systemd.services.immich-setup-config =
      mkIf (cfg.enable && (cfg.settings != { } || cfg.sso.enable || cfg.smtp != null))
        {
          description = "Setup Immich configuration for SHB-managed settings";
          wantedBy = [ "multi-user.target" ];
          before = [ "immich-server.service" ];
          after = [ "network.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = "immich";
            Group = "immich";
          };
          script = ''
            mkdir -p ${dataFolder}

            # Generate config file with only SHB-managed settings
            ${configSetupScript}
          '';
        };

    # Add immich user to video and render groups for hardware acceleration
    users.users.immich.extraGroups = optionals (cfg.accelerationDevices != [ ]) [
      "video"
      "render"
    ];

    # PostgreSQL extensions are automatically handled by the Immich service

    # Redis is automatically configured by the Immich service

    # Configure Nginx reverse proxy
    shb.nginx.vhosts = [
      {
        inherit (cfg) subdomain domain ssl;
        upstream = "http://127.0.0.1:${toString cfg.port}";
        autheliaRules = lib.mkIf (cfg.sso.enable) [
          {
            domain = fqdn;
            policy = "bypass";
            resources = [
              "^/api.*"
              "^/.well-known/immich"
              "^/share.*"
              "^/_app/immutable/.*"
            ];
          }
          {
            domain = fqdn;
            policy = cfg.sso.authorization_policy;
            subject = [
              "group:immich_user"
              "group:immich_admin"
            ];
          }
        ];
        authEndpoint = lib.mkIf (cfg.sso.enable) cfg.sso.endpoint;
        extraConfig = ''
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;
          send_timeout 600s;
          proxy_buffering off;
        '';
      }
    ];

    # Allow large uploads from mobile app
    services.nginx.virtualHosts."${fqdn}" = {
      extraConfig = ''
        client_max_body_size 50G;
      '';
      locations."^~ /share" = {
        recommendedProxySettings = true;
        proxyPass = "http://127.0.0.1:${toString cfg.publicProxyPort}";
      };
    };

    # Ensure services start in correct order
    systemd.services.immich-server = {
      after = [
        "postgresql.service"
        "redis-immich.service"
      ]
      ++ optionals (cfg.settings != { } || cfg.sso.enable || cfg.smtp != null) [
        "immich-setup-config.service"
      ];
      requires = [
        "postgresql.service"
        "redis-immich.service"
      ]
      ++ optionals (cfg.settings != { } || cfg.sso.enable || cfg.smtp != null) [
        "immich-setup-config.service"
      ];
    };

    systemd.services.immich-machine-learning = mkIf cfg.machineLearning.enable {
      after = [ "immich-server.service" ];
    };

    # Authelia integration for SSO
    shb.authelia.extraDefinitions = {
      # Immich expects all users that get a token to be granted access. So users can either be part of the
      # "admin" group or the "user" group. Users that are not part of either should be blocked by
      # the ID provider (Authelia).
      user_attributes.${roleClaim}.expression =
        ''"${cfg.sso.adminUserGroup}" in groups ? "admin" : "user"'';
    };
    shb.authelia.extraOidcClaimsPolicies.immich_policy = {
      custom_claims = {
        ${roleClaim} = { };
      };
    };
    shb.authelia.extraOidcScopes.immich_scope = {
      claims = [ roleClaim ];
    };

    shb.authelia.oidcClients = lists.optionals (cfg.sso.enable && cfg.sso.provider == "Authelia") [
      {
        client_id = cfg.sso.clientID;
        client_name = "Immich";
        client_secret.source = cfg.sso.sharedSecretForAuthelia.result.path;
        public = false;
        authorization_policy = cfg.sso.authorization_policy;
        claims_policy = "immich_policy";
        token_endpoint_auth_method = "client_secret_post";
        redirect_uris = [
          "${protocol}://${fqdn}/auth/login"
          "${protocol}://${fqdn}/user-settings"
          "app.immich:///oauth-callback"
        ];
        inherit scopes;
      }
    ];
  };
}
