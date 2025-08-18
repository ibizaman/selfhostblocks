{ config, pkgs, lib, ... }:

let
  cfg = config.shb.lldap;

  contracts = pkgs.callPackage ../contracts {};

  fqdn = "${cfg.subdomain}.${cfg.domain}";

  inherit (lib) mkOption types;

  ensureFormat = pkgs.formats.json { };

  ensureFieldsOptions = name: {
    name = mkOption {
      type = types.str;
      description = "Name of the field.";
      default = name;
    };

    attributeType = mkOption {
      type = types.enum [
        "STRING"
        "INTEGER"
        "JPEG"
        "DATE_TIME"
      ];
      description = "Attribute type.";
    };

    isEditable = mkOption {
      type = types.bool;
      description = "Is field editable.";
      default = true;
    };

    isList = mkOption {
      type = types.bool;
      description = "Is field a list.";
      default = false;
    };

    isVisible = mkOption {
      type = types.bool;
      description = "Is field visible in UI.";
      default = true;
    };
  };
in
{
  options.shb.lldap = {
    enable = lib.mkEnableOption "the LDAP service";

    dcdomain = lib.mkOption {
      type = lib.types.str;
      description = "dc domain to serve.";
      example = "dc=mydomain,dc=com";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain under which the LDAP service will be served.";
      example = "grafana";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain under which the LDAP service will be served.";
      example = "mydomain.com";
    };

    ldapPort = lib.mkOption {
      type = lib.types.port;
      description = "Port on which the server listens for the LDAP protocol.";
      default = 3890;
    };

    ssl = lib.mkOption {
      description = "Path to SSL files";
      type = lib.types.nullOr contracts.ssl.certs;
      default = null;
    };

    webUIListenPort = lib.mkOption {
      type = lib.types.port;
      description = "Port on which the web UI is exposed.";
      default = 17170;
    };

    ldapUserPassword = lib.mkOption {
      description = "LDAP admin user secret.";
      type = lib.types.submodule {
        options = contracts.secret.mkRequester {
          mode = "0440";
          owner = "lldap";
          group = "lldap";
          restartUnits = [ "lldap.service" ];
        };
      };
    };

    jwtSecret = lib.mkOption {
      description = "JWT secret.";
      type = lib.types.submodule {
        options = contracts.secret.mkRequester {
          mode = "0440";
          owner = "lldap";
          group = "lldap";
          restartUnits = [ "lldap.service" ];
        };
      };
    };

    restrictAccessIPRange = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Set a local network range to restrict access to the UI to only those IPs.";
      example = "192.168.1.1/24";
      default = null;
    };

    debug = lib.mkOption {
      description = "Enable debug logging.";
      type = lib.types.bool;
      default = false;
    };

    mount = lib.mkOption {
      type = contracts.mount;
      description = ''
        Mount configuration. This is an output option.

        Use it to initialize a block implementing the "mount" contract.
        For example, with a zfs dataset:

        ```
        shb.zfs.datasets."ldap" = {
          poolName = "root";
        } // config.shb.lldap.mount;
        ```
      '';
      readOnly = true;
      default = { path = "/var/lib/lldap"; };
    };

    backup = lib.mkOption {
      description = ''
        Backup configuration.
      '';
      type = lib.types.submodule {
        options = contracts.backup.mkRequester {
          # TODO: is there a workaround that avoid needing to use root?
          # root because otherwise we cannot access the private StateDiretory
          user = "root";
          # /private because the systemd service uses DynamicUser=true
          sourceDirectories = [
            "/var/lib/private/lldap"
          ];
        };
      };
    };

    ensureUsers = mkOption {
      description = ''
        Create the users defined here on service startup.

        If `enforceEnsure` option is `true`, the groups
        users belong to must be present in the `ensureGroups` option.

        Non-default options must be added to the `ensureGroupFields` option.
      '';
      default = { };
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            freeformType = ensureFormat.type;

            options = {
              id = mkOption {
                type = types.str;
                description = "Username.";
                default = name;
              };

              email = mkOption {
                type = types.str;
                description = "Email.";
              };

              password = mkOption {
                description = "Password.";
                type = lib.types.submodule {
                  options = contracts.secret.mkRequester {
                    mode = "0440";
                    owner = "lldap";
                    group = "lldap";
                    restartUnits = [ "lldap.service" ];
                  };
                };
              };

              displayName = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Display name.";
              };

              firstName = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "First name.";
              };

              lastName = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Last name.";
              };

              avatar_file = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Avatar file. Must be a valid path to jpeg file (ignored if avatar_url specified)";
              };

              avatar_url = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Avatar url. must be a valid URL to jpeg file (ignored if gravatar_avatar specified)";
              };

              gravatar_avatar = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Get avatar from Gravatar using the email.";
              };

              weser_avatar = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Convert avatar retrieved by gravatar or the URL.";
              };

              groups = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Groups the user would be a member of (all the groups must be specified in group config files).";
              };
            };
          }
        )
      );
    };

    ensureGroups = mkOption {
      description = ''
        Create the groups defined here on service startup.

        Non-default options must be added to the `ensureGroupFields` option.
      '';
      default = { };
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            freeformType = ensureFormat.type;

            options = {
              name = mkOption {
                type = types.str;
                description = "Name of the group.";
                default = name;
              };
            };
          }
        )
      );
    };

    ensureUserFields = mkOption {
      description = "Extra fields for users";
      default = { };
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = ensureFieldsOptions name;
          }
        )
      );
    };

    ensureGroupFields = mkOption {
      description = "Extra fields for groups";
      default = { };
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = ensureFieldsOptions name;
          }
        )
      );
    };
  };

  imports = [
    (lib.mkRenamedOptionModule [ "shb" "ldap" ] [ "shb" "lldap" ])
  ];
  
  config = lib.mkIf cfg.enable {

    services.nginx = {
      enable = true;

      virtualHosts.${fqdn} = {
        forceSSL = !(isNull cfg.ssl);
        sslCertificate = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.cert;
        sslCertificateKey = lib.mkIf (!(isNull cfg.ssl)) cfg.ssl.paths.key;
        locations."/" = {
          extraConfig = ''
            proxy_set_header Host $host;
          '' + (if isNull cfg.restrictAccessIPRange then "" else ''
            allow ${cfg.restrictAccessIPRange};
            deny all;
          '');
          proxyPass = "http://${toString config.services.lldap.settings.http_host}:${toString config.services.lldap.settings.http_port}/";
        };
      };
    };

    users.users.lldap = {
      name = "lldap";
      group = "lldap";
      isSystemUser = true;
    };
    users.groups.lldap = {};

    services.lldap = {
      enable = true;

      enforceEnsure = true;

      environment = {
        RUST_LOG = lib.mkIf cfg.debug "debug";
      };

      settings = {
        http_url = "https://${fqdn}";
        http_host = "127.0.0.1";
        http_port = cfg.webUIListenPort;

        ldap_host = "127.0.0.1";
        ldap_port = cfg.ldapPort;
        ldap_base_dn = cfg.dcdomain;

        ldap_user_pass_file = toString cfg.ldapUserPassword.result.path;
        force_ldap_user_pass_reset = "always";
        jwt_secret_file = toString cfg.jwtSecret.result.path;

        verbose = cfg.debug;
      };

      inherit (cfg) ensureGroups ensureUserFields ensureGroupFields;
      ensureUsers = lib.mapAttrs (n: v: (lib.removeAttrs v [ "password" ]) // {
        "password_file" = toString v.password.result.path;
      }) cfg.ensureUsers;
    };
  };
}
