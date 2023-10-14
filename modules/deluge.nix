{ config, pkgs, lib, ... }:

let
  cfg = config.shb.deluge;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.deluge = {
    enable = lib.mkEnableOption "selfhostblocks.deluge";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which deluge will be served.";
      example = "ha";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which deluge will be served.";
      example = "mydomain.com";
    };

    daemonPort = lib.mkOption {
      type = lib.types.int;
      description = "Deluge daemon port";
      default = 58846;
    };

    daemonListenPorts = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      description = "Deluge daemon listen ports";
      default = [ 6881 6889 ];
    };

    webPort = lib.mkOption {
      type = lib.types.int;
      description = "Deluge web port";
      default = 8112;
    };

    proxyPort = lib.mkOption {
      description = lib.mdDoc "If not null, sets up a deluge to forward all traffic to the Proxy listening at that port.";
      type = lib.types.nullOr lib.types.int;
      default = null;
    };

    downloadLocation = lib.mkOption {
      type = lib.types.str;
      description = "Folder where torrents gets downloaded";
      example = "/srv/torrents";
    };

    oidcEndpoint = lib.mkOption {
      type = lib.types.str;
      description = "OIDC endpoint for SSO";
      example = "https://authelia.example.com";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file location.";
      example = "secrets/torrent.yaml";
    };

    enabledPlugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Plugins to enable, can include those from additionalPlugins.";
      example = ["Label"];
      default = [];
    };

    additionalPlugins = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      description = "Location of additional plugins.";
      default = {};
    };

    logLevel = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["critical" "error" "warning" "info" "debug"]);
      description = "Enable logging.";
      default = false;
      example = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.deluge = {
      enable = true;
      declarative = true;
      openFirewall = true;
      config = {
        download_location = cfg.downloadLocation;
        allow_remote = true;
        daemon_port = cfg.daemonPort;
        listen_ports = cfg.daemonListenPorts;
        proxy = lib.optionalAttrs (cfg.proxyPort != null) {
          force_proxy = true;
          hostname = "127.0.0.1";
          port = cfg.proxyPort;
          proxy_hostnames = true;
          proxy_peer_connections = true;
          proxy_tracker_connections = true;
          type = 4; # HTTP
        };

        enabled_plugins = cfg.enabledPlugins;

        # TODO: expose these
        max_active_limit = 10000;
        max_active_downloading = 30;
        max_active_seeding = 10000;
        max_connections_global = 1000;
        max_connections_per_torrent = 50;

        max_download_speed = 1000;
        max_download_speed_per_torrent = -1;

        max_upload_slots_global = 100;
        max_upload_slots_per_torrent = 4;
        max_upload_speed = 200;
        max_upload_speed_per_torrent = 50;

        dont_count_slow_torrents = true;
        new_release_check = false;
      };
      authFile = config.sops.secrets."deluge/auth".path;

      web.enable = true;
      web.port = cfg.webPort;
    };

    systemd.services.deluged.serviceConfig.ExecStart = lib.mkForce (
      ''
          ${config.services.deluge.package}/bin/deluged \
            --do-not-daemonize \
            --config ${config.services.deluge.dataDir}/.config/deluge
      '' +
      (if (isNull cfg.logLevel) then "" else " -L ${cfg.logLevel}")
    );
    
    systemd.tmpfiles.rules = lib.attrsets.mapAttrsToList (name: path:
      "L+ ${config.services.deluge.dataDir}/.config/deluge/plugins/${name} - - - - ${path}"
    ) cfg.additionalPlugins;

    sops.secrets."deluge/auth" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = config.services.deluge.user;
      group = config.services.deluge.group;
      restartUnits = [ "deluged.service" "delugeweb.service" ];
    };

    shb.nginx.autheliaProtect = [
      {
        inherit (cfg) subdomain domain oidcEndpoint;
        upstream = "http://127.0.0.1:${toString config.services.deluge.web.port}";
        autheliaRules = [{
          domain = fqdn;
          policy = "two_factor";
          subject = ["group:deluge_user"];
        }];
      }
    ];

    users.groups.deluge = {
      members = [ "backup" ];
    };

    shb.backup.instances.deluge = {
      sourceDirectories = [
        config.services.deluge.dataDir
      ];
    };
  };
}
