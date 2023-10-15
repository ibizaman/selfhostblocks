{ config, pkgs, lib, ... }:

let
  cfg = config.shb.ldap;

  fqdn = "${cfg.subdomain}.${cfg.domain}";
in
{
  options.shb.ldap = {
    enable = lib.mkEnableOption "selfhostblocks.home-assistant";

    dcdomain = lib.mkOption {
      type = lib.types.str;
      description = "dc domain for ldap.";
      example = "dc=mydomain,dc=com";
    };

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

    ladpPort = lib.mkOption {
      type = lib.types.port;
      description = "Port on which the server listens for the LDAP protocol.";
      default = 3890;
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      description = "Port on which the web UI is exposed.";
      default = 17170;
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file location";
      example = "secrets/ldap.yaml";
    };

    localNetworkIPRange = lib.mkOption {
      type = lib.types.str;
      description = "Local network range, to restrict access to the UI to only those IPs.";
      example = "192.168.1.1/24";
    };
  };

  
  config = lib.mkIf cfg.enable {
    sops.secrets."lldap/user_password" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = "lldap";
      group = "lldap";
      restartUnits = [ "lldap.service" ];
    };
    sops.secrets."lldap/jwt_secret" = {
      inherit (cfg) sopsFile;
      mode = "0440";
      owner = "lldap";
      group = "lldap";
      restartUnits = [ "lldap.service" ];
    };

    services.nginx = {
      enable = true;

      virtualHosts.${fqdn} = {
        forceSSL = true;
        sslCertificate = "/var/lib/acme/${cfg.domain}/cert.pem";
        sslCertificateKey = "/var/lib/acme/${cfg.domain}/key.pem";
        locations."/" = {
          extraConfig = ''
            proxy_set_header Host $host;
            allow ${cfg.localNetworkIPRange};
            deny all;
          '';
          proxyPass = "http://${toString config.services.lldap.settings.http_host}:${toString config.services.lldap.settings.http_port}/";
        };
      };
    };

    users.users.lldap = {
      name = "lldap";
      group = "lldap";
      isSystemUser = true;
    };

    users.groups.lldap = {
      members = [ "backup" ];
    };

    services.lldap = {
      enable = true;

      environment = {
        LLDAP_JWT_SECRET_FILE = "/run/secrets/lldap/jwt_secret";
        LLDAP_LDAP_USER_PASS_FILE = "/run/secrets/lldap/user_password";

        # RUST_LOG = "debug";
      };

      settings = {
        http_url = "https://${fqdn}";
        http_host = "127.0.0.1";
        http_port = cfg.httpPort;

        ldap_host = "127.0.0.1";
        ldap_port = cfg.ladpPort;

        ldap_base_dn = cfg.dcdomain;

        # verbose = true;
      };
    };

    shb.backup.instances.lldap = {
      sourceDirectories = [
        "/var/lib/lldap"
      ];
    };
  };
}
