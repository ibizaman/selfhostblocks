{
  config,
  options,
  pkgs,
  lib,
  shb,
  ...
}:

let
  cfg = config.shb.forgejo;

  inherit (lib)
    all
    attrNames
    concatMapStringsSep
    getExe
    lists
    literalExpression
    mapAttrsToList
    mkEnableOption
    mkForce
    mkIf
    mkMerge
    mkOption
    mkOverride
    nameValuePair
    optionalString
    optionals
    ;
  inherit (lib.types)
    attrsOf
    bool
    enum
    listOf
    nullOr
    package
    port
    submodule
    str
    ;
in
{
  imports = [
    ../blocks/nginx.nix
    ../blocks/lldap.nix

    (lib.mkRemovedOptionModule [ "shb" "forgejo" "adminPassword" ] ''
      Instead, define an admin user in shb.forgejo.users and give it the same password, like so:

          shb.forgejo.users = {
            "forgejoadmin" = {
              isAdmin = true;
              email = "forgejoadmin@example.com";
              password.result = <path/to/password>;
            };
          };
    '')
  ];

  options.shb.forgejo = {
    enable = mkEnableOption "selfhostblocks.forgejo";

    subdomain = mkOption {
      type = str;
      description = ''
        Subdomain under which Forgejo will be served.

        ```
        <subdomain>.<domain>[:<port>]
        ```
      '';
      example = "forgejo";
    };

    domain = mkOption {
      description = ''
        Domain under which Forgejo is served.

        ```
        <subdomain>.<domain>[:<port>]
        ```
      '';
      type = str;
      example = "domain.com";
    };

    ssl = mkOption {
      description = "Path to SSL files";
      type = nullOr shb.contracts.ssl.certs;
      default = null;
    };

    ldap = mkOption {
      description = ''
        LDAP Integration.
      '';
      default = { };
      type = nullOr (submodule {
        options = {
          enable = mkEnableOption "LDAP integration.";

          provider = mkOption {
            type = enum [ "LLDAP" ];
            description = "LDAP provider name, used for display.";
            default = "LLDAP";
          };

          host = mkOption {
            type = str;
            description = ''
              Host serving the LDAP server.
            '';
            default = "127.0.0.1";
          };

          port = mkOption {
            type = port;
            description = ''
              Port of the service serving the LDAP server.
            '';
            default = 389;
          };

          dcdomain = mkOption {
            type = str;
            description = "dc domain for ldap.";
            example = "dc=mydomain,dc=com";
          };

          adminName = mkOption {
            type = str;
            description = "Admin user of the LDAP server. Cannot be reserved word 'admin'.";
            default = "admin";
          };

          adminPassword = mkOption {
            description = "LDAP admin password.";
            type = submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0440";
                owner = "forgejo";
                group = "forgejo";
                restartUnits = [ "forgejo.service" ];
              };
            };
          };

          userGroup = mkOption {
            type = str;
            description = "Group users must belong to be able to login.";
            default = "forgejo_user";
          };

          adminGroup = mkOption {
            type = str;
            description = "Group users must belong to be admins.";
            default = "forgejo_admin";
          };

          waitForSystemdServices = mkOption {
            type = listOf str;
            default = [ ];
            description = ''
              List of systemd services to wait on before starting.
              This is needed because forgejo will try a lookup on the LDAP instance
              and will abort setting up LDAP if it can't reach it.
            '';
          };
        };
      });
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
            type = enum [ "Authelia" ];
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
            default = "forgejo";
          };

          authorization_policy = mkOption {
            type = enum [
              "one_factor"
              "two_factor"
            ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };

          sharedSecret = mkOption {
            description = "OIDC shared secret for Forgejo.";
            type = submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0440";
                owner = "forgejo";
                group = "forgejo";
                restartUnits = [ "forgejo.service" ];
              };
            };
          };

          sharedSecretForAuthelia = mkOption {
            description = "OIDC shared secret for Authelia.";
            type = submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                owner = "authelia";
              };
            };
          };
        };
      };
    };

    users = mkOption {
      description = "Users managed declaratively.";
      default = { };
      type = attrsOf (submodule {
        options = {
          isAdmin = mkOption {
            description = "Set user as admin or not.";
            type = bool;
            default = false;
          };

          email = mkOption {
            description = ''
              Email of user.

              This is only set when the user is created, changing this later on will have no effect.
            '';
            type = str;
          };

          password = mkOption {
            description = "Forgejo admin user password.";
            type = submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0440";
                owner = "forgejo";
                group = "forgejo";
                restartUnits = [ "forgejo.service" ];
              };
            };
          };
        };
      });
    };

    databasePassword = mkOption {
      description = "File containing the Forgejo database password.";
      type = submodule {
        options = shb.contracts.secret.mkRequester {
          mode = "0440";
          owner = "forgejo";
          group = "forgejo";
          restartUnits = [ "forgejo.service" ];
        };
      };
    };

    repositoryRoot = mkOption {
      type = nullOr str;
      description = "Path where to store the repositories. If null, uses the default under the Forgejo StateDir.";
      default = null;
      example = "/srv/forgejo";
    };

    localActionRunner = mkOption {
      type = bool;
      default = true;
      description = ''
        Enable local action runner that runs for all labels.
      '';
    };

    hostPackages = mkOption {
      type = listOf package;
      default = with pkgs; [
        bash
        coreutils
        curl
        gawk
        gitMinimal
        gnused
        nodejs
        wget
      ];
      defaultText = literalExpression ''
        with pkgs; [
          bash
          coreutils
          curl
          gawk
          gitMinimal
          gnused
          nodejs
          wget
        ]
      '';
      description = ''
        List of packages, that are available to actions, when the runner is configured
        with a host execution label.
      '';
    };

    backup = mkOption {
      description = ''
        Backup configuration.
      '';
      default = { };
      type = lib.types.submodule {
        options = shb.contracts.backup.mkRequester {
          user = options.services.forgejo.user.value;
          sourceDirectories = [
            config.services.forgejo.dump.backupDir
          ]
          ++ optionals (cfg.repositoryRoot != null) [
            cfg.repositoryRoot
          ];
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
        shb.zfs.datasets."forgejo" = {
          poolName = "root";
        } // config.shb.forgejo.mount;
        ```
      '';
      readOnly = true;
      default = {
        path = config.services.forgejo.stateDir;
      };
    };

    smtp = mkOption {
      description = ''
        Send notifications by smtp.
      '';
      default = null;
      type = nullOr (submodule {
        options = {
          from_address = mkOption {
            type = str;
            description = "SMTP address from which the emails originate.";
            example = "authelia@mydomain.com";
          };
          host = mkOption {
            type = str;
            description = "SMTP host to send the emails to.";
          };
          port = mkOption {
            type = port;
            description = "SMTP port to send the emails to.";
            default = 25;
          };
          username = mkOption {
            type = str;
            description = "Username to connect to the SMTP host.";
          };
          password = mkOption {
            description = "File containing the password to connect to the SMTP host.";
            type = submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0440";
                owner = "forgejo";
                group = "forgejo";
                restartUnits = [ "forgejo.service" ];
              };
            };
          };
        };
      });
    };

    debug = mkOption {
      description = "Enable debug logging.";
      type = bool;
      default = false;
    };

    dashboard = lib.mkOption {
      description = ''
        Dashboard contract consumer
      '';
      default = { };
      type = lib.types.submodule {
        options = shb.contracts.dashboard.mkRequester {
          externalUrl = "https://${cfg.subdomain}.${cfg.domain}";
          externalUrlText = "https://\${config.shb.forgejo.subdomain}.\${config.shb.forgejo.domain}";
          internalUrl = "https://${cfg.subdomain}.${cfg.domain}";
          internalUrlText = "https://\${config.shb.forgejo.subdomain}.\${config.shb.forgejo.domain}";
        };
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.forgejo = {
        enable = true;
        repositoryRoot = mkIf (cfg.repositoryRoot != null) cfg.repositoryRoot;
        settings = {
          server = {
            DOMAIN = cfg.domain;
            PROTOCOL = "http+unix";
            ROOT_URL = "https://${cfg.subdomain}.${cfg.domain}/";
          };

          service.DISABLE_REGISTRATION = true;

          log.LEVEL = if cfg.debug then "Debug" else "Info";

          cron = {
            ENABLE = true;
            RUN_AT_START = true;
            SCHEDULE = "@every 1h";
          };
        };
      };

      # 1 lower than default, to solve conflict between shb.postgresql and nixpkgs' forgejo module.
      services.postgresql.enable = mkOverride 999 true;

      # https://github.com/NixOS/nixpkgs/issues/258371#issuecomment-2271967113
      systemd.services.forgejo.serviceConfig.Type = mkForce "exec";

      shb.nginx.vhosts = [
        {
          inherit (cfg) domain subdomain ssl;
          upstream = "http://unix:${config.services.forgejo.settings.server.HTTP_ADDR}";
        }
      ];
    })

    (mkIf cfg.enable {
      services.forgejo.database = {
        type = "postgres";

        passwordFile = cfg.databasePassword.result.path;
      };
    })

    (mkIf cfg.enable {
      services.forgejo.dump = {
        enable = true;
        type = "tar.gz";
        interval = "hourly";
      };
      systemd.services.forgejo-dump.preStart = "rm -f ${config.services.forgejo.dump.backupDir}/*.tar.gz";
    })

    # For Forgejo setup: https://github.com/lldap/lldap/blob/main/example_configs/gitea.md
    # For cli info: https://docs.gitea.com/usage/command-line
    # Security protocols in: https://codeberg.org/forgejo/forgejo/src/branch/forgejo/services/auth/source/ldap/security_protocol.go#L27-L31
    (mkIf (cfg.enable && cfg.ldap.enable != false) {
      systemd.services.forgejo.wants = cfg.ldap.waitForSystemdServices;
      systemd.services.forgejo.after = cfg.ldap.waitForSystemdServices;

      shb.lldap.ensureGroups = {
        ${cfg.ldap.adminGroup} = { };
        ${cfg.ldap.userGroup} = { };
      };

      # The delimiter in the `cut` command is a TAB!
      systemd.services.forgejo.preStart =
        let
          provider = "SHB-${cfg.ldap.provider}";
        in
        ''
          auth="${getExe config.services.forgejo.package} admin auth"

          echo "Trying to find existing ldap configuration for ${provider}"...
          set +e -o pipefail
          id="$($auth list | grep "${provider}.*LDAP" |  cut -d'	' -f1)"
          found=$?
          set -e +o pipefail

          if [[ $found = 0 ]]; then
            echo Found ldap configuration at id=$id, updating it if needed.
            $auth update-ldap \
              --id                  $id \
              --name                ${provider} \
              --host                ${cfg.ldap.host} \
              --port                ${toString cfg.ldap.port} \
              --bind-dn             uid=${cfg.ldap.adminName},ou=people,${cfg.ldap.dcdomain} \
              --bind-password       $(tr -d '\n' < ${cfg.ldap.adminPassword.result.path}) \
              --security-protocol   Unencrypted \
              --user-search-base    ou=people,${cfg.ldap.dcdomain} \
              --user-filter         '(&(|(memberof=cn=${cfg.ldap.userGroup},ou=groups,${cfg.ldap.dcdomain})(memberof=cn=${cfg.ldap.adminGroup},ou=groups,${cfg.ldap.dcdomain}))(|(uid=%[1]s)(mail=%[1]s)))' \
              --admin-filter        '(memberof=cn=${cfg.ldap.adminGroup},ou=groups,${cfg.ldap.dcdomain})' \
              --username-attribute  uid \
              --firstname-attribute givenName \
              --surname-attribute   sn \
              --email-attribute     mail \
              --avatar-attribute    jpegPhoto \
              --synchronize-users
            echo "Done updating LDAP configuration."
          else
            echo Did not find any ldap configuration, creating one with name ${provider}.
            $auth add-ldap \
              --name                ${provider} \
              --host                ${cfg.ldap.host} \
              --port                ${toString cfg.ldap.port} \
              --bind-dn             uid=${cfg.ldap.adminName},ou=people,${cfg.ldap.dcdomain} \
              --bind-password       $(tr -d '\n' < ${cfg.ldap.adminPassword.result.path}) \
              --security-protocol   Unencrypted \
              --user-search-base    ou=people,${cfg.ldap.dcdomain} \
              --user-filter         '(&(|(memberof=cn=${cfg.ldap.userGroup},ou=groups,${cfg.ldap.dcdomain})(memberof=cn=${cfg.ldap.adminGroup},ou=groups,${cfg.ldap.dcdomain}))(|(uid=%[1]s)(mail=%[1]s)))' \
              --admin-filter        '(memberof=cn=${cfg.ldap.adminGroup},ou=groups,${cfg.ldap.dcdomain})' \
              --username-attribute  uid \
              --firstname-attribute givenName \
              --surname-attribute   sn \
              --email-attribute     mail \
              --avatar-attribute    jpegPhoto \
              --synchronize-users
            echo "Done adding LDAP configuration."
          fi
        '';
    })

    # For Authelia to Forgejo integration: https://www.authelia.com/integration/openid-connect/gitea/
    # For Forgejo config: https://forgejo.org/docs/latest/admin/config-cheat-sheet
    # For cli info: https://docs.gitea.com/usage/command-line
    (mkIf (cfg.enable && cfg.sso.enable != false) {
      assertions = [
        {
          assertion = cfg.ldap.enable == true;
          message = "'shb.forgejo.ldap.enable' must be set to true and ldap configured when 'shb.forgejo.sso.enable' is true. Otherwise you will never be able to register new accounts.";
        }
      ];

      services.forgejo.settings = {
        oauth2 = {
          ENABLED = true;
        };

        openid = {
          ENABLE_OPENID_SIGNIN = false;
          ENABLE_OPENID_SIGNUP = true;
          WHITELISTED_URIS = cfg.sso.endpoint;
        };

        service = {
          # DISABLE_REGISTRATION = mkForce false;
          # ALLOW_ONLY_EXTERNAL_REGISTRATION = false;
          SHOW_REGISTRATION_BUTTON = false;
        };
      };

      # The delimiter in the `cut` command is a TAB!
      systemd.services.forgejo.preStart =
        let
          provider = "SHB-${cfg.sso.provider}";
        in
        ''
          auth="${getExe config.services.forgejo.package} admin auth"

          echo "Trying to find existing sso configuration for ${provider}"...
          set +e -o pipefail
          id="$($auth list | grep "${provider}.*OAuth2" |  cut -d'	' -f1)"
          found=$?
          set -e +o pipefail

          if [[ $found = 0 ]]; then
            echo Found sso configuration at id=$id, updating it if needed.
            $auth update-oauth \
              --id       $id \
              --name     ${provider} \
              --provider openidConnect \
              --key      forgejo \
              --secret   $(tr -d '\n' < ${cfg.sso.sharedSecret.result.path}) \
              --auto-discover-url ${cfg.sso.endpoint}/.well-known/openid-configuration
          else
            echo Did not find any sso configuration, creating one with name ${provider}.
            $auth add-oauth \
              --name     ${provider} \
              --provider openidConnect \
              --key      forgejo \
              --secret   $(tr -d '\n' < ${cfg.sso.sharedSecret.result.path}) \
              --auto-discover-url ${cfg.sso.endpoint}/.well-known/openid-configuration
          fi
        '';

      shb.authelia.oidcClients = lists.optionals (!(isNull cfg.sso)) [
        (
          let
            provider = "SHB-${cfg.sso.provider}";
          in
          {
            client_id = cfg.sso.clientID;
            client_name = "Forgejo";
            client_secret.source = cfg.sso.sharedSecretForAuthelia.result.path;
            public = false;
            authorization_policy = cfg.sso.authorization_policy;
            redirect_uris = [ "https://${cfg.subdomain}.${cfg.domain}/user/oauth2/${provider}/callback" ];
          }
        )
      ];
    })

    (mkIf cfg.enable {
      assertions = [
        {
          assertion = all (u: u != "admin") (attrNames cfg.users);
          message = "Username cannot be 'admin'.";
        }
      ];

      systemd.services.forgejo.preStart = ''
        admin="${getExe config.services.forgejo.package} admin user"
      ''
      + concatMapStringsSep "\n" (u: ''
        if ! $admin list | grep "${u.name}"; then
          $admin create ${optionalString u.value.isAdmin "--admin"} --email "${u.value.email}" --must-change-password=false --username "${u.name}" --password "$(tr -d '\n' < ${u.value.password.result.path})"
        else
          $admin change-password --must-change-password=false --username "${u.name}" --password "$(tr -d '\n' < ${u.value.password.result.path})"
        fi
      '') (mapAttrsToList nameValuePair cfg.users);
    })

    (mkIf (cfg.enable && cfg.smtp != null) {
      services.forgejo.settings.mailer = {
        ENABLED = true;
        SMTP_ADDR = "${cfg.smtp.host}:${toString cfg.smtp.port}";
        FROM = cfg.smtp.from_address;
        USER = cfg.smtp.username;
        PASSWD = cfg.smtp.password.result.path;
      };
    })

    (mkIf cfg.enable {
      services.forgejo.settings.actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "github";
      };
    })

    (mkIf (cfg.enable && cfg.localActionRunner) (
      let
        # Store the identity with Forgejo's persistent, backed-up data. Publishing
        # identityDir completes initialization or explicit migration once.
        registrationDir = "${config.services.forgejo.customDir}/runner-registration";
        identityDir = "${registrationDir}/initialized";
        legacyDir = "/var/lib/gitea-runner/local";
        uuidPlaceholder = "@UUID@";
        runtimeConfig = "./config.yaml";
        forgejoActions = "${getExe config.services.forgejo.package} forgejo-cli actions";
        runner = config.services.forgejo-runner;
      in
      {
        assertions = [
          {
            assertion = lib.path.hasPrefix (/. + config.services.forgejo.stateDir) (
              /. + config.services.forgejo.customDir
            );
            message = "shb.forgejo.localActionRunner requires services.forgejo.customDir to be inside services.forgejo.stateDir so runner identity is covered by shb.forgejo.mount.";
          }
        ];

        environment.systemPackages = [
          (pkgs.callPackage ./forgejo/migrate-runner.nix {
            inherit registrationDir identityDir legacyDir;
            user = config.services.forgejo.user;
          })
        ];

        system.preSwitchChecks.shb-forgejo-runner-migration = ''
          if { [ -e ${lib.escapeShellArg legacyDir} ] || [ -L ${lib.escapeShellArg legacyDir} ]; } \
            && [ ! -e ${lib.escapeShellArg identityDir} ]; then
            echo "The local Forgejo runner must be migrated before activating this configuration." >&2
            echo "Run as root, then retry activation:" >&2
            echo "  systemctl stop gitea-runner-local.service" >&2
            echo "  $1/sw/bin/shb-forgejo-runner-migrate" >&2
            exit 1
          fi
        '';

        # Use the native module for runner configuration, credentials and service hardening.
        # https://wiki.nixos.org/wiki/Forgejo#Actions_Runner
        services.forgejo-runner = {
          instances.local = {
            enable = true;
            settings = {
              runner.labels = [ "native:host" ];
              server.connections.default = {
                url = "${if cfg.ssl != null then "https" else "http"}://${cfg.subdomain}.${cfg.domain}";
                uuid = uuidPlaceholder;
              };
            };
            secrets.server.connections.default.token_url = "${identityDir}/token";
            inherit (cfg) hostPackages;
          };
        };

        # Forgejo's offline registration is idempotent when reusing the same secret.
        # https://forgejo.org/docs/v15.0/admin/command-line/#forgejo-cli-actions-register
        # SHB retains that secret across interrupted attempts and publishes UUID/token
        # together, then skips initialization once the identity has been saved.
        systemd.services.forgejo-runner-initialize = {
          description = "Initialize a new local Forgejo runner once";
          wants = [ "forgejo.service" ];
          after = [ "forgejo.service" ];
          unitConfig = {
            # Wait for persistent storage before checking or creating the identity.
            RequiresMountsFor = [ config.services.forgejo.customDir ];
            # A completed initialization or migration skips this service on later boots.
            ConditionPathExists = "!${identityDir}";
            # Existing installations must use the explicit migration command instead.
            # PID 1 can check the legacy DynamicUser directory; the Forgejo user cannot.
            AssertPathExists = "!${legacyDir}";
            AssertPathIsSymbolicLink = "!${legacyDir}";
          };
          path = [ pkgs.coreutils ];
          environment = {
            # Point the offline CLI at the running Forgejo instance's configuration and database.
            FORGEJO_WORK_DIR = config.services.forgejo.stateDir;
            FORGEJO_CUSTOM = config.services.forgejo.customDir;
          };
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = config.services.forgejo.user;
            Group = config.services.forgejo.group;
            # New credential files must only be readable by the Forgejo user.
            UMask = "0077";
          };
          script = ''
            # Stop on errors, including a failed registration command inside the pipeline.
            set -euo pipefail

            # Create the private parent directory on Forgejo's persistent storage.
            install --directory --mode=0700 ${lib.escapeShellArg registrationDir}
            cd ${lib.escapeShellArg registrationDir}
            # Keep unfinished work across failures so retries can reuse the same secret.
            # Stage beside the destination so the final rename stays on one filesystem.
            mkdir -p initializing
            cd initializing

            # Generate a secret only when none has been saved. Rename it into place only
            # after generation succeeds, so a partial write cannot become the saved token.
            if [ ! -e token ]; then
              ${forgejoActions} generate-secret > token.new
              mv token.new token
            fi
            # Refuse an empty saved token instead of silently replacing the runner's identity.
            test -s token

            # Register through Forgejo's offline CLI, keeping the secret out of process arguments.
            # Retrying with the saved secret returns the same runner's UUID. Store the UUID
            # without the CLI's trailing newline for substitution into the runner's YAML.
            ${forgejoActions} register --name local --secret-stdin=true < token | tr -d '\n' > uuid
            # Do not publish an identity if registration returned no UUID.
            test -s uuid

            # Publish both credentials together in one atomic rename. This directory also
            # tells ConditionPathExists above that initialization must not run again.
            mv --no-target-directory ${lib.escapeShellArg "${registrationDir}/initializing"} ${lib.escapeShellArg identityDir}
          '';
        };

        # The runner's UUID is saved on the target machine, but Forgejo Runner requires
        # it inline in YAML; only its token supports loading from a file. Substitute the
        # saved UUID into a runtime config copy, following the native module's test.
        # Remove this workaround when Forgejo Runner supports uuid_url alongside token_url.
        # https://github.com/NixOS/nixpkgs/blob/5e867b1db0f219e0e906574cca1175f421a87834/nixos/tests/forgejo.nix#L102-L113
        systemd.services.forgejo-runner-local = {
          requires = [ "forgejo-runner-initialize.service" ];
          wants = [ "nginx.service" ];
          after = [
            "forgejo-runner-initialize.service"
            "gitea-runner-local.service"
            "nginx.service"
          ];
          conflicts = [ "gitea-runner-local.service" ];
          preStart = ''
            # Replace the read-only file left by a previous start.
            install -m 600 ${runner.instances.local.configFile} ${lib.escapeShellArg runtimeConfig}
            ${getExe pkgs.replace-secret} ${lib.escapeShellArg uuidPlaceholder} "$CREDENTIALS_DIRECTORY/UUID" ${lib.escapeShellArg runtimeConfig}
            chmod u-w ${lib.escapeShellArg runtimeConfig}
            # Wait for the API before the runner's first declaration.
            ${getExe pkgs.curl} --fail --silent --show-error --output /dev/null \
              --retry 30 --retry-delay 1 --retry-all-errors --retry-max-time 30 --max-time 2 \
              ${lib.escapeShellArg "${runner.instances.local.settings.server.connections.default.url}/api/healthz"}
          '';
          serviceConfig = {
            ExecStart = mkForce "${getExe runner.package} daemon --config ${runtimeConfig}";
            LoadCredential = [ "UUID:${identityDir}/uuid" ];
          };
        };
      }
    ))
  ];
}
