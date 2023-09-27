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
      description = "Subdomain under which home-assistant will be served.";
      example = "nextcloud";
    };

    domain = lib.mkOption {
      description = lib.mdDoc "Domain to serve sites under.";
      type = lib.types.str;
      example = "domain.com";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file location";
      example = "secrets/nextcloud.yaml";
    };

    localNetworkIPRange = lib.mkOption {
      type = lib.types.str;
      description = "Local network range, to restrict access to the UI to only those IPs.";
      example = "192.168.1.1/24";
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      description = "Enable debugging.";
      default = false;
      example = true;
    };
  };

  config = lib.mkIf cfg.enable {
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

      # Enable php-fpm and nginx which will be behind the shb haproxy instance.
      hostName = fqdn;
      nginx.hstsMaxAge = 31536000; # Needs > 1 year for https://hstspreload.org to be happy

      config = {
        dbtype = "pgsql";
        adminuser = "root";
        adminpassFile = "/run/secrets/nextcloud/adminpass";
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
      https = true;

      extraOptions = {
        "overwrite.cli.url" = "https://" + fqdn;
        "overwritehost" = fqdn;
         # 'trusted_domains' needed otherwise we get this issue https://help.nextcloud.com/t/the-polling-url-does-not-start-with-https-despite-the-login-url-started-with-https/137576/2
        "trusted_domains" = [ fqdn ];
        "overwriteprotocol" = "https"; # Needed if behind a reverse_proxy
        "overwritecondaddr" = ""; # We need to set it to empty otherwise overwriteprotocol does not work.
      } // lib.optionalAttrs cfg.debug {
        "debug" = true;
        "filelocking.debug" = true;
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

        # Needed to avoid corruption per https://docs.nextcloud.com/server/21/admin_manual/configuration_server/caching_configuration.html#id2
        "redis.session.locking_enabled" = "1";
        "redis.session.lock_retries" = "-1";
        "redis.session.lock_wait_time" = "10000";
      } // lib.optionalAttrs cfg.debug {
        # "xdebug.remote_enable" = "on";
        # "xdebug.remote_host" = "127.0.0.1";
        # "xdebug.remote_port" = "9000";
        # "xdebug.remote_handler" = "dbgp";
        "xdebug.trigger_value" = "debug_me";

        "xdebug.mode" = "profile";
        "xdebug.output_dir" = "/var/log/xdebug";
        "xdebug.start_with_request" = "trigger";
      };

      phpExtraExtensions = all: [ all.xdebug ];
    };

    services.onlyoffice = {
      enable = true;
      hostname = "oo.${cfg.domain}";
      port = 13444;

      postgresHost = "/run/postgresql";

      jwtSecretFile = "/run/secrets/nextcloud/onlyoffice/jwt_secret";
    };
    services.nginx.virtualHosts."oo.${cfg.domain}" = {
      sslCertificate = "/var/lib/acme/${cfg.domain}/cert.pem";
      sslCertificateKey = "/var/lib/acme/${cfg.domain}/key.pem";
      forceSSL = true;
      locations."/" = {
        extraConfig = ''
        allow ${cfg.localNetworkIPRange};
        '';
      };
    };

    # Secret needed for services.onlyoffice.jwtSecretFile
    sops.secrets."nextcloud/onlyoffice/jwt_secret" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = "onlyoffice";
      group = "onlyoffice";
      restartUnits = [ "onlyoffice-docservice.service" ];
    };

    # Secret needed for services.nextcloud.config.adminpassFile.
    sops.secrets."nextcloud/adminpass" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = "nextcloud";
      group = "nextcloud";
      restartUnits = [ "phpfpm-nextcloud.service" ];
    };

    services.nginx.virtualHosts.${fqdn} = {
      # listen = [ { addr = "0.0.0.0"; port = 443; } ];
      sslCertificate = "/var/lib/acme/${cfg.domain}/cert.pem";
      sslCertificateKey = "/var/lib/acme/${cfg.domain}/key.pem";
      forceSSL = true;
    };

    # Needed for a few apps. Would be nice to avoid having to put that in the environment and instead override https://github.com/NixOS/nixpkgs/blob/261abe8a44a7e8392598d038d2e01f7b33cf26d0/nixos/modules/services/web-apps/nextcloud.nix#L1035
    environment.systemPackages = [ pkgs.ffmpeg ];

    services.postgresql.settings = {
      # From https://pgtune.leopard.in.ua/

      # DB Version: 16
      # OS Type: linux
      # DB Type: web
      # Total Memory (RAM): 5 GB
      # CPUs num: 2
      # Connections num: 100
      # Data Storage: hdd

      max_connections = "100";
      shared_buffers = "1280MB";
      effective_cache_size = "3840MB";
      maintenance_work_mem = "320MB";
      checkpoint_completion_target = "0.9";
      wal_buffers = "16MB";
      default_statistics_target = "100";
      random_page_cost = "4";
      effective_io_concurrency = "2";
      work_mem = "6553kB";
      huge_pages = "off";
      min_wal_size = "1GB";
      max_wal_size = "4GB";
    };

    systemd.services.phpfpm-nextcloud.serviceConfig = {
      # Setup permissions needed for backups, as the backup user is member of the jellyfin group.
      UMask = lib.mkForce "0027";
    };
    systemd.services.phpfpm-nextcloud.preStart = ''
      mkdir -p /var/log/xdebug; chown -R nextcloud: /var/log/xdebug
    '';

    # Sets up backup for Nextcloud.
    shb.backup.instances.nextcloud = {
      sourceDirectories = [
        config.services.nextcloud.datadir
      ];
      excludePatterns = [".rnd"];
    };
  };
}
