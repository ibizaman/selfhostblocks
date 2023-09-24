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

    additionalPlugins = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      description = "Location of additional plugins.";
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    services.deluge = {
      enable = true;
      declarative = true;
      openFirewall = true;
      config = {
        download_location = cfg.downloadLocation;
        max_upload_speed = -1.0;
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
      };
      authFile = "/run/secrets/deluge/auth";

      web.enable = true;
      web.port = cfg.webPort;
    };

    
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
        autheliaRule = {
          domain = fqdn;
          policy = "two_factor";
          subject = ["group:deluge_user"];
        };
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
