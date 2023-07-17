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

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Sops file location";
      example = "secrets/ldap.yaml";
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
      };

      settings = {
        http_url = "https://${fqdn}";
        http_host = "127.0.0.1";
        http_port = 17170;

        ldap_host = "127.0.0.1";
        ldap_port = 3890;

        ldap_base_dn = cfg.dcdomain;
      };
    };

    shb.backup.instances.lldap = {
      sourceDirectories = [
        "/var/lib/lldap"
      ];
    };
  };
}
