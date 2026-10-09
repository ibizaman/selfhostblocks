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

  ssoFqdnWithPort =
    if isNull cfg.sso.port then cfg.sso.endpoint else "${cfg.sso.endpoint}:${toString cfg.sso.port}";
  # Generate Immich configuration file only for SHB-managed settings
  shbManagedSettings =
    lib.optionalAttrs (cfg.settings != { }) cfg.settings
    // {
      server.externalDomain = "${protocol}://${cfg.subdomain}.${cfg.domain}";
      newVersionCheck.enabled = cfg.newVersionCheck;
    }
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
        # 0 means the user cannot upload anything. Empty means infinity.
        # defaultStorageQuota = 0;
        buttonText = cfg.sso.buttonText;
        autoRegister = cfg.sso.autoRegister;
        autoLaunch = cfg.sso.autoLaunch;
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
    filterAttrs
    mapAttrs'
    mkEnableOption
    mkIf
    mkMerge
    lists
    mkOption
    nameValuePair
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
    externalPath
    ;
in
{
  imports = [
    ../../lib/module.nix
    ../blocks/nginx.nix

    (lib.mkRemovedOptionModule [ "shb" "immich" "mount" ] ''
      The mount contract is deprecated. Use instead the
      `shb.immich.mediaLocation` option.
    '')

    # TODO: I don't understand why but these 3 imports fail saying it can't find anything
    # under shb.immich.sso. It's the same in the sibling jellyfin.nix module.
    #
    # (lib.mkRemovedOptionModule [ "shb" "immich" "sso" "passwordLogin" ] ''
    #   The passwordLogin option does not exist anymore on upstream Immich.
    #   To enable passwordLogin as before, set `shb.immich.sso.autoLaunch` to false.
    # '')
    # (lib.mkRenamedOptionModule [ "shb" "immich" "sso" "adminUserGroup" ] [ "shb" "immich" "ldap" "adminGroup" ])
    # (lib.mkRenamedOptionModule [ "shb" "immich" "sso" "userGroup" ] [ "shb" "immich" "ldap" "userGroup" ])
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

    skipOnboarding = mkOption {
      description = ''
        This allows you to skip onboarding.

        If set to true, you are required to fill out the shb.immich.admin options.
      '';
      type = bool;
      default = false;
    };

    initialAdmin = mkOption {
      description = ''
        Declaratively create an admin.

        If set, this means the admin user will be created when Immich server starts.
        If the admin already exists, nothing will be done.

        This does not skip onboarding unless you set
        shb.immich.skipOnboarding to true.
      '';
      default = null;
      type = nullOr (submodule {
        options = {
          name = mkOption {
            description = ''
              Initial name of declaratively setup admin.

              Subsequent changes in the UI will override this value.
              Also, changing this value will not update the actual name.
            '';
            type = str;
          };
          email = mkOption {
            description = ''
              Initial email of declaratively setup admin.

              Subsequent changes in the UI will override this value.
              Also, changing this value will not update the actual email.
            '';
            type = str;
          };
          passwordFile = mkOption {
            description = ''
              Initial password of declaratively setup admin.

              Subsequent changes in the UI will override this value.
              Also, changing this value will not update the actual password.
            '';
            type = submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = "immich";
                restartUnits = [ "immich-server.service" ];
              };
            };
          };
        };
      });
    };

    newVersionCheck = mkOption {
      description = ''
        Set to true to allow Immich to phone home
        so it can check if a new version is available.

        In the spirit of not sending any telemetry by default,
        this option is set to false by default.
      '';
      type = bool;
      default = false;
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

    declarativeApiKeys = mkOption {
      description = ''
        Api keys defined here are automatically created and managed by SHB.

        Currently, no mechanism to recreate or rotate a key exist apart from deleting it manually
        and running the corresponding systemd service once more.
      '';
      type = attrsOf (
        submodule (
          { name, ... }: {
            options = {
              name = mkOption {
                description = ''
                  Pretty name of the api key. Can contain spaces.

                  Defaults to the submodule's name.
                '';
                default = name;
              };
              email = mkOption {
                description = ''
                  Email of the owner of the key. No attempt is made to verify if this user exists on Immich
                  and the generation will fail in that case.

                  Defaults to the initial admin.
                '';
                default = cfg.initialAdmin.email;
                defaultText = "shb.immich.initialAdmin.email";
              };
              permissions = mkOption {
                description = ''
                  List of permissions to set on the key.

                  Changing this will not recreate the key.
                  To recreate it, it must be deleted on disk.
                '';
                type = listOf str;
              };
              path = mkOption {
                description = ''
                  Path where the API key will be written to.

                  The default path is non-volatile so the same API key
                  can be re-used across reboots. A volatile path
                  will end up creating a new key on reboot.
                '';
                type = externalPath;
                default = "${cfg.mediaLocation}/${name}";
              };
            };
          }
        )
      );
    };

    backupApiKey = mkOption {
      description = ''
        Api key with permission backup.* used to create and restore backups.

        This key can be created manually
        or come from the shb.immich.declarativeApiKeys option:

        ```
        shb.immich.declarativeApiKeys.backupKey.permissions = config.shb.immich.backupApiKey.permissions;
        shb.immich.backupApiKey.contract.result.path = config.shb.immich.declarativeApiKeys.backupKey.path;
        ```

        If null, no backup will be taken.
      '';
      type = nullOr (submodule {
        options = {
          contract = mkOption {
            description = ''
              This option implements the contract for secrets for the backup api key.
            '';
            type = submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = "immich";
                group = "immich";
                restartUnits = [ "immich-server.service" ];
              };
            };
          };
          permissions = mkOption {
            description = ''
              Permissions for the backup API key.

              Pass those to the shb.immich.declarativeApiKeys.<name>.permissions option.
            '';
            type = listOf str;
            default = [
              "maintenance"
              "backup.list"
              "backup.delete"
              "job.create"
            ];
            readOnly = true;
          };
        };
      });
      default = null;
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
            cfg.mediaLocation
          ];
          beforeBackup = optionals (cfg.backupApiKey != null) [
            ''
              set -euo pipefail

              export PATH="${
                pkgs.lib.makeBinPath [
                  pkgs.coreutils
                  pkgs.curl
                  pkgs.jq
                ]
              }:$PATH"

              if ! [ -f "${cfg.backupApiKey.contract.result.path}" ]; then
                echo "No backup api key found. ${
                  if (cfg.backupApiKey != null) then
                    "File ${cfg.backupApiKey.contract.result.path} is missing or with wrong permissions."
                  else
                    "Run systemd service immich-bootstrap-backup-api-key.service."
                }"
                exit 1
              fi
              apiKey="$(cat "${cfg.backupApiKey.contract.result.path}")"
              endpoint="127.0.0.1:${toString cfg.port}/api"

              response="$( \
                curl --silent --fail-with-body -X GET "$endpoint/admin/database-backups" \
                   -H "Content-Type: application/json" \
                   -H "x-api-key: $apiKey" \
              )"
              if ! backups_before="$(echo "$response" | jq -r '.backups.[].filename')"; then
                  echo "Could not parse response as json: $response"
                  exit 1
              fi
              echo "backups_before=$backups_before"
              if ! before_count=$(echo "$response" | jq '.backups | length'); then
                  echo "Could not parse response as json: $response"
                  exit 1
              fi
              echo "before_count=$before_count"

              curl --silent --fail-with-body -X POST "$endpoint/jobs" \
                   -H "Content-Type: application/json" \
                   -H "x-api-key: $apiKey" \
                   --data "{\"name\":\"backup-database\"}"

              interval=2

              while true; do
                  response="$( \
                    curl --silent --fail-with-body -X GET "$endpoint/admin/database-backups" \
                       -H "Content-Type: application/json" \
                       -H "x-api-key: $apiKey" \
                  )"
                  if ! backups_after="$(echo "$response" | jq -r '.backups.[].filename')"; then
                    sleep "$interval"
                    continue
                  fi
                  echo "backups_after=$backups_after"

                  after_count=$(echo "$response" | jq '.backups | length')
                  echo "after_count=$after_count"

                  if (( after_count == before_count + 1 )); then
                      new_entry=$(comm -13 \
                          <(printf '%s\n' "$backups_before" | sort) \
                          <(printf '%s\n' "$backups_after" | sort))

                      break
                  elif (( after_count != before_count )); then
                      echo "Unexpected number of backups. We expected to find $(( before_count + 1 )) but there are $after_count backups. Aborting because we don't know which backup to choose. This can happen if two backups run simultaneously. To fix this you can just restatr this backup."
                  fi

                  sleep "$interval"
              done

              echo -n "$new_entry" > ${cfg.mediaLocation}/backups/.latest
            ''
          ];
          afterBackup = optionals (cfg.backupApiKey != null) [
            ''
              export PATH="${
                pkgs.lib.makeBinPath [
                  pkgs.curl
                ]
              }:$PATH"

              if ! [ -f "${cfg.backupApiKey.contract.result.path}" ]; then
                echo "No backup api key found. ${
                  if (cfg.backupApiKey != null) then
                    "File ${cfg.backupApiKey.contract.result.path} is missing or with wrong permissions."
                  else
                    "Run systemd service immich-bootstrap-backup-api-key.service."
                }"
                exit 1
              fi
              apiKey="$(cat "${cfg.backupApiKey.contract.result.path}")"
              endpoint="127.0.0.1:${toString cfg.port}/api"

              if ! [ -f "${cfg.mediaLocation}/backups/.latest" ]; then
                exit 0
              fi

              filename="$(cat "${cfg.mediaLocation}/backups/.latest")"
              endpoint="127.0.0.1:${toString cfg.port}/api"
              curl --silent --fail-with-body -X DELETE $endpoint/admin/database-backups \
                 -H "Content-Type: application/json" \
                 -H "x-api-key: $apiKey" \
                 --data "{\"backups\":[\"$filename\"]}"
            ''
          ];
          beforeRestore = [ ];
          afterRestore = optionals (cfg.backupApiKey != null) [
            ''
              export PATH="${
                pkgs.lib.makeBinPath [
                  pkgs.curl
                  pkgs.coreutils
                  pkgs.jq
                ]
              }:$PATH"

              if ! [ -f "${cfg.backupApiKey.contract.result.path}" ]; then
                echo "No backup api key found. ${
                  if (cfg.backupApiKey != null) then
                    "File ${cfg.backupApiKey.contract.result.path} is missing or with wrong permissions."
                  else
                    "Run systemd service immich-bootstrap-backup-api-key.service."
                }"
                exit 1
              fi
              apiKey="$(cat "${cfg.backupApiKey.contract.result.path}")"
              filename="$(cat "${cfg.mediaLocation}/backups/.latest")"
              endpoint="127.0.0.1:${toString cfg.port}/api"

              cookieJar="$(mktemp)"
              trap 'rm -f "$cookieJar"' EXIT

              if ! curl --silent --fail-with-body -X POST $endpoint/admin/maintenance \
                     -H "Content-Type: application/json" \
                     -H "x-api-key: $apiKey" \
                     -c "$cookieJar" \
                     --data "{\"action\":\"restore_database\",\"restoreBackupFilename\":\"$filename\"}" \
                     ; then
                   echo "Could not start restore process, aborting."
                   exit 1
              fi

              interval=2
              success=true

              while true; do
                  if response="$( \
                    curl --silent --fail-with-body -X GET "$endpoint/admin/maintenance/status" \
                       -H "Content-Type: application/json" \
                       -H "x-api-key: $apiKey" \
                  )"; then
                      if echo "$response" | jq -e '.task == "error"' >/dev/null; then
                          echo "Database restore failed." >&2
                          success=false
                          break
                      fi

                      if echo "$response" | jq -e '.active == false and .action == "end"' >/dev/null; then
                          echo "Database restore completed successfully."
                          break
                      fi
                  fi

                  sleep "$interval"
              done

              curl --silent --fail-with-body -X DELETE $endpoint/admin/database-backups \
                 -H "Content-Type: application/json" \
                 -H "x-api-key: $apiKey" \
                 --data "{\"backups\":[\"$filename\"]}"

              if [ $success = false ]; then
                echo "Something went wrong during the restore"
                exit 1
              fi
            ''
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

    ldap = mkOption {
      description = "Setup LDAP integration.";
      default = { };
      type = submodule {
        options = {
          adminGroup = lib.mkOption {
            type = lib.types.str;
            description = "OIDC admin group";
            default = "immich_admin";
          };

          userGroup = lib.mkOption {
            type = lib.types.str;
            description = "OIDC user group";
            default = "immich_user";
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
            type = str;
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

    dashboard = lib.mkOption {
      description = ''
        Dashboard contract consumer
      '';
      default = { };
      type = lib.types.submodule {
        options = shb.contracts.dashboard.mkRequester {
          externalUrl = "https://${fqdn}";
          externalUrlText = "https://\${config.shb.immich.subdomain}.\${config.shb.immich.domain}";
          internalUrl = "http://127.0.0.1:${toString cfg.port}";
        };
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      assertions = [
        {
          assertion = !(isNull cfg.ssl) -> !(isNull cfg.ssl.paths.cert) && !(isNull cfg.ssl.paths.key);
          message = "SSL is enabled for Immich but no cert or key is provided.";
        }
        {
          assertion = cfg.sso.enable -> cfg.ssl != null;
          message = "To integrate SSO, SSL must be enabled, set the shb.immich.ssl option.";
        }
        {
          assertion = cfg.skipOnboarding -> cfg.initialAdmin != null;
          message = "To skip onboarding, the admin user must be set declaratively, set shb.immich.initialAdmin option.";
        }
        {
          assertion = cfg.declarativeApiKeys != { } -> cfg.initialAdmin != null;
          message = ''
            To let the SHB immich module manage the declarative api keys, the admin user must be set declaratively, set the shb.immich.initialAdmin.* options.

            If Immich has already been started from a previous deploy and you see this message for the first time, the recommended fix is
            to set the shb.immich.initialAdmin.* options to match the current admin email and password.
          '';
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

          IMMICH_TRUSTED_PROXIES = "127.0.0.1";

          IMMICH_LOG_FORMAT = "json";
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
      systemd.tmpfiles.settings."10-shb-immich" = {
        "/var/lib/immich".d = {
          mode = "0700";
          user = "immich";
          group = "immich";
        };
      };

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
              mkdir -p ${cfg.mediaLocation}

              # Generate config file with only SHB-managed settings
              ${configSetupScript}
            '';
          };

      # We do it ourselves to add SUPERUSER role because immich needs it for restoring a backup.
      services.immich.database.createDB = false;
      services.postgresql.ensureDatabases = [ config.services.immich.database.name ];
      services.postgresql.ensureUsers = [
        {
          name = config.services.immich.database.user;
          ensureDBOwnership = true;
          ensureClauses = {
            login = true;
            superuser = true;
          };
        }
      ];

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
                "group:${cfg.ldap.userGroup}"
                "group:${cfg.ldap.adminGroup}"
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

        serviceConfig.ExecStartPost =
          let
            waitForReady = pkgs.writeShellApplication {
              name = "waitForReady";
              runtimeInputs = [
                pkgs.curl
              ];
              text = ''
                URL="http://127.0.0.1:${toString cfg.port}/api/server/config"
                SLEEP_INTERVAL_SEC=2

                start_time=$(date +%s)

                echo "Waiting for Immich's public API..."

                while true; do
                  if curl \
                      --fail \
                      --header 'Accept: application/json' \
                      --silent \
                      "$URL" \
                      2>/dev/null
                  then
                    echo "Immich is ready."
                    break
                  fi

                  now=$(date +%s)
                  elapsed=$(( now - start_time ))

                  echo "Waiting for Immich... elapsed: ''${elapsed}s"
                  sleep "$SLEEP_INTERVAL_SEC"
                done
              '';
            };

            declarativeAdminScript = pkgs.writeShellApplication {
              name = "declarativeAdminScript";
              runtimeInputs = [
                pkgs.curl
                pkgs.jq
              ];
              text = ''
                echo "Creating or updating declarative admin user..."
                password="$(cat "${cfg.initialAdmin.passwordFile.result.path}")"
                isInitialized="$(curl 127.0.0.1:${toString cfg.port}/api/server/config | jq .isInitialized)"
                if [ "$isInitialized" = "false" ]; then
                    curl -X POST 127.0.0.1:${toString cfg.port}/api/auth/admin-sign-up \
                         -H "Content-Type: application/json" \
                         --data "{\"email\":\"${cfg.initialAdmin.email}\",\"name\":\"${cfg.initialAdmin.name}\",\"password\":\"$password\"}"
                    echo "Admin user created successfully."
                else
                    echo "Admin user exists already, nothing to do."
                fi
              '';
            };

            skipOnboardingScript = pkgs.writeShellApplication {
              name = "skipOnboardingScript";
              runtimeInputs = [
                pkgs.curl
                pkgs.jq
              ];
              text = ''
                echo "Skipping onboarding..."
                password="$(cat "${cfg.initialAdmin.passwordFile.result.path}")"
                isOnboarded="$(curl 127.0.0.1:${toString cfg.port}/api/server/config | jq .isOnboarded)"
                if [ "$isOnboarded" = "false" ]; then
                    accessToken="$(curl -X POST 127.0.0.1:${toString cfg.port}/api/auth/login \
                         -H "Content-Type: application/json" \
                         --data "{\"email\":\"${cfg.initialAdmin.email}\",\"password\":\"$password\"}" \
                         | jq -r .accessToken)"
                    curl -X PUT 127.0.0.1:${toString cfg.port}/api/users/me/onboarding \
                         -H "Content-Type: application/json" \
                         -H "x-immich-session-token: $accessToken" \
                         --data "{\"isOnboarded\":true}"
                    curl -X POST 127.0.0.1:${toString cfg.port}/api/system-metadata/admin-onboarding \
                         -H "Content-Type: application/json" \
                         -H "x-immich-session-token: $accessToken" \
                         --data "{\"isOnboarded\":true}"
                    echo "Onboarding skipped successfully."
                else
                    echo "Onboarding already skipped."
                fi
              '';
            };
          in
          [ (lib.getExe waitForReady) ]
          ++ (lib.optionals (cfg.initialAdmin != null) [ (lib.getExe declarativeAdminScript) ])
          ++ (lib.optionals (cfg.skipOnboarding) [ (lib.getExe skipOnboardingScript) ]);
      };

      systemd.services.immich-machine-learning = mkIf cfg.machineLearning.enable {
        after = [ "immich-server.service" ];
      };

      # Authelia integration for SSO
      shb.authelia.extraDefinitions = {
        # Immich expects all users that get a token to be granted access. So users can either be part of the
        # "admin" group or the "user" group. Users that are not part of either should be blocked by
        # the ID provider (Authelia).
        user_attributes.${roleClaim}.expression = ''"${cfg.ldap.adminGroup}" in groups ? "admin" : "user"'';
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
          response_types = [ "code" ];
          grant_types = [ "authorization_code" ];
          require_pkce = true;
          pkce_challenge_method = "S256";
          id_token_signed_response_alg = "RS256";
          userinfo_signed_response_alg = "RS256";
          token_endpoint_auth_method = "client_secret_post";
          redirect_uris = [
            "${protocol}://${fqdn}/auth/login"
            "${protocol}://${fqdn}/user-settings"
            "app.immich:///oauth-callback"
          ];
          inherit scopes;
        }
      ];
    })
    {
      systemd.services =
        let
          mkService =
            name: cfg':
            nameValuePair "immich-bootstrap-${name}" {
              description = "Bootstrap the Immich ${cfg'.name} API key";
              wantedBy = [ "multi-user.target" ];
              after = [ "immich-server.service" ];
              requires = [ "immich-server.service" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                User = "immich";
                Group = "immich";
              };
              path = [
                pkgs.coreutils
                pkgs.curl
                pkgs.jq
              ];
              script = ''
                set -euo pipefail

                token_file="${cfg'.path}"

                if [ -s "$token_file" ]; then
                  exit 0
                fi

                password="$(cat "${cfg.initialAdmin.passwordFile.result.path}")"

                response="$(curl --silent --fail-with-body -X POST 127.0.0.1:${toString cfg.port}/api/auth/login \
                     -H "Content-Type: application/json" \
                     --data "{\"email\":\"${cfg.initialAdmin.email}\",\"password\":\"$password\"}")"
                accessToken="$(echo "$response" | jq -r .accessToken)" || { echo "response=$response"; exit 1; }

                response="$(curl --silent --fail-with-body -X POST 127.0.0.1:${toString cfg.port}/api/api-keys \
                     -H "Content-Type: application/json" \
                     -H "x-immich-session-token: $accessToken" \
                     --data '${builtins.toJSON { inherit (cfg') name permissions; }}')"
                apiKey="$(echo "$response" | jq -r .secret)" || { echo "response=$response"; exit 1; }

                echo "$apiKey" > "$token_file"
              '';
            };
        in
        mapAttrs' mkService cfg.declarativeApiKeys;
    }
  ];
}
