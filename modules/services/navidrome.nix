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

    ssl = mkOption {
      type = nullOr shb.contracts.ssl.certs;
      default = null;
      description = "Path to SSL files";
    };

    port = mkOption {
      type = port;
      default = 4533;
      description = "Port under which Navidrome will listen.";
    };

    musicFolder = mkOption {
      type = str;
      default = "/var/lib/navidrome/music";
      description = "Folder where your music library is stored.";
    };

    dataFolder = mkOption {
      type = str;
      default = "/var/lib/navidrome/data";
      description = "Folder to store application data (DB, cache).";
    };

    settings = mkOption {
      type = attrs;
      default = { };
      description = ''
        Navidrome configuration settings.
        Only specify settings that you want SHB to manage declaratively.
        Other settings can be changed through Navidrome's admin UI.

        See https://www.navidrome.org/docs/usage/configuration/options/ for available options.
      '';
      example = {
        LogLevel = "DEBUG";
        Scanner.Schedule = "@every 24h";
        SessionTimeout = "24h";
        EnableUserEditing = false;
      };
    };

    sso = mkOption {
      description = "Authelia forward auth configuration.";
      default = { };
      type = submodule {
        options = {
          enable = mkEnableOption "Header-based authentication with Authelia.";

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
        path = cfg.dataFolder;
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
            cfg.dataFolder
            cfg.musicFolder
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
          MusicFolder = cfg.musicFolder;
          DataFolder = cfg.dataFolder;
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
              "^/share"
              "^/rest"
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
