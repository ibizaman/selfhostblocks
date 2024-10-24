{ config, pkgs, lib, ... }:

let
  cfg = config.shb.ldap;

  contracts = pkgs.callPackage ../contracts {};

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.ldap = {
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

    ldapUserPassword = contracts.secret.mkOption {
      description = "LDAP admin user secret.";
      mode = "0440";
      owner = "lldap";
      group = "lldap";
      restartUnits = [ "lldap.service" ];
    };

    jwtSecret = contracts.secret.mkOption {
      description = "JWT secret.";
      mode = "0440";
      owner = "lldap";
      group = "lldap";
      restartUnits = [ "lldap.service" ];
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
        } // config.shb.ldap.mount;
        ```
      '';
      readOnly = true;
      default = { path = "/var/lib/lldap"; };
    };

    backup = lib.mkOption {
      type = contracts.backup;
      description = ''
        Backup configuration. This is an output option.

        Use it to initialize a block implementing the "backup" contract.
        For example, with the restic block:

        ```
        shb.restic.instances."lldap" = {
          enable = true;

          # Options specific to Restic.
        } // config.shb.lldap.backup;
        ```
      '';
      readOnly = true;
      default = {
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

      environment = {
        LLDAP_JWT_SECRET_FILE = toString cfg.jwtSecret.result.path;
        LLDAP_LDAP_USER_PASS_FILE = toString cfg.ldapUserPassword.result.path;

        RUST_LOG = lib.mkIf cfg.debug "debug";
      };

      settings = {
        http_url = "https://${fqdn}";
        http_host = "127.0.0.1";
        http_port = cfg.webUIListenPort;

        ldap_host = "127.0.0.1";
        ldap_port = cfg.ldapPort;

        ldap_base_dn = cfg.dcdomain;

        verbose = cfg.debug;
      };
    };
  };
}
