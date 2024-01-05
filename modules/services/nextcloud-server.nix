{ config, pkgs, lib, ... }:

let
  cfg = config.shb.nextcloud;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.nextcloud = {
    enable = lib.mkEnableOption "selfhostblocks.nextcloud-server";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which Nextcloud will be served.";
      example = "nextcloud";
    };

    domain = lib.mkOption {
      description = "Domain to serve Nextcloud under.";
      type = lib.types.str;
      example = "domain.com";
    };

    externalFqdn = lib.mkOption {
      description = "External fqdn used to access Nextcloud. Defaults to <subdomain>.<domain>. This should only be set if you include the port when accessing Nextcloud.";
      type = lib.types.nullOr lib.types.str;
      example = "nextcloud.domain.com:8080";
      default = null;
    };

    dataDir = lib.mkOption {
      description = "Folder where Nextcloud will store all its data.";
      type = lib.types.str;
      default = "/var/lib/nextcloud";
    };

    adminUser = lib.mkOption {
      type = lib.types.str;
      description = "Username of the initial admin user.";
      default = "root";
    };

    adminPassFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the Nextcloud admin password.";
    };

    maxUploadSize = lib.mkOption {
      default = "4G";
      type = lib.types.str;
      description = ''
        The upload limit for files. This changes the relevant options
        in php.ini and nginx if enabled.
      '';
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
      type = lib.types.submodule {
        options = {
          onlyoffice = lib.mkOption {
            description = "If non null, set up an Only Office service.";
            default = {
              enable = false;
              jwtSecretFile = "";
            };
            type = lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "Nextcloud OnlyOffice App";

                subdomain = lib.mkOption {
                  type = lib.types.str;
                  description = "Subdomain under which Only Office will be served.";
                  default = "oo";
                };

                localNetworkIPRange = lib.mkOption {
                  type = lib.types.str;
                  description = "Local network range, to restrict access to Open Office to only those IPs.";
                  default = "192.168.1.1/24";
                };

                jwtSecretFile = lib.mkOption {
                  type = lib.types.path;
                  description = "File containing the JWT secret.";
                };
              };
            });
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
      default = apps: {};
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
      description = "Enable xdebug tracing.";
      default = null;
      example = "debug_me";
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
        package = pkgs.nextcloud27;

        datadir = cfg.dataDir;

        hostName = fqdn;
        nginx.hstsMaxAge = 31536000; # Needs > 1 year for https://hstspreload.org to be happy

        inherit (cfg) maxUploadSize;

        config = {
          dbtype = "pgsql";
          adminuser = cfg.adminUser;
          adminpassFile = toString cfg.adminPassFile;
          # Not using dbpassFile as we're using socket authentication.
          defaultPhoneRegion = "US";
          trustedProxies = [ "127.0.0.1" ];
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
        https = config.shb.ssl.enable;

        extraApps = cfg.extraApps pkgs.nextcloud27Packages.apps;
        extraAppsEnable = true;
        appstoreEnable = true;

        extraOptions = let
          protocol = if config.shb.ssl.enable then "https" else "http";
        in {
          "overwrite.cli.url" = "${protocol}://${fqdn}";
          "overwritehost" = if (isNull cfg.externalFqdn) then fqdn else cfg.externalFqdn;
          # 'trusted_domains' needed otherwise we get this issue https://help.nextcloud.com/t/the-polling-url-does-not-start-with-https-despite-the-login-url-started-with-https/137576/2
          # TODO: could instead set extraTrustedDomains
          "trusted_domains" = [ fqdn ];
          # TODO: could instead set overwriteProtocol
          "overwriteprotocol" = protocol; # Needed if behind a reverse_proxy
          "overwritecondaddr" = ""; # We need to set it to empty otherwise overwriteprotocol does not work.
          "debug" = cfg.debug;
          "filelocking.debug" = cfg.debug;
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
          "openssl.cafile" = "/etc/ssl/certs/ca-certificates.crt";
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
        sslCertificate = lib.mkIf config.shb.ssl.enable "/var/lib/acme/${cfg.domain}/cert.pem";
        sslCertificateKey = lib.mkIf config.shb.ssl.enable "/var/lib/acme/${cfg.domain}/key.pem";
        forceSSL = lib.mkIf config.shb.ssl.enable true;

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
        pkgs.ffmpeg

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

      systemd.services.nextcloud-cron.path = [
        pkgs.perl
      ];

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
          assertion = cfg.apps.onlyoffice.jwtSecretFile != "";
          message = "Must set jwtSecretFile.";
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
        sslCertificate = lib.mkIf config.shb.ssl.enable "/var/lib/acme/${cfg.domain}/cert.pem";
        sslCertificateKey = lib.mkIf config.shb.ssl.enable "/var/lib/acme/${cfg.domain}/key.pem";
        forceSSL = lib.mkIf config.shb.ssl.enable true;
        locations."/" = {
          extraConfig = ''
        allow ${cfg.apps.onlyoffice.localNetworkIPRange};
        '';
        };
      };
    })
  ];
}
