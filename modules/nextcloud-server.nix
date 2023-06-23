{ config, pkgs, lib, ... }:

let
  cfg = config.shb.nextcloud;
in
{
  options.shb.nextcloud = {
    enable = lib.mkEnableOption "selfhostblocks.nextcloud-server";

    fqdn = lib.mkOption {
      type = lib.types.str;
      description = "Fully qualified domain under which nextcloud will be served.";
      example = "nextcloud.domain.com";
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
      hostName = cfg.fqdn;

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
        "overwrite.cli.url" = "https://" + cfg.fqdn;
        "overwritehost" = cfg.fqdn;
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

    # The following changed the listen address for nginx and puts haproxy in front. See
    # https://nixos.wiki/wiki/Nextcloud#Change_default_listening_port
    #
    # It's a bit of a waste in resources to have nginx behind haproxy but the config for nginx is
    # complex enough that I find it better to re-use the one from nixpkgs instead of trying to copy
    # it over to haproxy. At least for now.
    services.nginx.virtualHosts.${cfg.fqdn}.listen = [ { addr = "127.0.0.1"; port = 8080; } ];
    shb.reverseproxy.sites.nextcloud = {
      frontend = {
        acl = {
          acl_nextcloud = "hdr_beg(host) n.";
          # well_known = "path_beg /.well-known";
          # caldav-endpoint = "path_beg /.well-known/caldav";
          # carddav-endpoint = "path_beg /.well-known/carddav";
          # webfinger-endpoint = "path_beg /.well-known/webfinger";
          # nodeinfo-endpoint = "path_beg /.well-known/nodeinfo";
        };
        http-request.set-header = {
          "X-Forwarded-Host" = "%[req.hdr(host)]";
          "X-Forwarded-Port" = "%[dst_port]";
        };
        # http-request = [
        #   "redirect code 301 location /remote.php/dav if acl_nextcloud caldav-endpoint"
        #   "redirect code 301 location /remote.php/dav if acl_nextcloud carddav-endpoint"
        #   "redirect code 301 location /public.php?service=webfinger if acl_nextcloud webfinger-endpoint"
        #   "redirect code 301 location /public.php?service=nodeinfo if acl_nextcloud nodeinfo-endpoint"
        # ];
        # http-response = {
        #   set-header = {
        #     # These headers are from https://github.com/NixOS/nixpkgs/blob/d3bb401dcfc5a46ce51cdfb5762e70cc75d082d2/nixos/modules/services/web-apps/nextcloud.nix#L1167-L1173
        #     X-Content-Type-Options = "nosniff";
        #     X-XSS-Protection = "\"1; mode=block\"";
        #     X-Robots-Tag = "\"noindex, nofollow\"";
        #     X-Download-Options = "noopen";
        #     X-Permitted-Cross-Domain-Policies = "none";
        #     X-Frame-Options = "sameorigin";
        #     Referrer-Policy = "no-referrer";
        #   };
        # };
        use_backend = "if acl_nextcloud";
      };
      backend = {
        servers = [
          {
            name = "nextcloud1";
            address =
              let
                addrs = config.services.nginx.virtualHosts.${cfg.fqdn}.listen;
              in
                builtins.map (c: "${c.addr}:${builtins.toString c.port}") addrs;
            forwardfor = true;
            balance = "roundrobin";
            check = {
              inter = "5s";
              downinter = "15s";
              fall = "3";
              rise = "3";
            };
            httpcheck = "GET /";
          }
        ];
      };
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
    };
  };
}
