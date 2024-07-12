{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "ha";
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";

  commonTestScript = testLib.accessScript {
    inherit fqdn;
    hasSSL = { node, ... }: !(isNull node.config.shb.home-assistant.ssl);
    waitForServices = { ... }: [
      "home-assistant.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      8123
    ];
  };

  base = { config, ... }: {
    imports = [
      (pkgs'.path + "/nixos/modules/profiles/headless.nix")
      (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
      {
        options = {
          shb.backup = lib.mkOption { type = lib.types.anything; };
        };
      }
      ../../modules/blocks/nginx.nix
      ../../modules/blocks/postgresql.nix
      ../../modules/blocks/ssl.nix
      ../../modules/services/home-assistant.nix
    ];

    # Nginx port.
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    shb.certs = {
      cas.selfsigned.myca = {
        name = "My CA";
      };
      certs.selfsigned = {
        n = {
          ca = config.shb.certs.cas.selfsigned.myca;
          domain = "*.${domain}";
          group = "nginx";
        };
      };
    };

    systemd.services.nginx.after = [ config.shb.certs.certs.selfsigned.n.systemdService ];
    systemd.services.nginx.requires = [ config.shb.certs.certs.selfsigned.n.systemdService ];
  };

  basic = { config, ... }: {
    shb.home-assistant = {
      enable = true;
      inherit subdomain domain;
      ssl = config.shb.certs.certs.selfsigned.n;

      config = {
        name = "Tiserbox";
        country = "My Country";
        latitude = "01.0000000000";
        longitude.source = pkgs.writeText "longitude" "01.0000000000";
        time_zone = "America/Los_Angeles";
        unit_system = "metric";
      };
    };
  };

  ldap = { config, ... }: {
    imports = [
      ../../modules/blocks/ldap.nix
    ];

    shb.ldap = {
      enable = true;
      inherit domain;
      subdomain = "ldap";
      ldapPort = 3890;
      webUIListenPort = 17170;
      dcdomain = "dc=example,dc=com";
      ldapUserPasswordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
      jwtSecretFile = pkgs.writeText "jwtSecret" "jwtSecret";
    };

    networking.hosts = {
      "127.0.0.1" = [ "${config.shb.ldap.subdomain}.${domain}" ];
    };

    shb.home-assistant = {
      ldap = {
        enable = true;
        host = "127.0.0.1";
        port = config.shb.ldap.webUIListenPort;
        userGroup = "homeassistant_user";
      };
    };
  };

  # Not yet supported
  #
  # sso = { config, ... }: {
  #   imports = [
  #     ../../modules/blocks/authelia.nix
  #   ];
  #
  #   shb.authelia = {
  #     enable = true;
  #     inherit domain;
  #     subdomain = "auth";
  #     ssl = config.shb.certs.certs.selfsigned.n;
  #
  #     ldapEndpoint = "ldap://127.0.0.1:${builtins.toString config.shb.ldap.ldapPort}";
  #     dcdomain = config.shb.ldap.dcdomain;
  #
  #     secrets = {
  #       jwtSecretFile = pkgs.writeText "jwtSecret" "jwtSecret";
  #       ldapAdminPasswordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
  #       sessionSecretFile = pkgs.writeText "sessionSecret" "sessionSecret";
  #       storageEncryptionKeyFile = pkgs.writeText "storageEncryptionKey" "storageEncryptionKey";
  #       identityProvidersOIDCHMACSecretFile = pkgs.writeText "identityProvidersOIDCHMACSecret" "identityProvidersOIDCHMACSecret";
  #       identityProvidersOIDCIssuerPrivateKeyFile = (pkgs.runCommand "gen-private-key" {} ''
  #         mkdir $out
  #         ${pkgs.openssl}/bin/openssl genrsa -out $out/private.pem 4096
  #       '') + "/private.pem";
  #     };
  #   };
  #
  #   networking.hosts = {
  #     "127.0.0.1" = [ "${config.shb.authelia.subdomain}.${domain}" ];
  #   };
  # };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "vaultwarden_basic";

    nodes.server = lib.mkMerge [
      base
      basic
      {
        options = {
          shb.authelia = lib.mkOption { type = lib.types.anything; };
        };
      }
    ];

    nodes.client = {};

    testScript = commonTestScript;
  };

  ldap = pkgs.testers.runNixOSTest {
    name = "vaultwarden_ldap";
  
    nodes.server = lib.mkMerge [ 
      base
      basic
      ldap
      {
        options = {
          shb.authelia = lib.mkOption { type = lib.types.anything; };
        };
      }
    ];
  
    nodes.client = {};
  
    testScript = commonTestScript;
  };

  # Not yet supported
  #
  # sso = pkgs.testers.runNixOSTest {
  #   name = "vaultwarden_sso";
  #
  #   nodes.server = lib.mkMerge [ 
  #     base
  #     basic
  #     ldap
  #     sso
  #   ];
  #
  #   nodes.client = {};
  #
  #   testScript = commonTestScript;
  # };
}
