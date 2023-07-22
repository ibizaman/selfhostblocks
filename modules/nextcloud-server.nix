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
  };

  config = lib.mkIf cfg.enable {
    users.users = {
      nextcloud = {
        name = "nextcloud";
        group = "nextcloud";
        home = "/srv/data/nextcloud";
        isSystemUser = true;
      };
    };

    users.groups = {
      nextcloud = {
        members = [ "backup" ];
      };
    };

    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud26;

      # Enable php-fpm and nginx which will be behind the shb haproxy instance.
      hostName = fqdn;

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

      extraOptions = {
        "overwrite.cli.url" = "https://" + fqdn;
        "overwritehost" = fqdn;
        "overwriteprotocol" = "https";
        "overwritecondaddr" = "^127\\.0\\.0\\.1$";
      };

      phpOptions = {
        # The OPcache interned strings buffer is nearly full with 8, bump to 16.
        "opcache.interned_strings_buffer" = "16";
      };
    };

    # Secret needed for services.nextcloud.config.adminpassFile.
    sops.secrets."nextcloud/adminpass" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = "nextcloud";
      group = "nextcloud";
    };

    services.nginx.virtualHosts.${fqdn} = {
      # listen = [ { addr = "0.0.0.0"; port = 443; } ];
      sslCertificate = "/var/lib/acme/${cfg.domain}/cert.pem";
      sslCertificateKey = "/var/lib/acme/${cfg.domain}/key.pem";
      addSSL = true;
    };

    systemd.services.phpfpm-nextcloud.serviceConfig = {
      # Setup permissions needed for backups, as the backup user is member of the jellyfin group.
      UMask = lib.mkForce "0027";
    };

    # Sets up backup for Nextcloud.
    shb.backup.instances.nextcloud = {
      sourceDirectories = [
        config.services.nextcloud.datadir
      ];
      excludePatterns = [".rnd"];
    };
  };
}
