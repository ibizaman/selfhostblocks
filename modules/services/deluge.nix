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
      description = "If not null, sets up a deluge to forward all traffic to the Proxy listening at that port.";
      type = lib.types.nullOr lib.types.int;
      default = null;
    };

    outgoingInterface = lib.mkOption {
      description = "If not null, sets up a deluge to bind all outgoing traffic to the given interface.";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    settings = lib.mkOption {
      description = "Deluge operational settings.";
      type = lib.types.submodule {
        options = {
          downloadLocation = lib.mkOption {
            type = lib.types.str;
            description = "Folder where torrents gets downloaded";
            example = "/srv/torrents";
          };

          max_active_limit = lib.mkOption {
            type = lib.types.int;
            description = "Maximum Active Limit";
            default = 200;
          };
          max_active_downloading = lib.mkOption {
            type = lib.types.int;
            description = "Maximum Active Downloading";
            default = 30;
          };
          max_active_seeding = lib.mkOption {
            type = lib.types.int;
            description = "Maximum Active Seeding";
            default = 100;
          };
          max_connections_global = lib.mkOption {
            type = lib.types.int;
            description = "Maximum Connections Global";
            default = 200;
          };
          max_connections_per_torrent = lib.mkOption {
            type = lib.types.int;
            description = "Maximum Connections Per Torrent";
            default = 50;
          };

          max_download_speed = lib.mkOption {
            type = lib.types.int;
            description = "Maximum Download Speed";
            default = 1000;
          };
          max_download_speed_per_torrent = lib.mkOption {
            type = lib.types.int;
            description = "Maximum Download Speed Per Torrent";
            default = -1;
          };

          max_upload_slots_global = lib.mkOption {
            type = lib.types.int;
            description = "Maximum Upload Slots Global";
            default = 100;
          };
          max_upload_slots_per_torrent = lib.mkOption {
            type = lib.types.int;
            description = "Maximum Upload Slots Per Torrent";
            default = 4;
          };
          max_upload_speed = lib.mkOption {
            type = lib.types.int;
            description = "Maximum Upload Speed";
            default = 200;
          };
          max_upload_speed_per_torrent = lib.mkOption {
            type = lib.types.int;
            description = "Maximum Upload Speed Per Torrent";
            default = 50;
          };

          dont_count_slow_torrents = lib.mkOption {
            type = lib.types.bool;
            description = "Do not count slow torrents towards any limits.";
            default = true;
          };
        };
      };
    };

    extraServiceConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Extra configuration given to the systemd service file.";
      default = {};
      example = lib.literalExpression ''
      {
        MemoryHigh = "512M";
        MemoryMax = "900M";
      }
      '';
    };

    authEndpoint = lib.mkOption {
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
      type = lib.types.listOf lib.types.path;
      description = "Location of additional plugins. Each item in the list must be the path to the directory containing the plugin .egg file.";
      default = [];
    };

    logLevel = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["critical" "error" "warning" "info" "debug"]);
      description = "Enable logging.";
      default = false;
      example = true;
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [{
    services.deluge = {
      enable = true;
      declarative = true;
      openFirewall = true;
      config = {
        download_location = cfg.settings.downloadLocation;
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
        outgoing_interface = cfg.outgoingInterface;

        enabled_plugins = cfg.enabledPlugins
                          ++ lib.optional (lib.any (x: x.enable) [
                              config.shb.arr.radarr
                              config.shb.arr.sonarr
                              config.shb.arr.bazarr
                              config.shb.arr.readarr
                              config.shb.arr.lidarr
                          ]) "Label";

        inherit (cfg.settings)
          max_active_limit
          max_active_downloading
          max_active_seeding
          max_connections_global
          max_connections_per_torrent

          max_download_speed
          max_download_speed_per_torrent

          max_upload_slots_global
          max_upload_slots_per_torrent
          max_upload_speed
          max_upload_speed_per_torrent

          dont_count_slow_torrents;

        new_release_check = false;
      };
      authFile = config.sops.secrets."deluge/auth".path;

      web.enable = true;
      web.port = cfg.webPort;
    };

    systemd.services.deluged.serviceConfig.ExecStart = lib.mkForce (lib.concatStringsSep " \\\n    " ([
      "${config.services.deluge.package}/bin/deluged"
      "--do-not-daemonize"
      "--config ${config.services.deluge.dataDir}/.config/deluge"
    ] ++ (lib.optional (!(isNull cfg.logLevel)) "-L ${cfg.logLevel}")
    ));
    
    systemd.tmpfiles.rules =
      let
        plugins = pkgs.symlinkJoin {
          name = "deluge-plugins";
          paths = cfg.additionalPlugins;
        };
      in
        [
          "L+ ${config.services.deluge.dataDir}/.config/deluge/plugins - - - - ${plugins}"
        ];

    sops.secrets."deluge/auth" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = config.services.deluge.user;
      group = config.services.deluge.group;
      restartUnits = [ "deluged.service" "delugeweb.service" ];
    };

    shb.nginx.autheliaProtect = lib.mkIf config.shb.authelia.enable [
      {
        inherit (cfg) subdomain domain authEndpoint;
        upstream = "http://127.0.0.1:${toString config.services.deluge.web.port}";
        autheliaRules = [{
          domain = fqdn;
          policy = "two_factor";
          subject = ["group:deluge_user"];
        }];
      }
    ];

    # We want deluge to create files in the media group and to make those files group readable.
    users.users.deluge = {
      extraGroups = [ "media" ];
    };
    systemd.services.deluged.serviceConfig.Group = lib.mkForce "media";
    systemd.services.deluged.serviceConfig.UMask = lib.mkForce "0027";

    # We backup the whole deluge directory and set permissions for the backup user accordingly.
    users.groups.deluge.members = [ "backup" ];
    users.groups.media.members = [ "backup" ];
    shb.backup.instances.deluge = {
      sourceDirectories = [
        config.services.deluge.dataDir
      ];
    };
  } {
    systemd.services.deluged.serviceConfig = cfg.extraServiceConfig;
  }]);
}
