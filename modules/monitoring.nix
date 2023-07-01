{ config, pkgs, lib, ... }:

let
  cfg = config.shb.monitoring;
in
{
  options.shb.monitoring = {
    enable = lib.mkEnableOption "selfhostblocks.monitoring";

    # sopsFile = lib.mkOption {
    #   type = lib.types.path;
    #   description = "Sops file location";
    #   example = "secrets/monitoring.yaml";
    # };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "grafana" ];
      ensureUsers = [
        {
          name = "grafana";
          ensurePermissions = {
            "DATABASE grafana" = "ALL PRIVILEGES";
          };
          ensureClauses = {
            "login" = true;
          };
        }
      ];
    };

    services.grafana = {
      enable = true;

      database = {
        host = "/run/postgresql";
        user = "grafana";
        name = "grafana";
        type = "postgres";
        # Uses peer auth for local users, so we don't need a password.
        # Here's the syntax anyway for future refence:
        # password = "$__file{/run/secrets/homeassistant/dbpass}";
      };

      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
        };
      };
    };

    shb.reverseproxy.sites.grafana = {
      frontend = {
        acl = {
          acl_grafana = "hdr_beg(host) grafana.";
        };
        use_backend = "if acl_grafana";
      };
      backend = {
        servers = [
          {
            name = "grafana1";
            address = "127.0.0.1:3000";
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

    # sops.secrets."grafana" = {
    #   inherit (cfg) sopsFile;
    #   mode = "0440";
    #   owner = "grafana";
    #   group = "grafana";
    #   # path = "${config.services.home-assistant.configDir}/secrets.yaml";
    #   restartUnits = [ "grafana.service" ];
    # };
  };
}
