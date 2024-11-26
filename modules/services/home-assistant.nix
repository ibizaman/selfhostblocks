{ config, pkgs, lib, ... }:

let
  cfg = config.shb.home-assistant;

  contracts = pkgs.callPackage ../contracts {};
  shblib = pkgs.callPackage ../../lib {};

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

  # Filter secrets from config. Secrets are those of the form { source = <path>; }
  secrets = lib.attrsets.filterAttrs (k: v: builtins.isAttrs v) cfg.config;

  nonSecrets = (lib.attrsets.filterAttrs (k: v: !(builtins.isAttrs v)) cfg.config);

  configWithSecretsIncludes =
    nonSecrets
    // (lib.attrsets.mapAttrs (k: v: "!secret ${k}") secrets);
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

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    config = lib.mkOption {
      description = "See all available settings at https://www.home-assistant.io/docs/configuration/basic/";
      type = lib.types.submodule {
        freeformType = lib.types.attrsOf lib.types.str;
        options = {
          name = lib.mkOption {
            type = lib.types.oneOf [ lib.types.str shblib.secretFileType ];
            description = "Name of the Home Assistant instance.";
          };
          country = lib.mkOption {
            type = lib.types.oneOf [ lib.types.str shblib.secretFileType ];
            description = "Two letter country code where this instance is located.";
          };
          latitude = lib.mkOption {
            type = lib.types.oneOf [ lib.types.str shblib.secretFileType ];
            description = "Latitude where this instance is located.";
          };
          longitude = lib.mkOption {
            type = lib.types.oneOf [ lib.types.str shblib.secretFileType ];
            description = "Longitude where this instance is located.";
          };
          time_zone = lib.mkOption {
            type = lib.types.oneOf [ lib.types.str shblib.secretFileType ];
            description = "Timezone of this instance.";
            example = "America/Los_Angeles";
          };
          unit_system = lib.mkOption {
            type = lib.types.oneOf [ lib.types.str (lib.types.enum [ "metric" "us_customary" ]) ];
            description = "Timezone of this instance.";
            example = "America/Los_Angeles";
          };
        };
      };
    };

    ldap = lib.mkOption {
      description = ''
        LDAP Integration App. [Manual](https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_auth_ldap.html)

        Enabling this app will create a new LDAP configuration or update one that exists with
        the given host.

        Also, enabling LDAP will skip onboarding
        otherwise Home Assistant gets into a cyclic lock.
      '';
      default = {};
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "LDAP app.";

          host = lib.mkOption {
            type = lib.types.str;
            description = ''
              Host serving the LDAP server.


              If set, the Home Assistant auth will be disabled. To keep it, set
              `keepDefaultAuth` to `true`.
            '';
            default = "127.0.0.1";
          };

          port = lib.mkOption {
            type = lib.types.port;
            description = ''
              Port of the service serving the LDAP server.
            '';
            default = 389;
          };

          userGroup = lib.mkOption {
            type = lib.types.str;
            description = "Group users must belong to to be able to login to Nextcloud.";
            default = "homeassistant_user";
          };

          keepDefaultAuth = lib.mkOption {
            type = lib.types.bool;
            description = ''
              Keep Home Assistant auth active, even if LDAP is configured. Usually, you want to enable
              this to transfer existing users to LDAP and then you can disabled it.
            '';
            default = false;
          };
        };
      };
    };

    backup = lib.mkOption {
      description = ''
        Backup configuration.
      '';
      type = lib.types.submodule {
        options = contracts.backup.mkRequester {
          user = "hass";
          # No need for backup hooks as we use an hourly automation job in home assistant directly with a cron job.
          sourceDirectories = [
            "/var/lib/hass/backups"
          ];
        };
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
        homeassistant = configWithSecretsIncludes // {
          external_url = "https://${cfg.subdomain}.${cfg.domain}";
          auth_providers =
            (lib.optionals (!cfg.ldap.enable || cfg.ldap.keepDefaultAuth) [
              {
                type = "homeassistant";
              }
            ])
            ++ (lib.optionals cfg.ldap.enable [
              {
                type = "command_line";
                command = ldap_auth_script + "/bin/ldap_auth.sh";
                args = [ "http://${cfg.ldap.host}:${toString cfg.ldap.port}" cfg.ldap.userGroup ];
                meta = true;
              }
            ]);
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

        conversation.intents = {
          TellJoke = [
            "Tell [me] (a joke|something funny|a dad joke)"
            "Raconte [moi] (une blague)"
          ];
        };
        sensor = [
          {
            name = "random_joke";
            platform = "rest";
            json_attributes = ["joke" "id" "status"];
            value_template = "{{ value_json.joke }}";
            resource = "https://icanhazdadjoke.com/";
            scan_interval = "3600";
            headers.Accept = "application/json";
          }
        ];
        intent_script.TellJoke = {
          speech.text = ''{{ state_attr("sensor.random_joke", "joke") }}'';
          action = {
            service = "homeassistant.update_entity";
            entity_id = "sensor.random_joke";
          };
        };
      };
    };

    services.nginx.virtualHosts."${fqdn}" = {
      http2 = true;

      forceSSL = !(isNull cfg.ssl);
      sslCertificate = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.cert;
      sslCertificateKey = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.key;

      extraConfig = ''
        proxy_buffering off;
      '';
      locations."/" = {
        proxyPass = "http://${toString config.services.home-assistant.config.http.server_host}:${toString config.services.home-assistant.config.http.server_port}/";
        proxyWebsockets = true;
      };
    };

    systemd.services.home-assistant.preStart = lib.mkIf cfg.ldap.enable (
      let
        onboarding = pkgs.writeText "onboarding" ''
          {
            "version": 4,
            "minor_version": 1,
            "key": "onboarding",
            "data": {
              "done": [
                "user",
                "core_config"
              ]
            }
          }
        '';
        storage = "${config.services.home-assistant.configDir}";
        file = "${storage}/.storage/onboarding";
      in
        ''
          if ! -f ${file}; then
            mkdir -p ''$(dirname ${file}) && cp ${onboarding} ${file}
          fi
        '' + shblib.replaceSecrets {
          userConfig = cfg.config;
          resultPath = "${config.services.home-assistant.configDir}/secrets.yaml";
          generator = shblib.replaceSecretsGeneratorAdapter (lib.generators.toYAML {});
        });

    systemd.tmpfiles.rules = [
      "f ${config.services.home-assistant.configDir}/automations.yaml 0755 hass hass"
      "f ${config.services.home-assistant.configDir}/scenes.yaml      0755 hass hass"
      "f ${config.services.home-assistant.configDir}/scripts.yaml     0755 hass hass"
    ];
  };
}
