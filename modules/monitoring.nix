{ config, pkgs, lib, ... }:

let
  cfg = config.shb.monitoring;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.monitoring = {
    enable = lib.mkEnableOption "selfhostblocks.monitoring";

    # sopsFile = lib.mkOption {
    #   type = lib.types.path;
    #   description = "Sops file location";
    #   example = "secrets/monitoring.yaml";
    # };

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which home-assistant will be served.";
      example = "grafana";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which home-assistant will be served.";
      example = "mydomain.com";
    };
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

      settings = {
        database = {
          host = "/run/postgresql";
          user = "grafana";
          name = "grafana";
          type = "postgres";
          # Uses peer auth for local users, so we don't need a password.
          # Here's the syntax anyway for future refence:
          # password = "$__file{/run/secrets/homeassistant/dbpass}";
        };

        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
          domain = fqdn;
          root_url = "https://${fqdn}";
        };
      };
    };

    services.prometheus = {
      enable = true;
      port = 3001;
    };

    services.nginx = {
      enable = true;
      # recommendedProxySettings = true;

      virtualHosts.${fqdn} = {
        forceSSL = true;
        sslCertificate = "/var/lib/acme/${cfg.domain}/cert.pem";
        sslCertificateKey = "/var/lib/acme/${cfg.domain}/key.pem";
        locations."/" = {
          proxyPass = "http://${toString config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";
          proxyWebsockets = true;
        };
      };
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = ["127.0.0.1:9115"];
          }
        ];
      }
    ] ++ (lib.lists.optional config.services.nginx.enable {
        job_name = "nginx";
        static_configs = [
          {
            targets = ["127.0.0.1:9113"];
          }
        ];
      });
    services.prometheus.exporters.nginx = lib.mkIf config.services.nginx.enable {
      enable = true;
      port = 9113;
      listenAddress = "127.0.0.1";
      scrapeUri = "http://localhost:80/nginx_status";
    };
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = ["systemd"];
      port = 9115;
      listenAddress = "127.0.0.1";
    };
    services.nginx.statusPage = lib.mkDefault config.services.nginx.enable;

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
