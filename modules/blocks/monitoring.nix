{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.shb.monitoring;

  contracts = pkgs.callPackage ../contracts { };

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  commonLabels = {
    hostname = config.networking.hostName;
    domain = cfg.domain;
  };
in
{
  options.shb.monitoring = {
    enable = lib.mkEnableOption "selfhostblocks.monitoring";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which Grafana will be served.";
      example = "grafana";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which Grafana will be served.";
      example = "mydomain.com";
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    grafanaPort = lib.mkOption {
      type = lib.types.port;
      description = "Port where Grafana listens to HTTP requests.";
      default = 3000;
    };

    prometheusPort = lib.mkOption {
      type = lib.types.port;
      description = "Port where Prometheus listens to HTTP requests.";
      default = 3001;
    };

    lokiPort = lib.mkOption {
      type = lib.types.port;
      description = "Port where Loki listens to HTTP requests.";
      default = 3002;
    };

    lokiMajorVersion = lib.mkOption {
      type = lib.types.enum [
        2
        3
      ];
      description = ''
        Switching from version 2 to 3 requires manual intervention
        https://grafana.com/docs/loki/latest/setup/upgrade/#main--unreleased. So this let's the user
        upgrade at their own pace.
      '';
      default = 2;
    };

    debugLog = lib.mkOption {
      type = lib.types.bool;
      description = "Set to true to enable debug logging of the infrastructure serving Grafana.";
      default = false;
      example = true;
    };

    orgId = lib.mkOption {
      type = lib.types.int;
      description = "Org ID where all self host blocks related config will be stored.";
      default = 1;
    };

    provisionDashboards = lib.mkOption {
      type = lib.types.bool;
      description = "Provision Self Host Blocks dashboards under 'Self Host Blocks' folder.";
      default = true;
    };

    contactPoints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of email addresses to send alerts to";
      default = [ ];
    };

    adminPassword = lib.mkOption {
      description = "Initial admin password.";
      type = lib.types.submodule {
        options = contracts.secret.mkRequester {
          mode = "0400";
          owner = "grafana";
          group = "grafana";
          restartUnits = [ "grafana.service" ];
        };
      };
    };

    secretKey = lib.mkOption {
      description = "Secret key used for signing.";
      type = lib.types.submodule {
        options = contracts.secret.mkRequester {
          mode = "0400";
          owner = "grafana";
          group = "grafana";
          restartUnits = [ "grafana.service" ];
        };
      };
    };

    smtp = lib.mkOption {
      description = "SMTP options.";
      default = null;
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            from_address = lib.mkOption {
              type = lib.types.str;
              description = "SMTP address from which the emails originate.";
              example = "vaultwarden@mydomain.com";
            };
            from_name = lib.mkOption {
              type = lib.types.str;
              description = "SMTP name from which the emails originate.";
              default = "Grafana";
            };
            host = lib.mkOption {
              type = lib.types.str;
              description = "SMTP host to send the emails to.";
            };
            port = lib.mkOption {
              type = lib.types.port;
              description = "SMTP port to send the emails to.";
              default = 25;
            };
            username = lib.mkOption {
              type = lib.types.str;
              description = "Username to connect to the SMTP host.";
            };
            passwordFile = lib.mkOption {
              type = lib.types.str;
              description = "File containing the password to connect to the SMTP host.";
            };
          };
        }
      );
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = (!(isNull cfg.smtp)) -> builtins.length cfg.contactPoints > 0;
          message = "Must have at least one contact point for alerting";
        }
      ];

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

          security = {
            secret_key = "$__file{${cfg.secretKey.result.path}}";
            disable_initial_admin_creation = false; # Enable when LDAP support is configured.
            admin_password = "$__file{${cfg.adminPassword.result.path}}"; # Remove when LDAP support is configured.
          };

          server = {
            http_addr = "127.0.0.1";
            http_port = cfg.grafanaPort;
            domain = fqdn;
            root_url = "https://${fqdn}";
            router_logging = cfg.debugLog;
          };

          smtp = lib.mkIf (!(isNull cfg.smtp)) {
            enabled = true;
            inherit (cfg.smtp) from_address from_name;
            host = "${cfg.smtp.host}:${toString cfg.smtp.port}";
            user = cfg.smtp.username;
            password = "$__file{${cfg.smtp.passwordFile}}";
          };
        };
      };

      services.grafana.provision = {
        dashboards.settings = lib.mkIf cfg.provisionDashboards {
          apiVersion = 1;
          providers = [
            {
              folder = "Self Host Blocks";
              options.path = ./monitoring/dashboards;
              allowUiUpdates = true;
              disableDeletion = true;
            }
          ];
        };
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              inherit (cfg) orgId;
              name = "Prometheus";
              type = "prometheus";
              url = "http://127.0.0.1:${toString config.services.prometheus.port}";
              uid = "df80f9f5-97d7-4112-91d8-72f523a02b09";
              isDefault = true;
              version = 1;
            }
            {
              inherit (cfg) orgId;
              name = "Loki";
              type = "loki";
              url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
              uid = "cd6cc53e-840c-484d-85f7-96fede324006";
              version = 1;
            }
          ];
          deleteDatasources = [
            {
              inherit (cfg) orgId;
              name = "Prometheus";
            }
            {
              inherit (cfg) orgId;
              name = "Loki";
            }
          ];
        };
        alerting.contactPoints.settings = {
          apiVersion = 1;
          contactPoints = [
            {
              inherit (cfg) orgId;
              name = "grafana-default-email";
              receivers = lib.optionals ((builtins.length cfg.contactPoints) > 0) [
                {
                  uid = "sysadmin";
                  type = "email";
                  settings.addresses = lib.concatStringsSep ";" cfg.contactPoints;
                }
              ];
            }
          ];
        };
        alerting.policies.settings = {
          apiVersion = 1;
          policies = [
            {
              inherit (cfg) orgId;
              receiver = "grafana-default-email";
              group_by = [
                "grafana_folder"
                "alertname"
              ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";
            }
          ];
          # resetPolicies seems to happen after setting the above policies, effectively rolling back
          # any updates.
        };
        alerting.rules.settings =
          let
            rules = builtins.fromJSON (builtins.readFile ./monitoring/rules.json);
          in
          {
            apiVersion = 1;
            groups = [
              {
                inherit (cfg) orgId;
                name = "SysAdmin";
                folder = "Self Host Blocks";
                interval = "10m";
                inherit rules;
              }
            ];
            # deleteRules seems to happen after creating the above rules, effectively rolling back
            # any updates.
          };
      };

      services.prometheus = {
        enable = true;
        port = cfg.prometheusPort;
      };

      services.loki = {
        enable = true;
        dataDir = "/var/lib/loki";
        package =
          if cfg.lokiMajorVersion == 3 then
            pkgs.grafana-loki
          else
            # Comes from https://github.com/NixOS/nixpkgs/commit/8f95320f39d7e4e4a29ee70b8718974295a619f4
            (pkgs.grafana-loki.overrideAttrs (
              finalAttrs: previousAttrs: rec {
                version = "2.9.6";

                src = pkgs.fetchFromGitHub {
                  owner = "grafana";
                  repo = "loki";
                  rev = "v${version}";
                  hash = "sha256-79hK7axHf6soku5DvdXkE/0K4WKc4pnS9VMbVc1FS2I=";
                };

                subPackages = [
                  "cmd/loki"
                  "cmd/loki-canary"
                  "clients/cmd/promtail"
                  "cmd/logcli"
                  # Removes "cmd/lokitool"
                ];

                ldflags =
                  let
                    t = "github.com/grafana/loki/pkg/util/build";
                  in
                  [
                    "-s"
                    "-w"
                    "-X ${t}.Version=${version}"
                    "-X ${t}.BuildUser=nix@nixpkgs"
                    "-X ${t}.BuildDate=unknown"
                    "-X ${t}.Branch=unknown"
                    "-X ${t}.Revision=unknown"
                  ];
              }
            ));
        configuration = {
          auth_enabled = false;

          server.http_listen_port = cfg.lokiPort;

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
                  domain = cfg.domain;
                  hostname = config.networking.hostName;
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
          forceSSL = !(isNull cfg.ssl);
          sslCertificate = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.cert;
          sslCertificateKey = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.key;

          locations."/" = {
            proxyPass = "http://${toString config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
            '';
          };
        };
      };

      services.prometheus.scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
              labels = commonLabels;
            }
          ];
        }
        {
          job_name = "netdata";
          metrics_path = "/api/v1/allmetrics";
          params.format = [ "prometheus" ];
          honor_labels = true;
          static_configs = [
            {
              targets = [ "127.0.0.1:19999" ];
              labels = commonLabels;
            }
          ];
        }
        {
          job_name = "smartctl";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}" ];
              labels = commonLabels;
            }
          ];
        }
        {
          job_name = "prometheus_internal";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.port}" ];
              labels = commonLabels;
            }
          ];
        }
        {
          job_name = "systemd";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.systemd.port}" ];
              labels = commonLabels;
            }
          ];
        }
      ]
      ++ (lib.lists.optional config.services.nginx.enable {
        job_name = "nginx";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}" ];
            labels = commonLabels;
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
      })
      ++ (lib.optional config.services.dnsmasq.enable {
        job_name = "dnsmasq";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.dnsmasq.port}" ];
            labels = commonLabels;
          }
        ];
      });
      services.prometheus.exporters.nginx = lib.mkIf config.services.nginx.enable {
        enable = true;
        port = 9111;
        listenAddress = "127.0.0.1";
        scrapeUri = "http://localhost:80/nginx_status";
      };
      services.prometheus.exporters.node = {
        enable = true;
        # https://github.com/prometheus/node_exporter#collectors
        enabledCollectors = [
          "arp"
          "cpu"
          "cpufreq"
          "diskstats"
          "dmi"
          "edac"
          "entropy"
          "filefd"
          "filesystem"
          "hwmon"
          "loadavg"
          "meminfo"
          "netclass"
          "netdev"
          "netstat"
          "nvme"
          "os"
          "pressure"
          "rapl"
          "schedstat"
          "stat"
          "thermal_zone"
          "time"
          "uname"
          "vmstat"
          "zfs"

          # Disabled by default
          "cgroups"
          "drm"
          "ethtool"
          "logind"
          "wifi"
        ];
        port = 9112;
        listenAddress = "127.0.0.1";
      };
      # https://github.com/nixos/nixpkgs/commit/12c26aca1fd55ab99f831bedc865a626eee39f80
      # TODO: remove when https://github.com/NixOS/nixpkgs/pull/205165 is merged
      services.udev.extraRules = ''
        SUBSYSTEM=="nvme", KERNEL=="nvme[0-9]*", GROUP="disk"
      '';
      services.prometheus.exporters.smartctl = {
        enable = true;
        port = 9115;
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
        port = 9211;
        listenAddress = "127.0.0.1";
      };
      services.prometheus.exporters.systemd = {
        enable = true;
        port = 9116;
        listenAddress = "127.0.0.1";
      };
      services.nginx.statusPage = lib.mkDefault config.services.nginx.enable;
      services.netdata = {
        enable = true;
        config = {
          # web.mode = "none";
          # web."bind to" = "127.0.0.1:19999";
          global = {
            "debug log" = "syslog";
            "access log" = "syslog";
            "error log" = "syslog";
          };
        };
      };
    })
  ];
}
