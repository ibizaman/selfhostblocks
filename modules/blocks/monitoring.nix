{
  config,
  pkgs,
  lib,
  shb,
  ...
}:

let
  cfg = config.shb.monitoring;

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  roleClaim = "grafana_groups";
  oauthScopes = [
    "openid"
    "email"
    "profile"
    "groups"
    "${roleClaim}"
  ];
in
{
  imports = [
    ../../lib/module.nix
    ../blocks/authelia.nix
    ../blocks/lldap.nix
    ../blocks/nginx.nix
  ];

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
      type = lib.types.nullOr shb.contracts.ssl.certs;
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
        3
        2
      ];
      description = ''
        Switching from version 2 to 3 requires manual intervention
        https://grafana.com/docs/loki/latest/setup/upgrade/#loki-300.
        Only version 3 is supported now because it's the only one compatible with recent
        releases of Grafana.
      '';
      default = 3;
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

    dashboards = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      description = "Dashboards to provision under 'Self Host Blocks' folder.";
      default = [ ];
    };

    contactPoints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of email addresses to send alerts to";
      default = [ ];
    };

    scrutiny = {
      enable = lib.mkEnableOption "scrutiny service" // {
        default = true;
      };
      subdomain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = ''
          If a string, this will be the subdomain under which the scrutiny web interface will be servced.

          If null, the web interface will not be served and only the prometheus metrics will be accessible.
        '';
        default = "scrutiny";
      };
      ssl = lib.mkOption {
        description = "SSL certificate for the Scrutiny web interface. Defaults to `shb.monitoring.ssl` for backwards compatibility.";
        type = lib.types.nullOr shb.contracts.ssl.certs;
        default = cfg.ssl;
        defaultText = lib.literalExpression "config.shb.monitoring.ssl";
      };
      dashboard = lib.mkOption {
        description = ''
          Dashboard contract consumer
        '';
        default = { };
        type = lib.types.submodule {
          options = shb.contracts.dashboard.mkRequester {
            externalUrl = "https://${cfg.scrutiny.subdomain}.${cfg.domain}";
            externalUrlText = "https://\${config.shb.monitoring.scrutiny.subdomain}.\${config.shb.monitoring.domain}";
            internalUrl = "http://127.0.0.1:${toString config.services.scrutiny.settings.web.listen.port}";
            internalUrlText = "https://127.0.0.1.\${config.services.scrutiny.settings.web.listen.port}";
          };
        };
      };
    };

    adminPassword = lib.mkOption {
      description = "Initial admin password.";
      type = lib.types.submodule {
        options = shb.contracts.secret.mkRequester {
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
        options = shb.contracts.secret.mkRequester {
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

    ldap = lib.mkOption {
      description = ''
        Setup LDAP integration.
      '';
      default = { };
      type = lib.types.submodule {
        options = {
          userGroup = lib.mkOption {
            type = lib.types.str;
            description = "Group users must belong to to be able to login to Grafana.";
            default = "monitoring_user";
          };
          adminGroup = lib.mkOption {
            type = lib.types.str;
            description = "Group users must belong to to be admins in Grafana.";
            default = "monitoring_admin";
          };
        };
      };
    };

    sso = lib.mkOption {
      description = ''
        Setup SSO integration.
      '';
      default = { };
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "SSO integration.";

          authEndpoint = lib.mkOption {
            type = lib.types.str;
            default = null;
            description = "Endpoint to the SSO provider.";
            example = "https://authelia.example.com";
          };

          clientID = lib.mkOption {
            type = lib.types.str;
            description = "Client ID for the OIDC endpoint.";
            default = "grafana";
          };

          authorization_policy = lib.mkOption {
            type = lib.types.enum [
              "one_factor"
              "two_factor"
            ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };

          sharedSecret = lib.mkOption {
            description = "OIDC shared secret for Grafana.";
            type = lib.types.submodule {
              options = shb.contracts.secret.mkRequester {
                owner = "grafana";
                restartUnits = [
                  "grafana.service"
                ];
              };
            };
          };

          sharedSecretForAuthelia = lib.mkOption {
            description = "OIDC shared secret for Authelia. Must be the same as `sharedSecret`";
            type = lib.types.submodule {
              options = shb.contracts.secret.mkRequester {
                mode = "0400";
                ownerText = "config.shb.authelia.autheliaUser";
                owner = config.shb.authelia.autheliaUser;
              };
            };
          };
        };
      };
    };

    dashboard = lib.mkOption {
      description = ''
        Dashboard contract consumer
      '';
      default = { };
      type = lib.types.submodule {
        options = shb.contracts.dashboard.mkRequester {
          externalUrl = "https://${cfg.subdomain}.${cfg.domain}";
          externalUrlText = "https://\${config.shb.monitoring.subdomain}.\${config.shb.monitoring.domain}";
          internalUrl = "https://${cfg.subdomain}.${cfg.domain}";
          internalUrlText = "https://\${config.shb.monitoring.subdomain}.\${config.shb.monitoring.domain}";
        };
      };
    };

    impermanence = lib.mkOption {
      description = ''
        Paths to save when using impermanence setup.
      '';
      type = lib.types.attrsOf lib.types.str;
      default = {
        loki = "/var/lib/loki";
        fluent-bit = "/var/lib/private/fluent-bit";
      };
    };

    commonLabels = lib.mkOption {
      description = ''
        Common labels added to all metrics.
      '';
      type = lib.types.attrsOf lib.types.str;
      default = {
        hostname = config.networking.hostName;
        domain = cfg.domain;
      };
      defaultText = {
        hostname = "networking.hostName";
        domain = "shb.monitoring.domain";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = builtins.length cfg.contactPoints > 0;
          message = "Must have at least one contact point for alerting";
        }
        {
          assertion = cfg.lokiMajorVersion != 2;
          message = "Loki major version 2 is not supported anymore, set `shb.monitoring.lockMajorVersion = 3` and do the manual migration as described in https://grafana.com/docs/loki/latest/setup/upgrade/#loki-300.";
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
    })

    (lib.mkIf cfg.enable {
      shb.monitoring.dashboards = [
        ./monitoring/dashboards/Errors.json
        ./monitoring/dashboards/Performance.json
        ./monitoring/dashboards/Scraping_Jobs.json
      ];

      services.grafana.provision = {
        dashboards.settings = lib.mkIf (cfg.dashboards != [ ]) {
          apiVersion = 1;
          providers = [
            {
              folder = "Self Host Blocks";
              options.path = pkgs.symlinkJoin {
                name = "dashboards";
                paths = map (p: pkgs.runCommand "dashboard" { } "mkdir $out; cp ${p} $out") cfg.dashboards;
              };
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
    })

    (lib.mkIf cfg.enable {
      services.prometheus = {
        enable = true;
        port = cfg.prometheusPort;
        globalConfig = {
          scrape_interval = "15s";
        };
      };

      services.loki = {
        enable = true;
        dataDir = "/var/lib/loki";
        package = pkgs.grafana-loki;
        configuration = {
          auth_enabled = false;
          analytics.reporting_enabled = false;

          common = {
            path_prefix = config.services.loki.dataDir;

            instance_addr = "127.0.0.1";

            ring = {
              kvstore.store = "inmemory";
            };

            replication_factor = 1;
          };

          server.http_listen_port = cfg.lokiPort;

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
              {
                from = "2026-10-04";
                store = "tsdb";
                object_store = "filesystem";
                schema = "v13";
                index.prefix = "index_";
                index.period = "24h";
              }
            ];
          };

          storage_config = {
            boltdb.directory = "${config.services.loki.dataDir}/boltdb-index";
            filesystem.directory = "${config.services.loki.dataDir}/filesystem-index";
            tsdb_shipper = {
              active_index_directory = "${config.services.loki.dataDir}/tsdb-index";
              cache_location = "${config.services.loki.dataDir}/tsdb-cache";
            };
          };

          limits_config = {
            # allow_structured_metadata = false;
            volume_enabled = true;
            reject_old_samples = true;
            reject_old_samples_max_age = "168h";
            retention_period = "2520h";
            # 16 MiB/s sustained ingestion
            ingestion_rate_mb = 16;
            # 32 MiB burst allowance
            ingestion_burst_size_mb = 32;
          };

          compactor = {
            working_directory = "${config.services.loki.dataDir}/compactor";
            retention_enabled = true;
            delete_request_store = "filesystem";
          };
        };
      };

      # I decided to switch to fluent-bit because it can be tested locally https://docs.fluentbit.io/manual/local-testing/logging-pipeline
      services.fluent-bit = {
        enable = true;
        # Without this fluent-bit cannot read the systemd journal.
        package = pkgs.fluent-bit.override { systemdLibs = pkgs.systemd; };
        settings = {
          service = {
            flush = 1;
            log_level = "info";
            http_server = "true";
            http_listen = "127.0.0.1";
            http_port = 9080;
            grace = 30;
          };

          parsers = [
            {
              name = "nginx_json";
              format = "json";
              time_key = "time_local";
              time_format = "%d/%b/%Y:%H:%M:%S %z";
              time_keep = false; # Remove the time_local field from the output.
            }
          ];

          pipeline = {
            inputs = [
              {
                name = "systemd";

                # The asterisk appends the _SYSTEMD_UNIT to the prefix.
                tag = "systemd.*";

                # Read logs from this systemd journal directory.
                path = "/var/log/journal";

                # Database file to keep track of the journald cursor.
                db = "/var/lib/fluent-bit/systemd.db";

                # Max entries to lookback on start.
                max_entries = 1000;

                # Cap memory.
                mem_buf_limit = "50MB";

                read_from_tail = true;
              }
            ]
            ++ lib.optionals (config.services.nginx.enable) [
              {
                name = "tail";
                tag = "nginx.access";
                path = "/var/log/nginx/access.json";
                db = "/var/lib/fluent-bit/nginx-access.db";
                parser = "nginx_json";
              }
            ];

            filters = [
              {
                name = "modify";
                match = "systemd.*";
                copy = "_SYSTEMD_UNIT unit";
              }
              # Do not make fluent-bit read its own logs other we end up looping.
              # I'm keeping this here because I'm not sure it is needed.
              # {
              #   name = "grep";
              #   match = "systemd.*";
              #   exclude = "_SYSTEMD_UNIT ^fluent-bit\\.service$";
              # }
            ];

            outputs = [
              {
                name = "loki";
                match = "systemd.*";

                retry_limit = 5;

                host = "localhost";
                port = config.services.loki.configuration.server.http_listen_port;

                labels = lib.concatMapAttrsStringSep ", " (n: v: "${n}=${v}") {
                  job = "systemd-journal";
                  domain = cfg.domain;
                  hostname = config.networking.hostName;
                };

                label_keys = "$unit";
              }
              {
                name = "loki";
                match = "nginx.access";

                host = "localhost";
                port = config.services.loki.configuration.server.http_listen_port;

                labels = lib.concatMapAttrsStringSep ", " (n: v: "${n}=${v}") {
                  job = "nginx";
                  domain = cfg.domain;
                  hostname = config.networking.hostName;
                  service = "nginx";
                };

                label_keys = "$server_name";
              }
            ];
          };
        };
        graceLimit = "1m";
      };
      systemd.services.fluent-bit.after = lib.optionals config.services.nginx.enable [
        "nginx.service"
      ];
      systemd.services.fluent-bit.serviceConfig = {
        StateDirectory = "fluent-bit";
      }
      // lib.optionalAttrs config.services.nginx.enable {
        BindReadOnlyPaths = [ "/var/log/nginx/access.json" ];
        SupplementaryGroups = [ "nginx" ];
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
    })

    (lib.mkIf cfg.enable {
      services.prometheus.scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
              labels = cfg.commonLabels;
            }
          ];
        }
        {
          job_name = "zfs";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.zfs.port}" ];
              labels = cfg.commonLabels;
            }
          ];
        }
        {
          job_name = "smartctl";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}" ];
              labels = cfg.commonLabels;
            }
          ];
        }
        {
          job_name = "prometheus_internal";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.port}" ];
              labels = cfg.commonLabels;
            }
          ];
        }
        {
          job_name = "systemd";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.systemd.port}" ];
              labels = cfg.commonLabels;
            }
          ];
        }
      ]
      ++ (lib.lists.optional config.services.nginx.enable {
        job_name = "nginx";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}" ];
            labels = cfg.commonLabels;
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
            labels = cfg.commonLabels;
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
      services.prometheus.exporters.zfs = {
        enable = true;
        port = 9114;
        listenAddress = "127.0.0.1";
      };
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
        extraFlags = [
          "--systemd.collector.enable-ip-accounting"
        ];
      };
      # This accounting is then used by the systemd exporter
      systemd.settings.Manager = {
        DefaultCPUAccounting = true;
        DefaultMemoryAccounting = true;
        DefaultIOAccounting = true;
        DefaultTasksAccounting = true;
        DefaultIPAccounting = true;
      };

      services.nginx.statusPage = lib.mkDefault config.services.nginx.enable;

      nixpkgs.overlays = [
        (final: prev: {
          prometheus-systemd-exporter = prev.prometheus-systemd-exporter.overrideAttrs {
            src = final.fetchFromGitHub {
              owner = "ibizaman";
              repo = prev.prometheus-systemd-exporter.pname;
              # rev = "v${prev.prometheus-systemd-exporter.version}";
              rev = "next_timer";
              sha256 = "sha256-jzkh/616tsJbNxFtZ0xbdBQc16TMIYr9QOkPaeQw8xA=";
            };

            vendorHash = "sha256-4hsQ1417jLNOAqGkfCkzrmEtYR4YLLW2j0CiJtPg6GI=";
          };
        })
      ];
    })
    (lib.mkIf cfg.enable {
      services.cadvisor = {
        enable = true;
        port = 9118;
      };

      services.prometheus.scrapeConfigs = [
        {
          job_name = "cadvisor";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.cadvisor.port}" ];
              labels = cfg.commonLabels;
            }
          ];
        }
      ];
    })
    (lib.mkIf (cfg.enable && cfg.sso.enable) {
      shb.lldap.ensureGroups = {
        ${cfg.ldap.userGroup} = { };
        ${cfg.ldap.adminGroup} = { };
      };

      shb.authelia.extraDefinitions = {
        user_attributes.${roleClaim}.expression =
          # Roles are: None, Viewer, Editor, Admin, GrafanaAdmin
          ''"${cfg.ldap.adminGroup}" in groups ? "Admin" : ("${cfg.ldap.userGroup}" in groups ? "Editor" : "Invalid")'';
      };
      shb.authelia.extraOidcClaimsPolicies.${roleClaim} = {
        custom_claims = {
          "${roleClaim}" = { };
        };
      };
      shb.authelia.extraOidcScopes."${roleClaim}" = {
        claims = [ "${roleClaim}" ];
      };

      services.grafana.settings."auth.generic_oauth" = {
        enabled = true;
        name = "Authelia";
        icon = "signin";
        client_id = cfg.sso.clientID;
        client_secret = "$__file{${cfg.sso.sharedSecret.result.path}}";
        scopes = oauthScopes;
        empty_scopes = false;
        allow_sign_up = true;
        auto_login = true;
        auth_url = "${cfg.sso.authEndpoint}/api/oidc/authorization";
        token_url = "${cfg.sso.authEndpoint}/api/oidc/token";
        # use_refresh_token = true; ?  # https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/generic-oauth/#configure-generic-oauth-authentication-client-using-the-grafana-configuration-file
        api_url = "${cfg.sso.authEndpoint}/api/oidc/userinfo";
        login_attribute_path = "preferred_username";
        groups_attribute_path = "groups";
        name_attribute_path = "name";
        use_pkce = true;
        allow_assign_grafana_admin = true;
        skip_org_role_sync = false;
        role_attribute_path = roleClaim;
        role_attribute_strict = true;
      };

      shb.authelia.oidcClients = [
        {
          client_id = cfg.sso.clientID;
          client_secret.source = cfg.sso.sharedSecretForAuthelia.result.path;
          claims_policy = "${roleClaim}";
          scopes = oauthScopes;
          authorization_policy = cfg.sso.authorization_policy;
          redirect_uris = [
            "https://${cfg.subdomain}.${cfg.domain}/login/generic_oauth"
          ];
          require_pkce = true;
          pkce_challenge_method = "S256";
          response_types = [ "code" ];
          token_endpoint_auth_method = "client_secret_basic";
        }
      ];
    })

    (lib.mkIf (cfg.enable && cfg.scrutiny.enable) {
      services.scrutiny = {
        enable = true;

        openFirewall = false;

        # This src includes Prometheus metrics exporter.
        package = pkgs.scrutiny.overrideAttrs ({
          src = pkgs.fetchFromGitHub {
            owner = "ibizaman";
            repo = "scrutiny";
            rev = "74faf06f77df83f29e7e1806cd88b2fafc0bbb82";
            hash = "sha256-r0AVWL+E046xHxitwMPfRNTOpjuOk+W6tB41YgmLTPg=";
          };

          vendorHash = "sha256-kAlnlWnBMFCdgdak5L5hRquRtyLi5MTmDa/kxwqPs4E=";
        });

        settings = {
          web = {
            metrics.enabled = true; # Enables Prometheus exporter
            listen.host = "127.0.0.1";
          };
        };

        collector = {
          enable = true;
        };
      };

      services.prometheus.scrapeConfigs = [
        {
          job_name = "scrutiny";
          metrics_path = "/api/metrics";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.scrutiny.settings.web.listen.port}" ];
              labels = cfg.commonLabels;
            }
          ];
        }
      ];

      shb.monitoring.dashboards = [
        ./monitoring/dashboards/Health.json
      ];

      shb.nginx.vhosts = lib.mkIf (cfg.scrutiny.subdomain != null) [
        (
          {
            inherit (cfg) domain;
            inherit (cfg.scrutiny) ssl subdomain;

            upstream = "http://127.0.0.1:${toString config.services.scrutiny.settings.web.listen.port}";
            autheliaRules = lib.optionals (cfg.sso.enable) [
              {
                domain = "${cfg.subdomain}.${cfg.domain}";
                policy = cfg.sso.authorization_policy;
                subject = [
                  "group:${cfg.ldap.userGroup}"
                  "group:${cfg.ldap.adminGroup}"
                ];
              }
            ];
          }
          // lib.optionalAttrs cfg.sso.enable {
            inherit (cfg.sso) authEndpoint;
          }
        )
      ];
    })
  ];
}
