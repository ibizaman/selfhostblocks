{
  config,
  pkgs,
  lib,
  shb,
  ...
}:

let
  cfg = config.shb.deluge;

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  authGenerator =
    users:
    let
      genLine =
        name:
        {
          password,
          priority ? 10,
        }:
        "${name}:${password}:${toString priority}";

      lines = lib.mapAttrsToList genLine users;
    in
    lib.concatStringsSep "\n" lines;
in
{
  imports = [
    ../../lib/module.nix
    ../blocks/nginx.nix
    ../blocks/monitoring.nix
  ];

  options.shb.deluge = {
    enable = lib.mkEnableOption "the SHB Deluge service";

    enableDashboard = lib.mkEnableOption "the Torrents SHB dashboard" // {
      default = true;
    };

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

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr shb.contracts.ssl.certs;
      default = null;
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "Path where all configuration and state is stored.";
      default = "/var/lib/deluge";
    };

    daemonPort = lib.mkOption {
      type = lib.types.int;
      description = "Deluge daemon port";
      default = 58846;
    };

    daemonListenPorts = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      description = "Deluge daemon listen ports";
      default = [
        6881
        6889
      ];
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
      default = { };
      example = lib.literalExpression ''
        {
          MemoryHigh = "512M";
          MemoryMax = "900M";
        }
      '';
    };

    authEndpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "OIDC endpoint for SSO";
      default = null;
      example = "https://authelia.example.com";
    };

    extraUsers = lib.mkOption {
      description = "Users having access to this deluge instance. Attrset of username to user options.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            password = lib.mkOption {
              type = shb.secretFileType;
              description = "File containing the user password.";
            };
          };
        }
      );
    };

    localclientPassword = lib.mkOption {
      description = "Password for mandatory localclient user.";
      type = lib.types.submodule {
        options = shb.contracts.secret.mkRequester {
          owner = "deluge";
          restartUnits = [ "deluged.service" ];
        };
      };
    };

    prometheusScraperPassword = lib.mkOption {
      description = "Password for prometheus scraper. Setting this option will activate the prometheus deluge exporter.";
      type = lib.types.nullOr (
        lib.types.submodule {
          options = shb.contracts.secret.mkRequester {
            owner = "deluge";
            restartUnits = [
              "deluged.service"
              "prometheus.service"
            ];
          };
        }
      );
      default = null;
    };

    enabledPlugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        Plugins to enable, can include those from additionalPlugins.

        Label is automatically enabled if any of the `shb.arr.*` service is enabled.
      '';
      example = [ "Label" ];
      default = [ ];
    };

    additionalPlugins = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      description = "Location of additional plugins. Each item in the list must be the path to the directory containing the plugin .egg file.";
      default = [ ];
      example = lib.literalExpression ''
        additionalPlugins = [
          (pkgs.callPackage ({ python3, fetchFromGitHub }: python3.pkgs.buildPythonPackage {
            name = "deluge-autotracker";
            version = "1.0.0";
            src = fetchFromGitHub {
              owner = "ibizaman";
              repo = "deluge-autotracker";
              rev = "cc40d816a497bbf1c2ebeb3d8b1176210548a3e6";
              sha256 = "sha256-0LpVdv1fak2a5eX4unjhUcN7nMAl9fgpr3X+7XnQE6c=";
            } + "/autotracker";
            doCheck = false;
            format = "other";
            nativeBuildInputs = [ python3.pkgs.setuptools ];
            buildPhase = '''
            mkdir "$out"
            python3 setup.py install --install-lib "$out"
            ''';
            doInstallPhase = false;
          }) {})
        ];
      '';
    };

    backup = lib.mkOption {
      description = ''
        Backup configuration.
      '';
      default = { };
      type = lib.types.submodule {
        options = shb.contracts.backup.mkRequester {
          user = "deluge";
          sourceDirectories = [
            cfg.dataDir
          ];
        };
      };
    };

    logLevel = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "critical"
          "error"
          "warning"
          "info"
          "debug"
        ]
      );
      description = "Enable logging.";
      default = null;
      example = "info";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.deluge = {
          enable = true;
          declarative = true;
          openFirewall = true;
          inherit (cfg) dataDir;

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

            enabled_plugins =
              cfg.enabledPlugins
              ++ lib.optional (lib.any (x: x.enable) [
                config.services.radarr
                config.services.sonarr
                config.services.bazarr
                config.services.readarr
                config.services.lidarr
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

              dont_count_slow_torrents
              ;

            new_release_check = false;
          };

          authFile = "${cfg.dataDir}/.config/deluge/authTemplate";

          web.enable = true;
          web.port = cfg.webPort;
        };

        systemd.services.deluged.preStart = lib.mkBefore (
          shb.replaceSecrets {
            userConfig =
              cfg.extraUsers
              // {
                localclient.password.source = config.shb.deluge.localclientPassword.result.path;
              }
              // (lib.optionalAttrs (config.shb.deluge.prometheusScraperPassword != null) {
                prometheus_scraper.password.source = config.shb.deluge.prometheusScraperPassword.result.path;
              });
            resultPath = "${cfg.dataDir}/.config/deluge/authTemplate";
            generator = name: value: pkgs.writeText "delugeAuth" (authGenerator value);
          }
        );

        systemd.services.deluged.serviceConfig.ExecStart = lib.mkForce (
          lib.concatStringsSep " \\\n    " (
            [
              "${config.services.deluge.package}/bin/deluged"
              "--do-not-daemonize"
              "--config ${cfg.dataDir}/.config/deluge"
            ]
            ++ (lib.optional (!(isNull cfg.logLevel)) "-L ${cfg.logLevel}")
          )
        );

        systemd.tmpfiles.rules =
          let
            plugins = pkgs.symlinkJoin {
              name = "deluge-plugins";
              paths = cfg.additionalPlugins;
            };
          in
          [
            "L+ ${cfg.dataDir}/.config/deluge/plugins - - - - ${plugins}"
          ];

        shb.nginx.vhosts = [
          (
            {
              inherit (cfg) subdomain domain ssl;
              upstream = "http://127.0.0.1:${toString config.services.deluge.web.port}";
              autheliaRules = lib.mkIf (cfg.authEndpoint != null) [
                {
                  domain = fqdn;
                  policy = "bypass";
                  resources = [
                    "^/json"
                  ];
                }
                {
                  domain = fqdn;
                  policy = "two_factor";
                  subject = [ "group:deluge_user" ];
                }
              ];
            }
            // (lib.optionalAttrs (cfg.authEndpoint != null) {
              inherit (cfg) authEndpoint;
            })
          )
        ];
      }
      {
        systemd.services.deluged.serviceConfig = cfg.extraServiceConfig;
      }
      (lib.mkIf (config.shb.deluge.prometheusScraperPassword != null) {
        services.prometheus.exporters.deluge = {
          enable = true;

          delugeHost = "127.0.0.1";
          delugePort = config.services.deluge.config.daemon_port;
          delugeUser = "prometheus_scraper";
          delugePasswordFile = config.shb.deluge.prometheusScraperPassword.result.path;
          exportPerTorrentMetrics = true;
        };

        services.prometheus.scrapeConfigs = [
          {
            job_name = "deluge";
            static_configs = [
              {
                targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.deluge.port}" ];
                labels = {
                  "hostname" = config.networking.hostName;
                  "domain" = cfg.domain;
                };
              }
            ];
          }
        ];
      })

      (lib.mkIf (cfg.enable && cfg.enableDashboard) {
        shb.monitoring.dashboards = [
          ./deluge/dashboard/Torrents.json
        ];
      })
    ]
  );
}
