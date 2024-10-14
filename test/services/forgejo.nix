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

  basic = { config, ... }: {
    shb.forgejo = {
      enable = true;
      inherit domain subdomain;

      adminPassword.result.path = config.shb.hardcodedsecret.forgejoAdminPassword.path;
      databasePassword.result.path = config.shb.hardcodedsecret.forgejoDatabasePassword.path;
    };

    # Needed for gitea-runner-local to be able to ping forgejo.
    networking.hosts = {
      "127.0.0.1" = [ "${subdomain}.${domain}" ];
    };

    shb.hardcodedsecret.forgejoAdminPassword = config.shb.forgejo.adminPassword.request // {
      content = adminPassword;
    };

    shb.hardcodedsecret.forgejoDatabasePassword = config.shb.forgejo.databasePassword.request // {
      content = "databasePassword";
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
        adminPassword.result.path = config.shb.hardcodedsecret.forgejoLdapUserPassword.path;
      };
    };

    shb.hardcodedsecret.forgejoLdapUserPassword = config.shb.forgejo.ldap.adminPassword.request // {
      content = "ldapUserPassword";
    };
  };

  sso = { config, ... }: {
    shb.forgejo = {
      sso = {
        enable = true;
        endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        sharedSecret.result.path = config.shb.hardcodedsecret.forgejoSSOPassword.path;
        sharedSecretForAuthelia.result.path = config.shb.hardcodedsecret.forgejoSSOPasswordAuthelia.path;
      };
    };

    shb.hardcodedsecret.forgejoSSOPassword = config.shb.forgejo.sso.sharedSecret.request // {
      content = "ssoPassword";
    };

    shb.hardcodedsecret.forgejoSSOPasswordAuthelia = config.shb.forgejo.sso.sharedSecretForAuthelia.request // {
      content = "ssoPassword";
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
