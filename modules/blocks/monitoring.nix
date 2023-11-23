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

    debugLog = lib.mkOption {
      type = lib.types.bool;
      description = "Set to true to enable debug logging of the infrastructure serving Grafana.";
      default = false;
      example = true;
    };
  };

  config = lib.mkIf cfg.enable {
    shb.postgresql.ensures = [
      {
        username = "grafana";
        database = "grafana";
      }
    ];

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
          router_logging = cfg.debugLog;
        };
      };
    };

    services.prometheus = {
      enable = true;
      port = 3001;
    };

    services.loki = {
      enable = true;
      dataDir = "/var/lib/loki";
      configuration = {
        auth_enabled = false;

        server.http_listen_port = 3002;

        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore.store = "inmemory";
              replication_factor = 1;
            };
            final_sleep = "0s";
          };
          chunk_idle_period = "5m";
          chunk_retain_period = "30s";
        };

        schema_config = {
          configs = [
            {
              from = "2018-04-15";
              store = "boltdb";
              object_store = "filesystem";
              schema = "v9";
              index.prefix = "index_";
              index.period = "168h";
            }
          ];
        };

        storage_config = {
          boltdb.directory = "/tmp/loki/index";
          filesystem.directory = "/tmp/loki/chunks";
        };

        limits_config = {
          enforce_metric_name = false;
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };

        chunk_store_config = {
          max_look_back_period = 0;
        };

        table_manager = {
          chunk_tables_provisioning = {
            inactive_read_throughput = 0;
            inactive_write_throughput = 0;
            provisioned_read_throughput = 0;
            provisioned_write_throughput = 0;
          };
          index_tables_provisioning = {
            inactive_read_throughput = 0;
            inactive_write_throughput = 0;
            provisioned_read_throughput = 0;
            provisioned_write_throughput = 0;
          };
          retention_deletes_enabled = false;
          retention_period = 0;
        };
      };
    };

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };

        positions.filename = "/tmp/positions.yaml";

        client.url = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}/api/prom/push";

        scrape_configs = [
          {
            job_name = "systemd";
            journal = {
              json = false;
              max_age = "12h";
              path = "/var/log/journal";
              # matches = "_TRANSPORT=kernel";
              labels = {
                job = "systemd-journal";
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };

    services.nginx = {
      enable = true;

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
            targets = ["127.0.0.1:${toString config.services.prometheus.exporters.node.port}"];
          }
        ];
      }
      {
        job_name = "smartctl";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}"];
          }
        ];
      }
      {
        job_name = "prometheus_internal";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString config.services.prometheus.port}"];
          }
        ];
      }
    ] ++ (lib.lists.optional config.services.nginx.enable {
        job_name = "nginx";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}"];
          }
        ];
    # }) ++ (lib.optional (builtins.length (lib.attrNames config.services.redis.servers) > 0) {
    #     job_name = "redis";
    #     static_configs = [
    #       {
    #         targets = ["127.0.0.1:${toString config.services.prometheus.exporters.redis.port}"];
    #       }
    #     ];
    # }) ++ (lib.optional (builtins.length (lib.attrNames config.services.openvpn.servers) > 0) {
    #     job_name = "openvpn";
    #     static_configs = [
    #       {
    #         targets = ["127.0.0.1:${toString config.services.prometheus.exporters.openvpn.port}"];
    #       }
    #     ];
    }) ++ (lib.optional config.services.dnsmasq.enable {
        job_name = "dnsmasq";
        static_configs = [
          {
            targets = ["127.0.0.1:${toString config.services.prometheus.exporters.dnsmasq.port}"];
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
    services.prometheus.exporters.smartctl = {
      enable = true;
      port = 9117;
      listenAddress = "127.0.0.1";
    };
    # services.prometheus.exporters.redis = lib.mkIf (builtins.length (lib.attrNames config.services.redis.servers) > 0) {
    #   enable = true;
    #   port = 9119;
    #   listenAddress = "127.0.0.1";
    # };
    # services.prometheus.exporters.openvpn = lib.mkIf (builtins.length (lib.attrNames config.services.openvpn.servers) > 0) {
    #   enable = true;
    #   port = 9121;
    #   listenAddress = "127.0.0.1";
    #   statusPaths = lib.mapAttrsToList (name: _config: "/tmp/openvpn/${name}.status") config.services.openvpn.servers;
    # };
    services.prometheus.exporters.dnsmasq = lib.mkIf config.services.dnsmasq.enable {
      enable = true;
      port = 9123;
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
