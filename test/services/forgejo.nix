{ pkgs, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "f";
  domain = "example.com";

  adminPassword = "AdminPassword";

  commonTestScript = testLib.accessScript {
    inherit subdomain domain;
    hasSSL = { node, ... }: !(isNull node.config.shb.forgejo.ssl);
    waitForServices = { ... }: [
      "forgejo.service"
      "nginx.service"
    ];
    waitForUnixSocket = { node, ... }: [
      node.config.services.forgejo.settings.server.HTTP_ADDR
    ];
    extraScript = { node, ... }: ''
    server.wait_for_unit("gitea-runner-local.service", timeout=10)
    server.succeed("journalctl -o cat -u gitea-runner-local.service | grep -q 'Runner registered successfully'")
    '';
  };

  base = testLib.base pkgs' [
    ../../modules/services/forgejo.nix
  ];

  basic = {
    shb.forgejo = {
      enable = true;
      inherit domain subdomain;

      adminPasswordFile = pkgs.writeText "adminPasswordFile" adminPassword;
      databasePasswordFile = pkgs.writeText "databasePassword" "databasePassword";
    };

    # Needed for gitea-runner-local to be able to ping forgejo.
    networking.hosts = {
      "127.0.0.1" = [ "${subdomain}.${domain}" ];
    };
  };

  https = { config, ... }: {
    shb.forgejo = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  ldap = { config, ... }: {
    shb.forgejo = {
      ldap = {
        enable = true;
        host = "127.0.0.1";
        port = config.shb.ldap.ldapPort;
        dcdomain = config.shb.ldap.dcdomain;
        adminPasswordFile = config.shb.ldap.ldapUserPassword.result.path;
      };
    };
  };

  sso = { config, ... }: {
    shb.forgejo = {
      sso = {
        enable = true;
        endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        secretFile = pkgs.writeText "ssoSecretFile" "ssoSecretFile";
        secretFileForAuthelia = pkgs.writeText "ssoSecretFile" "ssoSecretFile";
      };
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "forgejo_basic";

    nodes.server = {
      imports = [
        base
        basic
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  https = pkgs.testers.runNixOSTest {
    name = "forgejo_https";

    nodes.server = {
      imports = [
        base
        (testLib.certs domain)
        basic
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  ldap = pkgs.testers.runNixOSTest {
    name = "forgejo_ldap";

    nodes.server = {
      imports = [
        base
        basic
        (testLib.ldap domain pkgs')
        ldap
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript;
  };

  sso = pkgs.testers.runNixOSTest {
    name = "forgejo_sso";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        base
        (testLib.certs domain)
        basic
        https
        (testLib.ldap domain pkgs')
        (testLib.sso domain pkgs' config.shb.certs.certs.selfsigned.n)
        sso
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };
}
