{
  config,
  pkgs,
  lib,
  shb,
  ...
}:

let
  cfg = config.shb.navidrome;

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  protocol = if !(isNull cfg.ssl) then "https" else "http";

  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    ;
  inherit (lib.types)
    attrs
    bool
    nullOr
    port
    str
    submodule
    ;
in
{
  imports = [
    ../../lib/module.nix
    ../blocks/nginx.nix
  ];

  options.shb.navidrome = {
    enable = mkEnableOption "selfhostblocks.navidrome";

    subdomain = mkOption {
      type = str;
      description = "Subdomain under which Navidrome will be served.";
      example = "music";
    };

    domain = mkOption {
      type = str;
      description = "Domain under which Navidrome will be served.";
      example = "example.com";
    };

    port = mkOption {
      type = port;
      default = 4533;
      description = "Port under which Navidrome will listen.";
    };

    ssl = mkOption {
      type = nullOr shb.contracts.ssl.certs;
      default = null;
      description = "Path to SSL files";
    };

    musicDir = mkOption {
      type = str;
      default = "/var/lib/navidrome/music";
      description = "Directory where your music library is stored.";
    };

    dataDir = mkOption {
      type = str;
      default = "/var/lib/navidrome/data";
      description = "Directory to store application data (DB, cache).";
    };

    enableSharing = mkOption {
      type = bool;
      default = false;
      description = "Enable public music sharing feature.";
    };

    settings = mkOption {
      type = attrs;
      default = { };
      description = ''
        Navidrome configuration settings. These get written to the Navidrome 
        configuration JSON.

        See https://www.navidrome.org/docs/usage/configuration/options/ for 
        available options.
      '';
      example = {
        LogLevel = "DEBUG";
        Scanner.Schedule = "@every 24h";
        SessionTimeout = "24h";
        EnableUserEditing = false;
      };
    };

    sso = mkOption {
      description = "SSO Configuration";
      default = { };
      type = submodule {
        options = {
          enable = mkEnableOption "SSO";

          endpoint = mkOption {
            type = str;
            description = "Authelia endpoint URL.";
            example = "https://auth.example.com";
          };

          authorization_policy = mkOption {
            type = lib.types.enum [
              "one_factor"
              "two_factor"
            ];
            description = "Require one factor (password) or two factor (device) authentication.";
            default = "one_factor";
          };

          logoutURL = mkOption {
            type = nullOr str;
            default = null;
            description = "URL to redirect to after logout for SSO session termination.";
            example = "https://auth.example.com/logout";
          };

          userGroup = mkOption {
            type = str;
            default = "navidrome_user";
            description = "LDAP group for authorized users.";
          };
        };
      };
    };

    mount = mkOption {
      type = shb.contracts.mount;
      description = ''
        Mount configuration. This is an output option.

        Use it to initialize a block implementing the "mount" contract.
        For example, with a zfs dataset:

        ```
        shb.zfs.datasets."navidrome" = {
          poolName = "root";
        } // config.shb.navidrome.mount;
        ```
      '';
      readOnly = true;
      default = {
        path = cfg.dataDir;
      };
    };

    backup = mkOption {
      description = ''
        Backup configuration for Navidrome data and music files.
      '';
      default = { };
      type = submodule {
        options = shb.contracts.backup.mkRequester {
          user = "navidrome";
          sourceDirectories = [
            cfg.dataDir
            cfg.musicDir
          ];
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
          externalUrl = "${protocol}://${fqdn}";
          externalUrlText = "https://\${config.shb.navidrome.subdomain}.\${config.shb.navidrome.domain}";
          internalUrl = "http://127.0.0.1:${toString cfg.port}";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(isNull cfg.ssl) -> !(isNull cfg.ssl.paths.cert) && !(isNull cfg.ssl.paths.key);
        message = "SSL is enabled for Navidrome but no cert or key is provided.";
      }
      {
        assertion = cfg.sso.enable -> cfg.ssl != null;
        message = "To integrate SSO, SSL must be enabled, set the shb.navidrome.ssl option.";
      }
    ];

    services.navidrome = {
      enable = true;
      settings =
        cfg.settings
        // {
          MusicFolder = cfg.musicDir;
          DataFolder = cfg.dataDir;
          EnableSharing = cfg.enableSharing;
          Port = cfg.port;
          Address = "127.0.0.1";
        }
        // lib.optionalAttrs (cfg.sso.enable) {
          ExtAuth.TrustedSources = "127.0.0.1/32";
          ExtAuth.UserHeader = "X-Forwarded-User";
        }
        // lib.optionalAttrs (cfg.sso.enable && cfg.sso.logoutURL != null) {
          ExtAuth.LogoutURL = cfg.sso.logoutURL;
        };
    };

    shb.nginx.vhosts = [
      {
        inherit (cfg) subdomain domain ssl;
        upstream = "http://127.0.0.1:${toString cfg.port}";
        autheliaRules = lib.mkIf (cfg.sso.enable) [
          {
            domain = fqdn;
            policy = "bypass";
            resources = [
              "^/rest"
            ]
            ++ lib.optionals cfg.enableSharing [
              "^/share"
            ];
          }
          {
            domain = fqdn;
            policy = cfg.sso.authorization_policy;
            subject = [ "group:${cfg.sso.userGroup}" ];
          }
        ];
        authEndpoint = lib.mkIf (cfg.sso.enable) cfg.sso.endpoint;
      }
    ];

    services.nginx.virtualHosts."${fqdn}" = lib.mkIf cfg.sso.enable {
      extraConfig = ''
        client_max_body_size 100M;
      '';
    };
  };
}
