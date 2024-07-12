{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "a";
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";

  commonTestScript = testLib.accessScript {
    inherit fqdn;
    hasSSL = { node, ... }: !(isNull node.config.shb.audiobookshelf.ssl);
    waitForServices = { ... }: [
      "audiobookshelf.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      node.config.shb.audiobookshelf.webPort
    ];
    # TODO: Test login
    # extraScript = { ... }: ''
    # '';
  };

  base = {
    imports = [
      (pkgs'.path + "/nixos/modules/profiles/headless.nix")
      (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
      {
        options = {
          shb.backup = lib.mkOption { type = lib.types.anything; };
        };
      }
      ../../modules/services/audiobookshelf.nix
    ];

    # Nginx port.
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };

  certs = { config, ... }: {
    imports = [
      ../../modules/blocks/ssl.nix
    ];

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

  basic = {
    shb.audiobookshelf = {
      enable = true;
      inherit subdomain domain;
    };
  };

  https = { config, ... }: {
    shb.audiobookshelf = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  sso = { config, ... }: {
    imports = [
      ../../modules/blocks/authelia.nix
      ../../modules/blocks/ldap.nix
      ../../modules/blocks/postgresql.nix
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

    shb.authelia = {
      enable = true;
      inherit domain;
      subdomain = "auth";
      ssl = config.shb.certs.certs.selfsigned.n;

      ldapEndpoint = "ldap://127.0.0.1:${builtins.toString config.shb.ldap.ldapPort}";
      dcdomain = config.shb.ldap.dcdomain;

      secrets = {
        jwtSecretFile = pkgs.writeText "jwtSecret" "jwtSecret";
        ldapAdminPasswordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
        sessionSecretFile = pkgs.writeText "sessionSecret" "sessionSecret";
        storageEncryptionKeyFile = pkgs.writeText "storageEncryptionKey" "storageEncryptionKey";
        identityProvidersOIDCHMACSecretFile = pkgs.writeText "identityProvidersOIDCHMACSecret" "identityProvidersOIDCHMACSecret";
        identityProvidersOIDCIssuerPrivateKeyFile = (pkgs.runCommand "gen-private-key" {} ''
          mkdir $out
          ${pkgs.openssl}/bin/openssl genrsa -out $out/private.pem 4096
        '') + "/private.pem";
      };
    };

    shb.audiobookshelf = {
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
      ssoSecretFile = pkgs.writeText "ssoSecretFile" "ssoSecretFile";
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "audiobookshelf-basic";

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

  https = pkgs.testers.runNixOSTest {
    name = "audiobookshelf-https";

    nodes.server = lib.mkMerge [
      base
      certs
      basic
      https
      {
        options = {
          shb.authelia = lib.mkOption { type = lib.types.anything; };
        };
      }
    ];

    nodes.client = {};

    testScript = commonTestScript;
  };

  sso = pkgs.testers.runNixOSTest {
    name = "audiobookshelf-sso";

    nodes.server = lib.mkMerge [
      base
      certs
      basic
      https
      sso
    ];

    nodes.client = {};

    testScript = commonTestScript;
  };
}
