{ config, options, pkgs, lib, ... }:

let
  cfg = config.shb.forgejo;

  contracts = pkgs.callPackage ../contracts {};

  inherit (lib) getExe lists literalExpression mkBefore mkEnableOption mkForce mkIf mkMerge mkOption mkOverride optionals;
  inherit (lib.types) bool enum listOf nullOr package port submodule str;
in
{
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
      type = nullOr contracts.ssl.certs;
      default = null;
    };

    ldap = mkOption {
      description = ''
        LDAP Integration.
      '';
      default = {};
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
            description = "Admin user of the LDAP server.";
            default = "admin";
          };

          adminPassword = mkOption {
            description = "LDAP admin password.";
            type = submodule {
              options = contracts.secret.mkRequester {
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
        };
      });
    };

    sso = mkOption {
      description = ''
        Setup SSO integration.
      '';
      default = {};
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
            type = enum [ "one_factor" "two_factor" ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };

          sharedSecret = mkOption {
            description = "OIDC shared secret for Forgejo.";
            type = submodule {
              options = contracts.secret.mkRequester {
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
              options = contracts.secret.mkRequester {
                mode = "0400";
                owner = "authelia";
              };
            };
          };
        };
      };
    };

    adminPassword = mkOption {
      description = "File containing the Forgejo admin user password.";
      type = submodule {
        options = contracts.secret.mkRequester {
          mode = "0440";
          owner = "forgejo";
          group = "forgejo";
          restartUnits = [ "forgejo.service" ];
        };
      };
    };

    databasePassword = mkOption {
      description = "File containing the Forgejo database password.";
      type = submodule {
        options = contracts.secret.mkRequester {
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
      type = contracts.backup.request;
      description = ''
        Backup configuration. This is an output option.

        Use it to initialize a block implementing the "backup" contract.
        For example, with the restic block:

        ```
        shb.restic.instances."forgejo" = {
          request = config.shb.forgejo.backup;
          settings = {
            enable = true;
          };
        };
        ```
      '';
      readOnly = true;
      default = {
        user = options.services.forgejo.user.value;
        sourceDirectories = [
          options.services.forgejo.dump.backupDir.value
        ] ++ optionals (cfg.repositoryRoot != null) [
          cfg.repositoryRoot
        ];
      };
    };

    mount = mkOption {
      type = contracts.mount;
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
      default = { path = config.services.forgejo.stateDir; };
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
          passwordFile = mkOption {
            type = str;
            description = "File containing the password to connect to the SMTP host.";
          };
        };
      });
    };

    debug = mkOption {
      description = "Enable debug logging.";
      type = bool;
      default = false;
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

      shb.nginx.vhosts = [{
        inherit (cfg) domain subdomain ssl;
        upstream = "http://unix:${config.services.forgejo.settings.server.HTTP_ADDR}";
      }];
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
    })

    # For Forgejo setup: https://github.com/lldap/lldap/blob/main/example_configs/gitea.md
    # For cli info: https://docs.gitea.com/usage/command-line
    # Security protocols in: https://codeberg.org/forgejo/forgejo/src/branch/forgejo/services/auth/source/ldap/security_protocol.go#L27-L31
    (mkIf (cfg.enable && cfg.ldap.enable != false) {
      # The delimiter in the `cut` command is a TAB!
      systemd.services.forgejo.preStart = let
        provider = "SHB-${cfg.ldap.provider}";
      in ''
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
            --user-filter         '(&(memberof=cn=${cfg.ldap.userGroup},ou=groups,${cfg.ldap.dcdomain})(|(uid=%[1]s)(mail=%[1]s)))' \
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
            --user-filter         '(&(memberof=cn=${cfg.ldap.userGroup},ou=groups,${cfg.ldap.dcdomain})(|(uid=%[1]s)(mail=%[1]s)))' \
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
      systemd.services.forgejo.preStart = let
        provider = "SHB-${cfg.sso.provider}";
      in ''
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
        (let
          provider = "SHB-${cfg.sso.provider}";
        in {
          client_id = cfg.sso.clientID;
          client_name = "Forgejo";
          client_secret.source = cfg.sso.sharedSecretForAuthelia.result.path;
          public = false;
          authorization_policy = cfg.sso.authorization_policy;
          redirect_uris = [ "https://${cfg.subdomain}.${cfg.domain}/user/oauth2/${provider}/callback" ];
        })
      ];
    })

    (mkIf cfg.enable {
      systemd.services.forgejo.preStart = ''
        admin="${getExe config.services.forgejo.package} admin user"
        $admin create --admin --email "root@localhost" --username meadmin --password "$(tr -d '\n' < ${cfg.adminPassword.result.path})" || true
        $admin change-password --username meadmin --password "$(tr -d '\n' < ${cfg.adminPassword.result.path})" || true
'';
    })

    (mkIf (cfg.enable && cfg.smtp != null) {
      services.forgejo.settings.mailer = {
        ENABLED = true;
        SMTP_ADDR = "${cfg.smtp.host}:${toString cfg.smtp.port}";
        FROM = cfg.smtp.from_address;
        USER = cfg.smtp.username;
      };

      services.forgejo.mailerPasswordFile = cfg.smtp.passwordFile;
    })

    # https://wiki.nixos.org/wiki/Forgejo#Runner
    (mkIf cfg.enable {
      services.forgejo.settings.actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "github";
      };

      services.gitea-actions-runner = mkIf cfg.localActionRunner {
        package = pkgs.forgejo-actions-runner;
        instances.local = {
          enable = true;
          name = "local";
          url = let
            protocol = if cfg.ssl != null then "https" else "http";
          in "${protocol}://${cfg.subdomain}.${cfg.domain}";
          tokenFile = ""; # Empty variable to satisfy an assertion.
          labels = [
            # "ubuntu-latest:docker://node:16-bullseye"
            # "ubuntu-22.04:docker://node:16-bullseye"
            # "ubuntu-20.04:docker://node:16-bullseye"
            # "ubuntu-18.04:docker://node:16-buster"     
            "native:host"
          ];
          inherit (cfg) hostPackages;
        };
      };

      # This combined with the next statement takes care of
      # automatically registering a forgejo runner.
      systemd.services.forgejo.postStart = mkIf cfg.localActionRunner (mkBefore ''
        ${pkgs.bash}/bin/bash -c '(while ! ${pkgs.netcat-openbsd}/bin/nc -z -U ${config.services.forgejo.settings.server.HTTP_ADDR}; do echo "Waiting for unix ${config.services.forgejo.settings.server.HTTP_ADDR} to open..."; sleep 2; done); sleep 2'
        actions="${getExe config.services.forgejo.package} actions"
        echo -n TOKEN= > /run/forgejo/forgejo-runner-token
        $actions generate-runner-token >> /run/forgejo/forgejo-runner-token
      '');

      systemd.services.gitea-runner-local.serviceConfig = {
        # LoadCredential = "TOKEN_FILE:/run/forgejo/forgejo-runner-token";
        # EnvironmentFile = [ "$CREDENTIALS_DIRECTORY/TOKEN_FILE" ];
        EnvironmentFile = [ "/run/forgejo/forgejo-runner-token" ];
      };

      systemd.services.gitea-runner-local.wants = [ "forgejo.service" ];
      systemd.services.gitea-runner-local.after = [ "forgejo.service" ];
    })
  ];
}
