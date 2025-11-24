{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.shb.nextcloud;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
  fqdnWithPort = if isNull cfg.port then fqdn else "${fqdn}:${toString cfg.port}";
  protocol = if !(isNull cfg.ssl) then "https" else "http";

  ssoFqdnWithPort =
    if isNull cfg.apps.sso.port then
      cfg.apps.sso.endpoint
    else
      "${cfg.apps.sso.endpoint}:${toString cfg.apps.sso.port}";

  contracts = pkgs.callPackage ../contracts { };

  nextcloudPkg = builtins.getAttr ("nextcloud" + builtins.toString cfg.version) pkgs;
  nextcloudApps =
    (builtins.getAttr ("nextcloud" + builtins.toString cfg.version + "Packages") pkgs).apps;

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
      type = lib.types.enum [
        31
        32
      ];
      default = 31;
    };

    dataDir = lib.mkOption {
      description = "Folder where Nextcloud will store all its data.";
      type = lib.types.str;
      default = "/var/lib/nextcloud";
    };

    mountPointServices = lib.mkOption {
      description = "If given, all the systemd services and timers will depend on the specified mount point systemd services.";
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = lib.literalExpression ''["var.mount"]'';
    };

    adminUser = lib.mkOption {
      type = lib.types.str;
      description = "Username of the initial admin user.";
      default = "root";
    };

    adminPass = lib.mkOption {
      description = "Nextcloud admin password.";
      type = lib.types.submodule {
        options = contracts.secret.mkRequester {
          mode = "0400";
          owner = "nextcloud";
          restartUnits = [ "phpfpm-nextcloud.service" ];
        };
      };
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
      description = ''
        Settings for the PostgreSQL database.

        Go to https://pgtune.leopard.in.ua/ and copy the generated configuration here.
      '';
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
      default = {
        "pm" = "static";
        "pm.max_children" = 5;
        "pm.start_servers" = 5;
      };
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

    phpFpmPrometheusExporter = lib.mkOption {
      description = "Settings for exporting";
      default = { };

      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            description = "Enable export of php-fpm metrics to Prometheus.";
            type = lib.types.bool;
            default = true;
          };

          port = lib.mkOption {
            description = "Port on which the exporter will listen.";
            type = lib.types.port;
            default = 8300;
          };
        };
      };
    };

    apps = lib.mkOption {
      description = ''
        Applications to enable in Nextcloud. Enabling an application here will also configure
        various services needed for this application.

        Enabled apps will automatically be installed, enabled and configured, so no need to do that
        through the UI. You can still make changes but they will be overridden on next deploy. You
        can still install and configure other apps through the UI.
      '';
      default = { };
      type = lib.types.submodule {
        options = {
          onlyoffice = lib.mkOption {
            description = ''
              Only Office App. [Nextcloud App Store](https://apps.nextcloud.com/apps/onlyoffice)

              Enabling this app will also start an OnlyOffice instance accessible at the given
              subdomain from the given network range.
            '';
            default = { };
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
            default = { };
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
                    nextcloud-occ config:system:set preview_max_x --type integer --value 2048
                    nextcloud-occ config:system:set preview_max_y --type integer --value 2048
                    nextcloud-occ config:system:set jpeg_quality --value 60
                    nextcloud-occ config:app:set preview jpeg_quality --value=60
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

          externalStorage = lib.mkOption {
            # TODO: would be nice to have quota include external storage but it's not supported for root:
            # https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_configuration.html#setting-storage-quotas
            description = ''
              External Storage App. [Manual](https://docs.nextcloud.com/server/28/go.php?to=admin-external-storage)

              Set `userLocalMount` to automatically add a local directory as an external storage.
              Use this option if you want to store user data in another folder or another hard drive
              altogether.

              In the `directory` option, you can use either `$user` and/or `$home` which will be
              replaced by the user's name and home directory.

              Recommended use of this option is to have the Nextcloud's `dataDir` on a SSD and the
              `userLocalRooDirectory` on a HDD. Indeed, a SSD is much quicker than a spinning hard
              drive, which is well suited for randomly accessing small files like thumbnails. On the
              other side, a spinning hard drive can store more data which is well suited for storing
              user data.
            '';
            default = { };
            type = lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "Nextcloud External Storage App";
                userLocalMount = lib.mkOption {
                  default = null;
                  description = "If set, adds a local mount as external storage.";
                  type = lib.types.nullOr (
                    lib.types.submodule {
                      options = {
                        directory = lib.mkOption {
                          type = lib.types.str;
                          description = ''
                            Local directory on the filesystem to mount. Use `$user` and/or `$home`
                            which will be replaced by the user's name and home directory.
                          '';
                          example = "/srv/nextcloud/$user";
                        };

                        mountName = lib.mkOption {
                          type = lib.types.str;
                          description = ''
                            Path of the mount in Nextcloud. Use `/` to mount as the root.
                          '';
                          default = "";
                          example = [
                            "home"
                            "/"
                          ];
                        };
                      };
                    }
                  );
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
            default = { };
            type = lib.types.nullOr (
              lib.types.submodule {
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

                  adminPassword = lib.mkOption {
                    description = "LDAP server admin password.";
                    type = lib.types.submodule {
                      options = contracts.secret.mkRequester {
                        mode = "0400";
                        owner = "nextcloud";
                        restartUnits = [ "phpfpm-nextcloud.service" ];
                      };
                    };
                  };

                  userGroup = lib.mkOption {
                    type = lib.types.str;
                    description = "Group users must belong to to be able to login to Nextcloud.";
                    default = "nextcloud_user";
                  };

                  configID = lib.mkOption {
                    type = lib.types.int;
                    description = ''
                      Multiple LDAP configs can co-exist with only one active at a time.
                      This option sets the config ID used by Self Host Blocks.
                    '';
                    default = 50;
                  };
                };
              }
            );
          };

          sso = lib.mkOption {
            description = ''
              SSO Integration App. [Manual](https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/oidc_auth.html)

              Enabling this app will create a new LDAP configuration or update one that exists with
              the given host.
            '';
            default = { };
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
                  type = lib.types.enum [
                    "one_factor"
                    "two_factor"
                  ];
                  description = "Require one factor (password) or two factor (device) authentication.";
                  default = "one_factor";
                };

                adminGroup = lib.mkOption {
                  type = lib.types.str;
                  description = "Group admins must belong to to be able to login to Nextcloud.";
                  default = "nextcloud_admin";
                };

                secret = lib.mkOption {
                  description = "OIDC shared secret.";
                  type = lib.types.submodule {
                    options = contracts.secret.mkRequester {
                      mode = "0400";
                      owner = "nextcloud";
                      restartUnits = [ "phpfpm-nextcloud.service" ];
                    };
                  };
                };

                secretForAuthelia = lib.mkOption {
                  description = "OIDC shared secret. Content must be the same as `secretFile` option.";
                  type = lib.types.submodule {
                    options = contracts.secret.mkRequester {
                      mode = "0400";
                      owner = "authelia";
                    };
                  };
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

          memories = lib.mkOption {
            description = ''
              Memories App. [Nextcloud App Store](https://apps.nextcloud.com/apps/memories)

              Enabling this app will set up the Memories app and configure all its dependencies.

              On first install, you can either let the cron job index all images or you can run it manually with:

              ```nix
              nextcloud-occ memories:index
              ```
            '';
            default = { };
            type = lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "Memories app.";

                vaapi = lib.mkOption {
                  type = lib.types.bool;
                  description = ''
                    Enable VAAPI transcoding.

                    Will make `nextcloud` user part of the `render` group to be able to access
                    `/dev/dri/renderD128`.
                  '';
                  default = false;
                };

                photosPath = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    Path where photos are stored in Nextcloud.
                  '';
                  default = "/Photos";
                };
              };
            };
          };

          recognize = lib.mkOption {
            description = ''
              Recognize App. [Nextcloud App Store](https://apps.nextcloud.com/apps/recognize)

              Enabling this app will set up the Recognize app and configure all its dependencies.
            '';
            default = { };
            type = lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "Recognize app.";
              };
            };
          };
        };
      };
    };

    extraApps = lib.mkOption {
      type = lib.types.raw;
      description = ''
        Extra apps to install.

        Should be a function returning an `attrSet` of `appid` as keys to `packages` as values,
        like generated by `fetchNextcloudApp`.
        The appid must be identical to the `id` value in the apps'
        `appinfo/info.xml`.
        Search in [nixpkgs](https://github.com/NixOS/nixpkgs/tree/master/pkgs/servers/nextcloud/packages) for the `NN.json` files for existing apps.

        You can still install apps through the appstore.
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

    backup = lib.mkOption {
      description = ''
        Backup configuration.
      '';
      default = { };
      type = lib.types.submodule {
        options = contracts.backup.mkRequester {
          user = "nextcloud";
          sourceDirectories = [
            cfg.dataDir
          ];
          excludePatterns = [ ".rnd" ];
        };
      };
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

    autoDisableMaintenanceModeOnStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Upon starting the service, disable maintenance mode if set.

        This is useful if a deploy failed and you try to redeploy.
      '';
    };

    alwaysApplyExpensiveMigrations = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run `occ maintenance:repair --include-expensive` on service start.

        Larger instances should disable this and run the command at a convenient time
        but Self Host Blocks assumes that it will not be the case for most users.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      users.users = {
        nextcloud = {
          name = "nextcloud";
          group = "nextcloud";
          isSystemUser = true;
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
        package = nextcloudPkg.overrideAttrs (old: {
          patches = [
            ../../patches/nextcloudexternalstorage.patch
          ];
        });

        datadir = cfg.dataDir;

        hostName = fqdn;
        nginx.hstsMaxAge = 31536000; # Needs > 1 year for https://hstspreload.org to be happy

        inherit (cfg) maxUploadSize;

        config = {
          dbtype = "pgsql";
          adminuser = cfg.adminUser;
          adminpassFile = cfg.adminPass.result.path;
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

        extraApps = if isNull cfg.extraApps then { } else cfg.extraApps nextcloudApps;
        extraAppsEnable = true;
        appstoreEnable = true;

        settings =
          let
            protocol = if !(isNull cfg.ssl) then "https" else "http";
          in
          {
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
            "loglevel" = if !cfg.debug then 2 else 0;
            "filelocking.debug" = cfg.debug;

            # Use persistent SQL connections.
            "dbpersistent" = "true";

            # https://help.nextcloud.com/t/very-slow-sync-for-small-files/11064/13
            "chunkSize" = "5120MB";
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

          # https://docs.nextcloud.com/server/stable/admin_manual/configuration_files/big_file_upload_configuration.html#configuring-php
          # > Output Buffering must be turned off [...] or PHP will return memory-related errors.
          output_buffering = "Off";

          # Needed to avoid corruption per https://docs.nextcloud.com/server/21/admin_manual/configuration_server/caching_configuration.html#id2
          "redis.session.locking_enabled" = "1";
          "redis.session.lock_retries" = "-1";
          "redis.session.lock_wait_time" = "10000";
        }
        // lib.optionalAttrs (!(isNull cfg.tracing)) {
          # "xdebug.remote_enable" = "on";
          # "xdebug.remote_host" = "127.0.0.1";
          # "xdebug.remote_port" = "9000";
          # "xdebug.remote_handler" = "dbgp";
          "xdebug.trigger_value" = cfg.tracing;

          "xdebug.mode" = "profile,trace";
          "xdebug.output_dir" = "/var/log/xdebug";
          "xdebug.start_with_request" = "trigger";
        };

        poolSettings = lib.mkIf (!(isNull cfg.phpFpmPoolSettings)) cfg.phpFpmPoolSettings;

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
      ];

      services.postgresql.settings = lib.mkIf (!(isNull cfg.postgresSettings)) cfg.postgresSettings;

      systemd.services.phpfpm-nextcloud.preStart = ''
        mkdir -p /var/log/xdebug; chown -R nextcloud: /var/log/xdebug
      '';
      systemd.services.phpfpm-nextcloud.requires = cfg.mountPointServices;
      systemd.services.phpfpm-nextcloud.after = cfg.mountPointServices;

      systemd.timers.nextcloud-cron.requires = cfg.mountPointServices;
      systemd.timers.nextcloud-cron.after = cfg.mountPointServices;
      # This is needed to be able to run the cron job before opening the app for the first time.
      # Otherwise the cron job fails while searching for this directory.
      systemd.services.nextcloud-setup.script = ''
        mkdir -p ${cfg.dataDir}/data/appdata_$(${occ} config:system:get instanceid)/theming/global
      '';

      systemd.services.nextcloud-setup.requires = cfg.mountPointServices;
      systemd.services.nextcloud-setup.after = cfg.mountPointServices;
    })

    (lib.mkIf (cfg.enable && cfg.phpFpmPrometheusExporter.enable) {
      services.prometheus.exporters.php-fpm = {
        enable = true;
        user = "nginx";
        port = cfg.phpFpmPrometheusExporter.port;
        listenAddress = "127.0.0.1";
        extraFlags = [
          "--phpfpm.scrape-uri=tcp://127.0.0.1:${
            toString (cfg.phpFpmPrometheusExporter.port - 1)
          }/status?full"
        ];
      };

      services.nextcloud = {
        poolSettings = {
          "pm.status_path" = "/status";
          # Need to use TCP connection to get status.
          # I couldn't get PHP-FPM exporter to work with a unix socket.
          #
          # I also tried to server the status page at /status.php
          # but fcgi doesn't like the returned headers.
          "pm.status_listen" = "127.0.0.1:${toString (cfg.phpFpmPrometheusExporter.port - 1)}";
        };
      };

      services.prometheus.scrapeConfigs = [
        {
          job_name = "phpfpm-nextcloud";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString cfg.phpFpmPrometheusExporter.port}" ];
              labels = {
                "hostname" = config.networking.hostName;
                "domain" = cfg.domain;
              };
            }
          ];
        }
      ];
    })

    (lib.mkIf (cfg.enable && cfg.apps.onlyoffice.enable) {
      assertions = [
        {
          assertion = !(isNull cfg.apps.onlyoffice.jwtSecretFile);
          message = "Must set shb.nextcloud.apps.onlyoffice.jwtSecretFile.";
        }
      ];

      services.nextcloud.extraApps = {
        inherit (nextcloudApps) onlyoffice;
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

    (lib.mkIf (cfg.enable && cfg.apps.previewgenerator.enable) {
      services.nextcloud.extraApps = {
        inherit (nextcloudApps) previewgenerator;
      };

      services.nextcloud.settings = {
        # List obtained from the admin panel of Memories app.
        enabledPreviewProviders = [
          "OC\\Preview\\BMP"
          "OC\\Preview\\GIF"
          "OC\\Preview\\HEIC"
          "OC\\Preview\\Image"
          "OC\\Preview\\JPEG"
          "OC\\Preview\\Krita"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\Movie"
          "OC\\Preview\\MP3"
          "OC\\Preview\\OpenDocument"
          "OC\\Preview\\PNG"
          "OC\\Preview\\TXT"
          "OC\\Preview\\XBitmap"
        ];

      };

      # Values taken from
      # http://web.archive.org/web/20200513043150/https://ownyourbits.com/2019/06/29/understanding-and-improving-nextcloud-previews/
      systemd.services.nextcloud-setup.script = lib.mkIf cfg.apps.previewgenerator.recommendedSettings ''
        ${occ} config:app:set previewgenerator squareSizes --value="32 256"
        ${occ} config:app:set previewgenerator widthSizes  --value="256 384"
        ${occ} config:app:set previewgenerator heightSizes --value="256"
        ${occ} config:system:set preview_max_x --type integer --value 2048
        ${occ} config:system:set preview_max_y --type integer --value 2048
        ${occ} config:system:set jpeg_quality --value 60
        ${occ} config:app:set preview jpeg_quality --value=60
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
        serviceConfig.ExecStart =
          let
            debug = if cfg.debug or cfg.apps.previewgenerator.debug then "-vvv" else "";
          in
          "${occ} ${debug} preview:pre-generate";
      };
    })

    (lib.mkIf (cfg.enable && cfg.apps.externalStorage.enable) {
      systemd.services.nextcloud-setup.script = ''
        ${occ} app:install files_external || :
        ${occ} app:enable  files_external
      ''
      + lib.optionalString (cfg.apps.externalStorage.userLocalMount != null) (
        let
          cfg' = cfg.apps.externalStorage.userLocalMount;
          jq = "${pkgs.jq}/bin/jq";
        in
        # sh
        ''
          exists=$(${occ} files_external:list --output=json | ${jq} 'any(.[]; .mount_point == "${cfg'.mountName}" and .configuration.datadir == "${cfg'.directory}")')
          if [[ "$exists" == "false" ]]; then
            ${occ} files_external:create \
                    '${cfg'.mountName}' \
                    local \
                    null::null \
                    --config datadir='${cfg'.directory}'
          fi
        ''
      );
    })

    (lib.mkIf (cfg.enable && cfg.apps.ldap.enable) {
      systemd.services.nextcloud-setup.path = [ pkgs.jq ];
      systemd.services.nextcloud-setup.script =
        let
          cfg' = cfg.apps.ldap;
          cID = "s" + toString cfg'.configID;
        in
        ''
          ${occ} app:install user_ldap || :
          ${occ} app:enable  user_ldap

          ${occ} config:app:set user_ldap ${cID}ldap_configuration_active --value=0

          # The following CLI commands follow
          # https://github.com/lldap/lldap/blob/main/example_configs/nextcloud.md#nextcloud-config--the-cli-way

          ${occ} ldap:set-config "${cID}" 'ldapHost' \
                    '${cfg'.host}'
          ${occ} ldap:set-config "${cID}" 'ldapPort' \
                    '${toString cfg'.port}'
          ${occ} ldap:set-config "${cID}" 'ldapAgentName' \
                    'uid=${cfg'.adminName},ou=people,${cfg'.dcdomain}'
          ${occ} ldap:set-config "${cID}" 'ldapAgentPassword'  \
                    "$(cat ${cfg'.adminPassword.result.path})"
          ${occ} ldap:set-config "${cID}" 'ldapBase' \
                    '${cfg'.dcdomain}'
          ${occ} ldap:set-config "${cID}" 'ldapBaseGroups' \
                    '${cfg'.dcdomain}'
          ${occ} ldap:set-config "${cID}" 'ldapBaseUsers' \
                    '${cfg'.dcdomain}'
          ${occ} ldap:set-config "${cID}" 'ldapEmailAttribute' \
                    'mail'
          ${occ} ldap:set-config "${cID}" 'ldapGroupFilter' \
                    '(&(|(objectclass=groupOfUniqueNames))(|(cn=${cfg'.userGroup})))'
          ${occ} ldap:set-config "${cID}" 'ldapGroupFilterGroups' \
                    '${cfg'.userGroup}'
          ${occ} ldap:set-config "${cID}" 'ldapGroupFilterObjectclass' \
                    'groupOfUniqueNames'
          ${occ} ldap:set-config "${cID}" 'ldapGroupMemberAssocAttr' \
                    'uniqueMember'
          ${occ} ldap:set-config "${cID}" 'ldapLoginFilter' \
                    '(&(&(objectclass=person)(memberOf=cn=${cfg'.userGroup},ou=groups,${cfg'.dcdomain}))(|(uid=%uid)(|(mail=%uid)(objectclass=%uid))))'
          ${occ} ldap:set-config "${cID}" 'ldapLoginFilterAttributes' \
                    'mail;objectclass'
          ${occ} ldap:set-config "${cID}" 'ldapUserDisplayName' \
                    'givenname'
          ${occ} ldap:set-config "${cID}" 'ldapUserFilter' \
                    '(&(objectclass=person)(memberOf=cn=${cfg'.userGroup},ou=groups,${cfg'.dcdomain}))'
          ${occ} ldap:set-config "${cID}" 'ldapUserFilterMode' \
                    '1'
          ${occ} ldap:set-config "${cID}" 'ldapUserFilterObjectclass' \
                    'person'
          # Makes the user_id used when creating a user through LDAP which means the ID used in
          # Nextcloud is compatible with the one returned by a (possibly added in the future) SSO
          # provider.
          ${occ} ldap:set-config "${cID}" 'ldapExpertUsernameAttr' \
                    'uid'

          ${occ} ldap:test-config -- "${cID}"

          # Only one active at the same time

          ALL_CONFIG="$(${occ} ldap:show-config --output=json)"
          for configid in $(echo "$ALL_CONFIG" | jq --raw-output "keys[]"); do
            echo "Deactivating $configid"
            ${occ} ldap:set-config "$configid" 'ldapConfigurationActive' \
                      '0'
          done

          ${occ} ldap:set-config "${cID}" 'ldapConfigurationActive' \
                    '1'
        '';
    })

    (
      let
        scopes = [
          "openid"
          "profile"
          "email"
          "groups"
          "nextcloud_userinfo"
        ];
      in
      lib.mkIf (cfg.enable && cfg.apps.sso.enable) {
        assertions = [
          {
            assertion = cfg.ssl != null;
            message = "To integrate SSO, SSL must be enabled, set the shb.nextcloud.ssl option.";
          }
        ];

        services.nextcloud.extraApps = {
          inherit (nextcloudApps) oidc_login;
        };

        systemd.services.nextcloud-setup-pre = {
          wantedBy = [ "multi-user.target" ];
          before = [ "nextcloud-setup.service" ];
          serviceConfig.Type = "oneshot";
          serviceConfig.User = "nextcloud";
          script = ''
            mkdir -p ${cfg.dataDir}/config
            cat <<EOF > "${cfg.dataDir}/config/secretFile"
            {
              "oidc_login_client_secret": "$(cat ${cfg.apps.sso.secret.result.path})"
            }
            EOF
          '';
        };

        services.nextcloud = {
          secretFile = "${cfg.dataDir}/config/secretFile";

          # See all options at https://github.com/pulsejet/nextcloud-oidc-login
          # Other important url/links are:
          #   ${fqdn}/.well-known/openid-configuration
          #   https://www.authelia.com/reference/guides/attributes/#custom-attributes
          #   https://github.com/lldap/lldap/blob/main/example_configs/nextcloud_oidc_authelia.md
          #   https://www.authelia.com/integration/openid-connect/nextcloud/#authelia
          #   https://www.openidconnect.net/
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
            # Now, Authelia provides the info using the UserInfo request.
            oidc_login_use_id_token = false;
            oidc_login_attributes = {
              id = "preferred_username";
              name = "name";
              mail = "email";
              groups = "groups";
              is_admin = "is_nextcloud_admin";
            };
            oidc_login_allowed_groups = [ cfg.apps.ldap.userGroup ];
            oidc_login_default_group = "oidc";
            oidc_login_use_external_storage = false;
            oidc_login_scope = lib.concatStringsSep " " scopes;
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
            oidc_login_webdav_enabled = false;
            oidc_login_password_authentication = false;
            oidc_login_public_key_caching_time = 86400;
            oidc_login_min_time_between_jwks_requests = 10;
            oidc_login_well_known_caching_time = 86400;
            # If true, nextcloud will download user avatars on login. This may lead to security issues
            # as the server does not control which URLs will be requested. Use with care.
            oidc_login_update_avatar = false;
            oidc_login_code_challenge_method = "S256";
          };
        };

        shb.authelia.extraDefinitions = {
          user_attributes."is_nextcloud_admin".expression =
            ''type(groups) == list && "${cfg.apps.sso.adminGroup}" in groups'';
        };
        shb.authelia.extraOidcClaimsPolicies."nextcloud_userinfo" = {
          custom_claims = {
            is_nextcloud_admin = { };
          };
        };
        shb.authelia.extraOidcScopes."nextcloud_userinfo" = {
          claims = [ "is_nextcloud_admin" ];
        };

        shb.authelia.oidcClients = lib.mkIf (cfg.apps.sso.provider == "Authelia") [
          {
            client_id = cfg.apps.sso.clientID;
            client_name = "Nextcloud";
            client_secret.source = cfg.apps.sso.secretForAuthelia.result.path;
            claims_policy = "nextcloud_userinfo";
            public = false;
            authorization_policy = cfg.apps.sso.authorization_policy;
            require_pkce = "true";
            pkce_challenge_method = "S256";
            redirect_uris = [ "${protocol}://${fqdnWithPort}/apps/oidc_login/oidc" ];
            inherit scopes;
            response_types = [ "code" ];
            grant_types = [ "authorization_code" ];
            access_token_signed_response_alg = "none";
            userinfo_signed_response_alg = "none";
            token_endpoint_auth_method = "client_secret_basic";
          }
        ];
      }
    )

    (lib.mkIf (cfg.enable && cfg.autoDisableMaintenanceModeOnStart) {
      systemd.services.nextcloud-setup.preStart = lib.mkBefore ''
        if [[ -e /var/lib/nextcloud/config/config.php ]]; then
            ${occ} maintenance:mode --no-interaction --quiet --off
        fi
      '';
    })

    (lib.mkIf (cfg.enable && cfg.alwaysApplyExpensiveMigrations) {
      systemd.services.nextcloud-setup.script = ''
        if [[ -e /var/lib/nextcloud/config/config.php ]]; then
            ${occ} maintenance:repair --include-expensive
        fi
      '';
    })

    # Great source of inspiration:
    # https://github.com/Shawn8901/nix-configuration/blob/538c18d9ecbf7c7e649b1540c0d40881bada6690/modules/nixos/private/nextcloud/memories.nix#L226
    (lib.mkIf cfg.apps.memories.enable (
      let
        cfg' = cfg.apps.memories;

        exiftool = pkgs.exiftool.overrideAttrs (
          f: p: {
            version = "12.70";
            src = pkgs.fetchurl {
              url = "https://exiftool.org/Image-ExifTool-12.70.tar.gz";
              hash = "sha256-TLJSJEXMPj870TkExq6uraX8Wl4kmNerrSlX3LQsr/4=";
            };
          }
        );
      in
      {
        assertions = [
          {
            assertion = true;
            message = "Memories app has an issue for now, see https://github.com/ibizaman/selfhostblocks/issues/476.";
          }
        ];

        services.nextcloud.extraApps = {
          inherit (nextcloudApps) memories;
        };

        systemd.services.nextcloud-cron = {
          # required for memories
          # see https://github.com/pulsejet/memories/blob/master/docs/troubleshooting.md#issues-with-nixos
          path = [ pkgs.perl ];
        };

        services.nextcloud = {
          # See all options at https://memories.gallery/system-config/
          settings = {
            "memories.exiftool" = "${exiftool}/bin/exiftool";
            "memories.exiftool_no_local" = false;
            "memories.index.mode" = "3";
            "memories.index.path" = cfg'.photosPath;
            "memories.timeline.default_path" = cfg'.photosPath;

            "memories.vod.disable" = !cfg'.vaapi;
            "memories.vod.vaapi" = cfg'.vaapi;
            "memories.vod.ffmpeg" = "${pkgs.ffmpeg-headless}/bin/ffmpeg";
            "memories.vod.ffprobe" = "${pkgs.ffmpeg-headless}/bin/ffprobe";
            "memories.vod.use_transpose" = true;
            "memories.vod.use_transpose.force_sw" = cfg'.vaapi; # AMD and old Intel can't use hardware here.

            "memories.db.triggers.fcu" = true;
            "memories.readonly" = true;
            "preview_ffmpeg_path" = "${pkgs.ffmpeg-headless}/bin/ffmpeg";
          };
        };

        systemd.services.phpfpm-nextcloud.serviceConfig = lib.mkIf cfg'.vaapi {
          DeviceAllow = [ "/dev/dri/renderD128 rwm" ];
          PrivateDevices = lib.mkForce false;
        };
      }
    ))

    (lib.mkIf cfg.apps.recognize.enable (
      let
        cfg' = cfg.apps.recognize;
      in
      {
        services.nextcloud.extraApps = {
          inherit (nextcloudApps) recognize;
        };

        systemd.services.nextcloud-setup.script = ''
          ${occ} config:app:set recognize nice_binary --value ${pkgs.coreutils}/bin/nice
          ${occ} config:app:set recognize node_binary --value ${pkgs.nodejs}/bin/node
          ${occ} config:app:set recognize faces.enabled --value true
          ${occ} config:app:set recognize faces.batchSize --value 50
          ${occ} config:app:set recognize imagenet.enabled --value true
          ${occ} config:app:set recognize imagenet.batchSize --value 100
          ${occ} config:app:set recognize landmarks.batchSize --value 100
          ${occ} config:app:set recognize landmarks.enabled --value true
          ${occ} config:app:set recognize tensorflow.cores --value 1
          ${occ} config:app:set recognize tensorflow.gpu --value false
          ${occ} config:app:set recognize tensorflow.purejs --value false
          ${occ} config:app:set recognize musicnn.enabled --value true
          ${occ} config:app:set recognize musicnn.batchSize --value 100
        '';
      }
    ))
  ];
}
