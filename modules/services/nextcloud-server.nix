{ config, pkgs, lib, ... }:

let
  cfg = config.shb.nextcloud;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
  fqdnWithPort = if isNull cfg.port then fqdn else "${fqdn}:${toString cfg.port}";
  protocol = if !(isNull cfg.ssl) then "https" else "http";

  ssoFqdnWithPort = if isNull cfg.apps.sso.port then cfg.apps.sso.endpoint else "${cfg.apps.sso.endpoint}:${toString cfg.apps.sso.port}";

  contracts = pkgs.callPackage ../contracts {};

  # Make sure to bump both nextcloudPkg and nextcloudApps at the same time.
  nextcloudPkg = version: builtins.getAttr ("nextcloud" + builtins.toString version) pkgs;
  nextcloudApps = version: (builtins.getAttr ("nextcloud" + builtins.toString version + "Packages") pkgs).apps;

  occ = "${config.services.nextcloud.occ}/bin/nextcloud-occ";
in
{
  options.shb.nextcloud = {
    enable = lib.mkEnableOption "selfhostblocks.nextcloud-server";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = ''
        Subdomain under which Nextcloud will be served.

        ```
        <subdomain>.<domain>[:<port>]
        ```
      '';
      example = "nextcloud";
    };

    domain = lib.mkOption {
      description = ''
        Domain under which Nextcloud is served.

        ```
        <subdomain>.<domain>[:<port>]
        ```
      '';
      type = lib.types.str;
      example = "domain.com";
    };

    port = lib.mkOption {
      description = ''
        Port under which Nextcloud will be served. If null is given, then the port is omitted.

        ```
        <subdomain>.<domain>[:<port>]
        ```
      '';
      type = lib.types.nullOr lib.types.port;
      default = null;
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    externalFqdn = lib.mkOption {
      description = "External fqdn used to access Nextcloud. Defaults to <subdomain>.<domain>. This should only be set if you include the port when accessing Nextcloud.";
      type = lib.types.nullOr lib.types.str;
      example = "nextcloud.domain.com:8080";
      default = null;
    };

    version = lib.mkOption {
      description = "Nextcloud version to choose from.";
      type = lib.types.enum [ 27 28 ];
      default = 27;
    };

    dataDir = lib.mkOption {
      description = "Folder where Nextcloud will store all its data.";
      type = lib.types.str;
      default = "/var/lib/nextcloud";
    };

    mountPointServices = lib.mkOption {
      description = "If given, all the systemd services and timers will depend on the specified mount point systemd services.";
      type = lib.types.listOf lib.types.str;
      default = [];
      example = lib.literalExpression ''["var.mount"]'';
    };

    adminUser = lib.mkOption {
      type = lib.types.str;
      description = "Username of the initial admin user.";
      default = "root";
    };

    adminPassFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      description = "File containing the Nextcloud admin password. Required.";
      default = null;
    };

    maxUploadSize = lib.mkOption {
      default = "4G";
      type = lib.types.str;
      description = ''
        The upload limit for files. This changes the relevant options
        in php.ini and nginx if enabled.
      '';
    };

    defaultPhoneRegion = lib.mkOption {
      type = lib.types.str;
      description = ''
        Two letters region defining default region.
      '';
      example = "US";
    };

    postgresSettings = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
      default = null;
      description = "Settings for the PostgreSQL database. Go to https://pgtune.leopard.in.ua/ and copy the generated configuration here.";
      example = lib.literalExpression ''
      {
        # From https://pgtune.leopard.in.ua/ with:

        # DB Version: 14
        # OS Type: linux
        # DB Type: dw
        # Total Memory (RAM): 7 GB
        # CPUs num: 4
        # Connections num: 100
        # Data Storage: ssd

        max_connections = "100";
        shared_buffers = "1792MB";
        effective_cache_size = "5376MB";
        maintenance_work_mem = "896MB";
        checkpoint_completion_target = "0.9";
        wal_buffers = "16MB";
        default_statistics_target = "500";
        random_page_cost = "1.1";
        effective_io_concurrency = "200";
        work_mem = "4587kB";
        huge_pages = "off";
        min_wal_size = "4GB";
        max_wal_size = "16GB";
        max_worker_processes = "4";
        max_parallel_workers_per_gather = "2";
        max_parallel_workers = "4";
        max_parallel_maintenance_workers = "2";
      }
      '';
    };

    phpFpmPoolSettings = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
      description = "Settings for PHPFPM.";
      default = null;
      example = lib.literalExpression ''
      {
        "pm" = "dynamic";
        "pm.max_children" = 50;
        "pm.start_servers" = 25;
        "pm.min_spare_servers" = 10;
        "pm.max_spare_servers" = 20;
        "pm.max_spawn_rate" = 50;
        "pm.max_requests" = 50;
        "pm.process_idle_timeout" = "20s";
      }
      '';
    };

    apps = lib.mkOption {
      description = ''
        Applications to enable in Nextcloud. Enabling an application here will also configure
        various services needed for this application.

        Enabled apps will automatically be installed, enabled and configured, so no need to do that
        through the UI. You can still make changes but they will be overridden on next deploy. You
        can still install and configure other apps through the UI.
      '';
      default = {};
      type = lib.types.submodule {
        options = {
          onlyoffice = lib.mkOption {
            description = ''
              Only Office App. [Nextcloud App Store](https://apps.nextcloud.com/apps/onlyoffice)

              Enabling this app will also start an OnlyOffice instance accessible at the given
              subdomain from the given network range.
            '';
            default = {};
            type = lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "Nextcloud OnlyOffice App";

                subdomain = lib.mkOption {
                  type = lib.types.str;
                  description = "Subdomain under which Only Office will be served.";
                  default = "oo";
                };

                ssl = lib.mkOption {
                  description = "Path to SSL files";
                  type = lib.types.nullOr contracts.ssl.certs;
                  default = null;
                };

                localNetworkIPRange = lib.mkOption {
                  type = lib.types.str;
                  description = "Local network range, to restrict access to Open Office to only those IPs.";
                  default = "192.168.1.1/24";
                };

                jwtSecretFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  description = ''
                    File containing the JWT secret. This option is required.

                    Must be readable by the nextcloud system user.
                  '';
                  default = null;
                };
              };
            };
          };

          previewgenerator = lib.mkOption {
            description = ''
              Preview Generator App. [Nextcloud App Store](https://apps.nextcloud.com/apps/previewgenerator)

              Enabling this app will create a cron job running every minute to generate thumbnails
              for new and updated files.

              To generate thumbnails for already existing files, run:

              ```
              nextcloud-occ -vvv preview:generate-all
              ```
            '';
            default = {};
            type = lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "Nextcloud Preview Generator App";

                recommendedSettings = lib.mkOption {
                  type = lib.types.bool;
                  description = ''
                    Better defaults than the defaults. Taken from [this article](http://web.archive.org/web/20200513043150/https://ownyourbits.com/2019/06/29/understanding-and-improving-nextcloud-previews/).

                    Sets the following options:

                    ```
                    nextcloud-occ config:app:set previewgenerator squareSizes --value="32 256"
                    nextcloud-occ config:app:set previewgenerator widthSizes  --value="256 384"
                    nextcloud-occ config:app:set previewgenerator heightSizes --value="256"
                    nextcloud-occ config:system:set preview_max_x --value 2048
                    nextcloud-occ config:system:set preview_max_y --value 2048
                    nextcloud-occ config:system:set jpeg_quality --value 60
                    nextcloud-occ config:app:set preview jpeg_quality --value="60"
                    ```
                  '';
                  default = true;
                  example = false;
                };

                debug = lib.mkOption {
                  type = lib.types.bool;
                  description = "Enable more verbose logging.";
                  default = false;
                  example = true;
                };
              };
            };
          };

          ldap = lib.mkOption {
            description = ''
              LDAP Integration App. [Manual](https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_auth_ldap.html)

              Enabling this app will create a new LDAP configuration or update one that exists with
              the given host.
            '';
            default = {};
            type = lib.types.nullOr (lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "LDAP app.";

                host = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    Host serving the LDAP server.
                  '';
                  default = "127.0.0.1";
                };

                port = lib.mkOption {
                  type = lib.types.port;
                  description = ''
                    Port of the service serving the LDAP server.
                  '';
                  default = 389;
                };

                dcdomain = lib.mkOption {
                  type = lib.types.str;
                  description = "dc domain for ldap.";
                  example = "dc=mydomain,dc=com";
                };

                adminName = lib.mkOption {
                  type = lib.types.str;
                  description = "Admin user of the LDAP server.";
                  default = "admin";
                };

                adminPasswordFile = lib.mkOption {
                  type = lib.types.path;
                  description = ''
                    File containing the admin password of the LDAP server.

                    Must be readable by the nextcloud system user.
                  '';
                  default = "";
                };

                userGroup = lib.mkOption {
                  type = lib.types.str;
                  description = "Group users must belong to to be able to login to Nextcloud.";
                  default = "nextcloud_user";
                };
              };
            });
          };

          sso = lib.mkOption {
            description = ''
              SSO Integration App. [Manual](https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/oidc_auth.html)

              Enabling this app will create a new LDAP configuration or update one that exists with
              the given host.
            '';
            default = {};
            type = lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "SSO app.";

                endpoint = lib.mkOption {
                  type = lib.types.str;
                  description = "OIDC endpoint for SSO.";
                  example = "https://authelia.example.com";
                };

                port = lib.mkOption {
                  description = "If given, adds a port to the endpoint.";
                  type = lib.types.nullOr lib.types.port;
                  default = null;
                };

                provider = lib.mkOption {
                  type = lib.types.enum [ "Authelia" ];
                  description = "OIDC provider name, used for display.";
                  default = "Authelia";
                };

                clientID = lib.mkOption {
                  type = lib.types.str;
                  description = "Client ID for the OIDC endpoint.";
                  default = "nextcloud";
                };

                authorization_policy = lib.mkOption {
                  type = lib.types.enum [ "one_factor" "two_factor" ];
                  description = "Require one factor (password) or two factor (device) authentication.";
                  default = "one_factor";
                };

                secretFile = lib.mkOption {
                  type = lib.types.path;
                  description = ''
                    File containing the secret for the OIDC endpoint.

                    Must be readable by the nextcloud system user.
                  '';
                  default = "";
                };

                secretFileForAuthelia = lib.mkOption {
                  type = lib.types.path;
                  description = ''
                    File containing the secret for the OIDC endpoint, must be readable by the Authelia user.

                    Must be readable by the authelia system user.
                  '';
                  default = "";
                };

                fallbackDefaultAuth = lib.mkOption {
                  type = lib.types.bool;
                  description = ''
                    Fallback to normal Nextcloud auth if something goes wrong with the SSO app.
                    Usually, you want to enable this to transfer existing users to LDAP and then you
                    can disabled it.
                  '';
                  default = false;
                };
              };
            };
          };
        };
      };
    };

    extraApps = lib.mkOption {
      type = lib.types.raw;
      description = ''
        Extra apps to install. Should be a function returning an attrSet of appid to packages
        generated by fetchNextcloudApp. The appid must be identical to the “id” value in the apps
        appinfo/info.xml. You can still install apps through the appstore.
      '';
      default = null;
      example = lib.literalExpression ''
        apps: {
          inherit (apps) mail calendar contact;
          phonetrack = pkgs.fetchNextcloudApp {
            name = "phonetrack";
            sha256 = "0qf366vbahyl27p9mshfma1as4nvql6w75zy2zk5xwwbp343vsbc";
            url = "https://gitlab.com/eneiluj/phonetrack-oc/-/wikis/uploads/931aaaf8dca24bf31a7e169a83c17235/phonetrack-0.6.9.tar.gz";
            version = "0.6.9";
          };
        }
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      description = "Enable more verbose logging.";
      default = false;
      example = true;
    };

    tracing = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = ''
        Enable xdebug tracing.

        To trigger writing a trace to `/var/log/xdebug`, add a the following header:

        ```
        XDEBUG_TRACE <shb.nextcloud.tracing value>
        ```

        The response will contain the following header:

        ```
        x-xdebug-profile-filename /var/log/xdebug/cachegrind.out.63484
        ```
      '';
      default = null;
      example = "debug_me";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !(isNull cfg.adminPassFile);
          message = "Must set shb.nextcloud.adminPassFile.";
        }
      ];

      users.users = {
        nextcloud = {
          name = "nextcloud";
          group = "nextcloud";
          isSystemUser = true;
        };
      };

      users.groups = {
        nextcloud = {
          members = [ "backup" ];
        };
      };

      # LDAP is manually configured through
      # https://github.com/lldap/lldap/blob/main/example_configs/nextcloud.md, see also
      # https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_auth_ldap.html
      #
      # Verify setup with:
      #  - On admin page
      #  - https://scan.nextcloud.com/
      #  - https://www.ssllabs.com/ssltest/
      # As of writing this, we got no warning on admin page and A+ on both tests.
      #
      # Content-Security-Policy is hard. I spent so much trying to fix lingering issues with .js files
      # not loading to realize those scripts are inserted by extensions. Doh.
      services.nextcloud = {
        enable = true;
        package = nextcloudPkg cfg.version;

        datadir = cfg.dataDir;

        hostName = fqdn;
        nginx.hstsMaxAge = 31536000; # Needs > 1 year for https://hstspreload.org to be happy

        inherit (cfg) maxUploadSize;

        config = {
          dbtype = "pgsql";
          adminuser = cfg.adminUser;
          adminpassFile = toString cfg.adminPassFile;
        };
        database.createLocally = true;

        # Enable caching using redis https://nixos.wiki/wiki/Nextcloud#Caching.
        configureRedis = true;
        caching.apcu = false;
        # https://docs.nextcloud.com/server/26/admin_manual/configuration_server/caching_configuration.html
        caching.redis = true;

        # Adds appropriate nginx rewrite rules.
        webfinger = true;

        # Very important for a bunch of scripts to load correctly. Otherwise you get Content-Security-Policy errors. See https://docs.nextcloud.com/server/13/admin_manual/configuration_server/harden_server.html#enable-http-strict-transport-security
        https = !(isNull cfg.ssl);

        extraApps = if isNull cfg.extraApps then {} else cfg.extraApps (nextcloudApps cfg.version);
        extraAppsEnable = true;
        appstoreEnable = true;

        settings = let
          protocol = if !(isNull cfg.ssl) then "https" else "http";
        in {
          "default_phone_region" = cfg.defaultPhoneRegion;

          "overwrite.cli.url" = "${protocol}://${fqdn}";
          "overwritehost" = fqdnWithPort;
          # 'trusted_domains' needed otherwise we get this issue https://help.nextcloud.com/t/the-polling-url-does-not-start-with-https-despite-the-login-url-started-with-https/137576/2
          # TODO: could instead set extraTrustedDomains
          "trusted_domains" = [ fqdn ];
          "trusted_proxies" = [ "127.0.0.1" ];
          # TODO: could instead set overwriteProtocol
          "overwriteprotocol" = protocol; # Needed if behind a reverse_proxy
          "overwritecondaddr" = ""; # We need to set it to empty otherwise overwriteprotocol does not work.
          "debug" = cfg.debug;
          "filelocking.debug" = cfg.debug;

          # Use persistent SQL connections.
          "dbpersistent" = "true";
        };

        phpOptions = {
          # The OPcache interned strings buffer is nearly full with 8, bump to 16.
          catch_workers_output = "yes";
          display_errors = "stderr";
          error_reporting = "E_ALL & ~E_DEPRECATED & ~E_STRICT";
          expose_php = "Off";
          "opcache.enable_cli" = "1";
          "opcache.fast_shutdown" = "1";
          "opcache.interned_strings_buffer" = "16";
          "opcache.max_accelerated_files" = "10000";
          "opcache.memory_consumption" = "128";
          "opcache.revalidate_freq" = "1";
          short_open_tag = "Off";

          output_buffering = "Off";

          # Needed to avoid corruption per https://docs.nextcloud.com/server/21/admin_manual/configuration_server/caching_configuration.html#id2
          "redis.session.locking_enabled" = "1";
          "redis.session.lock_retries" = "-1";
          "redis.session.lock_wait_time" = "10000";
        } // lib.optionalAttrs (! (isNull cfg.tracing)) {
          # "xdebug.remote_enable" = "on";
          # "xdebug.remote_host" = "127.0.0.1";
          # "xdebug.remote_port" = "9000";
          # "xdebug.remote_handler" = "dbgp";
          "xdebug.trigger_value" = cfg.tracing;

          "xdebug.mode" = "profile,trace";
          "xdebug.output_dir" = "/var/log/xdebug";
          "xdebug.start_with_request" = "trigger";
        };

        poolSettings = lib.mkIf (! (isNull cfg.phpFpmPoolSettings)) cfg.phpFpmPoolSettings;

        phpExtraExtensions = all: [ all.xdebug ];
      };

      services.nginx.virtualHosts.${fqdn} = {
        # listen = [ { addr = "0.0.0.0"; port = 443; } ];
        forceSSL = !(isNull cfg.ssl);
        sslCertificate = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.cert;
        sslCertificateKey = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.key;

        # From [1] this should fix downloading of big files. [2] seems to indicate that buffering
        # happens at multiple places anyway, so disabling one place should be okay.
        # [1]: https://help.nextcloud.com/t/download-aborts-after-time-or-large-file/25044/6
        # [2]: https://stackoverflow.com/a/50891625/1013628
        extraConfig = ''
        proxy_buffering off;
        '';
      };

      environment.systemPackages = [
        # Needed for a few apps. Would be nice to avoid having to put that in the environment and instead override https://github.com/NixOS/nixpkgs/blob/261abe8a44a7e8392598d038d2e01f7b33cf26d0/nixos/modules/services/web-apps/nextcloud.nix#L1035
        pkgs.ffmpeg-headless

        # Needed for the recognize app.
        pkgs.nodejs
      ];

      services.postgresql.settings = lib.mkIf (! (isNull cfg.postgresSettings)) cfg.postgresSettings;

      systemd.services.phpfpm-nextcloud.serviceConfig = {
        # Setup permissions needed for backups, as the backup user is member of the jellyfin group.
        UMask = lib.mkForce "0027";
      };
      systemd.services.phpfpm-nextcloud.preStart = ''
      mkdir -p /var/log/xdebug; chown -R nextcloud: /var/log/xdebug
      '';
      systemd.services.phpfpm-nextcloud.requires = cfg.mountPointServices;
      systemd.services.phpfpm-nextcloud.after = cfg.mountPointServices;

      systemd.services.nextcloud-cron.path = [
        pkgs.perl
      ];
      systemd.timers.nextcloud-cron.requires = cfg.mountPointServices;
      systemd.timers.nextcloud-cron.after = cfg.mountPointServices;

      systemd.services.nextcloud-setup.requires = cfg.mountPointServices;
      systemd.services.nextcloud-setup.after = cfg.mountPointServices;

      # Sets up backup for Nextcloud.
      shb.backup.instances.nextcloud = {
        sourceDirectories = [
          cfg.dataDir
        ];
        excludePatterns = [".rnd"];
      };
    })

    (lib.mkIf cfg.apps.onlyoffice.enable {
      assertions = [
        {
          assertion = !(isNull cfg.apps.onlyoffice.jwtSecretFile);
          message = "Must set shb.nextcloud.apps.onlyoffice.jwtSecretFile.";
        }
      ];

      services.nextcloud.extraApps = {
        inherit ((nextcloudApps cfg.version)) onlyoffice;
      };

      services.onlyoffice = {
        enable = true;
        hostname = "${cfg.apps.onlyoffice.subdomain}.${cfg.domain}";
        port = 13444;

        postgresHost = "/run/postgresql";

        jwtSecretFile = cfg.apps.onlyoffice.jwtSecretFile;
      };

      services.nginx.virtualHosts."${cfg.apps.onlyoffice.subdomain}.${cfg.domain}" = {
        forceSSL = !(isNull cfg.ssl);
        sslCertificate = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.cert;
        sslCertificateKey = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.key;

        locations."/" = {
          extraConfig = ''
          allow ${cfg.apps.onlyoffice.localNetworkIPRange};
          '';
        };
      };
    })

    (lib.mkIf cfg.apps.previewgenerator.enable {
      services.nextcloud.extraApps = {
        inherit ((nextcloudApps cfg.version)) previewgenerator;
      };

      # Values taken from
      # http://web.archive.org/web/20200513043150/https://ownyourbits.com/2019/06/29/understanding-and-improving-nextcloud-previews/
      systemd.services.nextcloud-setup.script = lib.mkIf cfg.apps.previewgenerator.recommendedSettings ''
        ${occ} config:app:set previewgenerator squareSizes --value="32 256"
        ${occ} config:app:set previewgenerator widthSizes  --value="256 384"
        ${occ} config:app:set previewgenerator heightSizes --value="256"
        ${occ} config:system:set preview_max_x --value 2048
        ${occ} config:system:set preview_max_y --value 2048
        ${occ} config:system:set jpeg_quality --value 60
        ${occ} config:app:set preview jpeg_quality --value="60"
      '';

      # Configured as defined in https://github.com/nextcloud/previewgenerator
      systemd.timers.nextcloud-cron-previewgenerator = {
        wantedBy = [ "timers.target" ];
        requires = cfg.mountPointServices;
        after = [ "nextcloud-setup.service" ] ++ cfg.mountPointServices;
        timerConfig.OnBootSec = "10m";
        timerConfig.OnUnitActiveSec = "10m";
        timerConfig.Unit = "nextcloud-cron-previewgenerator.service";
      };

      systemd.services.nextcloud-cron-previewgenerator = {
        environment.NEXTCLOUD_CONFIG_DIR = "${config.services.nextcloud.datadir}/config";
        serviceConfig.Type = "oneshot";
        serviceConfig.User = "nextcloud";
        serviceConfig.ExecStart =
          let
            debug = if cfg.debug or cfg.apps.previewgenerator.debug then "-vvv" else "";
          in
            "${occ} ${debug} preview:pre-generate";
      };
    })

    (lib.mkIf cfg.apps.ldap.enable {
      systemd.services.nextcloud-setup.path = [ pkgs.jq ];
      systemd.services.nextcloud-setup.script = ''
        ${occ} app:install user_ldap || :
        ${occ} app:enable  user_ldap

        # The following code tries to match an existing config or creates a new one.
        # The criteria for matching is the ldapHost value.

        ALL_CONFIG="$(${occ} ldap:show-config --output=json --show-password)"

        MATCHING_CONFIG_IDs="$(echo "$ALL_CONFIG" | jq '[to_entries[] | select(.value.ldapHost=="127.0.0.1") | .key]')"
        if [[ $(echo "$MATCHING_CONFIG_IDs" | jq 'length') > 0 ]]; then
          CONFIG_ID="$(echo "$MATCHING_CONFIG_IDs" | jq --raw-output '.[0]')"
        else
          CONFIG_ID="$(${occ} ldap:create-empty-config --only-print-prefix)"
        fi

        echo "Using configId $CONFIG_ID"

        # The following CLI commands follow
        # https://github.com/lldap/lldap/blob/main/example_configs/nextcloud.md#nextcloud-config--the-cli-way

        ${occ} ldap:set-config "$CONFIG_ID" 'ldapHost' \
                  '${cfg.apps.ldap.host}'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapPort' \
                  '${toString cfg.apps.ldap.port}'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapAgentName' \
                  'uid=${cfg.apps.ldap.adminName},ou=people,${cfg.apps.ldap.dcdomain}'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapAgentPassword'  \
                  "$(cat ${cfg.apps.ldap.adminPasswordFile})"
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapBase' \
                  '${cfg.apps.ldap.dcdomain}'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapBaseGroups' \
                  '${cfg.apps.ldap.dcdomain}'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapBaseUsers' \
                  '${cfg.apps.ldap.dcdomain}'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapEmailAttribute' \
                  'mail'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupFilter' \
                  '(&(|(objectclass=groupOfUniqueNames))(|(cn=${cfg.apps.ldap.userGroup})))'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupFilterGroups' \
                  '${cfg.apps.ldap.userGroup}'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupFilterObjectclass' \
                  'groupOfUniqueNames'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapGroupMemberAssocAttr' \
                  'uniqueMember'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapLoginFilter' \
                  '(&(&(objectclass=person)(memberOf=cn=${cfg.apps.ldap.userGroup},ou=groups,${cfg.apps.ldap.dcdomain}))(|(uid=%uid)(|(mail=%uid)(objectclass=%uid))))'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapLoginFilterAttributes' \
                  'mail;objectclass'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapUserDisplayName' \
                  'displayname'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapUserFilter' \
                  '(&(objectclass=person)(memberOf=cn=${cfg.apps.ldap.userGroup},ou=groups,${cfg.apps.ldap.dcdomain}))'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapUserFilterMode' \
                  '1'
        ${occ} ldap:set-config "$CONFIG_ID" 'ldapUserFilterObjectclass' \
                  'person'

        ${occ} ldap:test-config -- "$CONFIG_ID"

        # Only one active at the same time

        for configid in $(echo "$ALL_CONFIG" | jq --raw-output "keys[]"); do
          echo "Deactivating $configid"
          ${occ} ldap:set-config "$configid" 'ldapConfigurationActive' \
                    '0'
        done

        ${occ} ldap:set-config "$CONFIG_ID" 'ldapConfigurationActive' \
                  '1'
      '';
    })

    (lib.mkIf cfg.apps.sso.enable {
      assertions = [
        {
          assertion = cfg.apps.sso.enable -> cfg.apps.ldap.enable;
          message = "SSO app requires LDAP app to work correctly.";
        }
      ];

      systemd.services.nextcloud-setup.script =
        ''
        ${occ} app:install oidc_login || :
        ${occ} app:enable  oidc_login
        '';

      systemd.services.nextcloud-setup.preStart =
        ''
        mkdir -p ${cfg.dataDir}/config
        cat <<EOF > "${cfg.dataDir}/config/secretFile"
        {
          "oidc_login_client_secret": "$(cat ${cfg.apps.sso.secretFile})"
        }
        EOF
        '';

      services.nextcloud = {
        secretFile = "${cfg.dataDir}/config/secretFile";

        # See all options at https://github.com/pulsejet/nextcloud-oidc-login
        settings = {
          allow_user_to_change_display_name = false;
          lost_password_link = "disabled";
          oidc_login_provider_url = ssoFqdnWithPort;
          oidc_login_client_id = cfg.apps.sso.clientID;

          # Automatically redirect the login page to the provider.
          oidc_login_auto_redirect = !cfg.apps.sso.fallbackDefaultAuth;
          # Authelia at least does not support this.
          oidc_login_end_session_redirect = false;
          # Redirect to this page after logging out the user
          oidc_login_logout_url = ssoFqdnWithPort;
          oidc_login_button_text = "Log in with ${cfg.apps.sso.provider}";
          oidc_login_hide_password_form = false;
          oidc_login_use_id_token = true;
          oidc_login_attributes = {
            id = "preferred_username";
            name = "name";
            mail = "email";
            groups = "groups";
          };
          oidc_login_default_group = "oidc";
          oidc_login_use_external_storage = false;
          oidc_login_scope = "openid profile email groups";
          oidc_login_proxy_ldap = false;
          # Enable creation of users new to Nextcloud from OIDC login. A user may be known to the
          # IdP but not (yet) known to Nextcloud. This setting controls what to do in this case.
          # * 'true' (default): if the user authenticates to the IdP but is not known to Nextcloud,
          #     then they will be returned to the login screen and not allowed entry;
          # * 'false': if the user authenticates but is not yet known to Nextcloud, then the user
          #     will be automatically created; note that with this setting, you will be allowing (or
          #     relying on) a third-party (the IdP) to create new users
          oidc_login_disable_registration = false;
          oidc_login_redir_fallback = cfg.apps.sso.fallbackDefaultAuth;
          # oidc_login_alt_login_page = "assets/login.php";
          oidc_login_tls_verify = true;
          # If you get your groups from the oidc_login_attributes, you might want to create them if
          # they are not already existing, Default is `false`. This creates groups for all groups
          # the user is associated with in LDAP. It's too much.
          oidc_create_groups = false;
          # Enable use of WebDAV via OIDC bearer token.
          oidc_login_webdav_enabled = true;
          oidc_login_password_authentication = false;
          oidc_login_public_key_caching_time = 86400;
          oidc_login_min_time_between_jwks_requests = 10;
          oidc_login_well_known_caching_time = 86400;
          # If true, nextcloud will download user avatars on login. This may lead to security issues
          # as the server does not control which URLs will be requested. Use with care.
          oidc_login_update_avatar = false;
        };
      };

      shb.authelia.oidcClients = lib.mkIf (cfg.apps.sso.provider == "Authelia") [
        {
          id = cfg.apps.sso.clientID;
          description = "Nextcloud";
          secret.source = cfg.apps.sso.secretFileForAuthelia;
          public = false;
          authorization_policy = cfg.apps.sso.authorization_policy;
          redirect_uris = [ "${protocol}://${fqdnWithPort}/apps/oidc_login/oidc" ];
          scopes = [
            "openid"
            "profile"
            "email"
            "groups"
          ];
          userinfo_signing_algorithm = "none";
        }
      ];
    })
  ];
}
