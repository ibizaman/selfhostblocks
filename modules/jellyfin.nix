{ config, lib, pkgs, ...}:

let
  cfg = config.shb.jellyfin;
in
{
  options.shb.jellyfin = {
    enable = lib.mkEnableOption "shb jellyfin";
  };

  config = lib.mkIf cfg.enable {
    services.jellyfin.enable = true;

    networking.firewall = {
      # from https://jellyfin.org/docs/general/networking/index.html, for auto-discovery
      allowedUDPPorts = [ 1900 7359 ];
    };

    users.groups = {
      media = {
        name = "media";
        members = [ "jellyfin" ];
      };
      jellyfin = {
        members = [ "backup" ];
      };
    };

    shb.reverseproxy.sites.jellyfin = {
      frontend = {
        acl = {
          acl_jellyfin = "hdr_beg(host) jellyfin.";
          acl_jellyfin_network_allowed = "src 127.0.0.1";
          acl_jellyfin_restricted_page = "path_beg /metrics";
        };
        http-request = {
          deny = "if acl_jellyfin acl_jellyfin_restricted_page !acl_jellyfin_network_allowed";
        };
        use_backend = "if acl_jellyfin";
      };
      # TODO: enable /metrics and block from outside https://jellyfin.org/docs/general/networking/monitoring/#prometheus-metrics
      backend = {
        servers = [
          {
            name = "jellyfin1";
            address = "127.0.0.1:8091";
            forwardfor = false;
            balance = "roundrobin";
            check = {
              inter = "5s";
              downinter = "15s";
              fall = "3";
              rise = "3";
            };
            httpcheck = "GET /health";
          }
        ];
      };
    };

    shb.backup.instances.jellyfin = {
      sourceDirectories = [
        "/var/lib/jellyfin"
      ];
    };

    systemd.services.jellyfin.serviceConfig = {
      # Setup permissions needed for backups, as the backup user is member of the jellyfin group.
      UMask = lib.mkForce "0027";
      StateDirectoryMode = lib.mkForce "0750";
    };
  };
}
