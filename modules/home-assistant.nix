{ config, pkgs, lib, ... }:

let
  cfg = config.shb.home-assistant;

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  ldap_auth_script_repo = pkgs.fetchFromGitHub {
    owner = "lldap";
    repo = "lldap";
    rev = "7d1f5abc137821c500de99c94f7579761fc949d8";
    sha256 = "sha256-8D+7ww70Ja6Qwdfa+7MpjAAHewtCWNf/tuTAExoUrg0=";
  };

  ldap_auth_script = pkgs.writeShellScriptBin "ldap_auth.sh" ''
    export PATH=${pkgs.gnused}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin
    exec ${pkgs.bash}/bin/bash ${ldap_auth_script_repo}/example_configs/lldap-ha-auth.sh $@
  '';
in
{
  options.shb.home-assistant = {
    enable = lib.mkEnableOption "selfhostblocks.home-assistant";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which home-assistant will be served.";
      example = "ha";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "domain under which home-assistant will be served.";
      example = "mydomain.com";
    };

    ldapEndpoint = lib.mkOption {
      type = lib.types.str;
      description = "host serving the LDAP server";
      example = "http://127.0.0.1:389";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file location";
      example = "secrets/homeassistant.yaml";
    };

    backupCfg = lib.mkOption {
      type = lib.types.anything;
      description = "Backup configuration for home-assistant";
      default = {};
      example = {
        backend = "restic";
        repositories = [];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      # Find them at https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/home-assistant/component-packages.nix
      extraComponents = [
        # Components required to complete the onboarding
        "met"
        "radio_browser"
      ];
      configDir = "/var/lib/hass";
      # If you can't find a component in component-packages.nix, you can add them manually with something similar to:
      # extraPackages = python3Packages: [
      #   (python3Packages.simplisafe-python.overrideAttrs (old: rec {
      #     pname = "simplisafe-python";
      #     version = "5b003a9fa1abd00f0e9a0b99d3ee57c4c7c16bda";
      #     format = "pyproject";

      #     src = pkgs.fetchFromGitHub {
      #       owner = "bachya";
      #       repo = pname;
      #       rev = "${version}";
      #       hash = "sha256-Ij2e0QGYLjENi/yhFBQ+8qWEJp86cgwC9E27PQ5xNno=";
      #     };
      #   }))
      # ];
      config = {
        # Includes dependencies for a basic setup
        # https://www.home-assistant.io/integrations/default_config/
        default_config = {};
        http = {
          use_x_forwarded_for = true;
          server_host = "127.0.0.1";
          server_port = 8123;
          trusted_proxies = "127.0.0.1";
        };
        logger.default = "info";
        homeassistant = {
          external_url = "https://${cfg.subdomain}.${cfg.domain}";
          country = "!secret country";
          latitude = "!secret latitude_home";
          longitude = "!secret longitude_home";
          time_zone = "America/Los_Angeles";
          auth_providers = [
            # Ensure you have the homeassistant provider enabled if you want to continue using your existing accounts
            # { type = "homeassistant"; }
            { type = "command_line";
              command = ldap_auth_script + "/bin/ldap_auth.sh";
              # Only allow users in the 'homeassistant_user' group to login.
              # Change to ["https://lldap.example.com"] to allow all users
              args = [ cfg.ldapEndpoint "homeassistant_user" ];
              meta = true;
            }
          ];
        };
        "automation ui" = "!include automations.yaml";
        "scene ui" = "!include scenes.yaml";
        "script ui" = "!include scripts.yaml";

        "automation manual" = [
          {
            alias = "Create Backup on Schedule";
            trigger = [
              {
                platform = "time_pattern";
                minutes = "5";
              }
            ];
            action = [
              {
                service = "shell_command.delete_backups";
                data = {};
              }
              {
                service = "backup.create";
                data = {};
              }
            ];
            mode = "single";
          }
        ];

        shell_command = {
          delete_backups = "find ${config.services.home-assistant.configDir}/backups -type f -delete";
        };
      };
    };

    services.nginx.virtualHosts."${fqdn}" = {
      forceSSL = true;
      http2 = true;
      sslCertificate = "/var/lib/acme/${cfg.domain}/cert.pem";
      sslCertificateKey = "/var/lib/acme/${cfg.domain}/key.pem";
      extraConfig = ''
        proxy_buffering off;
      '';
      locations."/" = {
        proxyPass = "http://${toString config.services.home-assistant.config.http.server_host}:${toString config.services.home-assistant.config.http.server_port}/";
        proxyWebsockets = true;
      };
    };

    sops.secrets."home-assistant" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = "hass";
      group = "hass";
      path = "${config.services.home-assistant.configDir}/secrets.yaml";
      restartUnits = [ "home-assistant.service" ];
    };

    systemd.tmpfiles.rules = [
      "f ${config.services.home-assistant.configDir}/automations.yaml 0755 hass hass"
      "f ${config.services.home-assistant.configDir}/scenes.yaml      0755 hass hass"
      "f ${config.services.home-assistant.configDir}/scripts.yaml     0755 hass hass"
    ];

    shb.backup.instances.home-assistant = lib.mkIf (cfg.backupCfg != {}) (
      cfg.backupCfg
      // {
        sourceDirectories = [
          "${config.services.home-assistant.configDir}/backups"
        ];

        # No need for backup hooks as we use an hourly automation job in home assistant directly with a cron job.
      }
    );

    # Adds the "backup" user to the "hass" group.
    users.groups.hass = {
      members = [ "backup" ];
    };

    # This allows the "backup" user, member of the "backup" group, to access what's inside the home
    # folder, which is needed for accessing the "backups" folder. It allows to read (r), enter the
    # directory (x) but not modify what's inside.
    users.users.hass.homeMode = "0750";

    systemd.services.home-assistant.serviceConfig = {
      # This allows all members of the "hass" group to read files, list directories and enter
      # directories created by the home-assistant service. This is needed for the "backup" user,
      # member of the "hass" group, to backup what is inside the "backup/" folder.
      UMask = lib.mkForce "0027";
    };
  };
}
