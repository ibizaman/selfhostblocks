{ pkgs, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "f";
  domain = "example.com";

  adminPassword = "AdminPassword";

  commonTestScript = testLib.mkScripts {
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

      adminPassword.result = config.shb.hardcodedsecret.forgejoAdminPassword.result;
      databasePassword.result = config.shb.hardcodedsecret.forgejoDatabasePassword.result;
    };

    # Needed for gitea-runner-local to be able to ping forgejo.
    networking.hosts = {
      "127.0.0.1" = [ "${subdomain}.${domain}" ];
    };

    shb.hardcodedsecret.forgejoAdminPassword = {
      request = config.shb.forgejo.adminPassword.request;
      settings.content = adminPassword;
    };

    shb.hardcodedsecret.forgejoDatabasePassword = {
      request = config.shb.forgejo.databasePassword.request;
      settings.content = "databasePassword";
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
        adminPassword.result = config.shb.hardcodedsecret.forgejoLdapUserPassword.result;
      };
    };

    shb.hardcodedsecret.forgejoLdapUserPassword = {
      request = config.shb.forgejo.ldap.adminPassword.request;
      settings.content = "ldapUserPassword";
    };
  };

  sso = { config, ... }: {
    shb.forgejo = {
      sso = {
        enable = true;
        endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        sharedSecret.result = config.shb.hardcodedsecret.forgejoSSOPassword.result;
        sharedSecretForAuthelia.result = config.shb.hardcodedsecret.forgejoSSOPasswordAuthelia.result;
      };
    };

    shb.hardcodedsecret.forgejoSSOPassword = {
      request = config.shb.forgejo.sso.sharedSecret.request;
      settings.content = "ssoPassword";
    };

    shb.hardcodedsecret.forgejoSSOPasswordAuthelia = {
      request = config.shb.forgejo.sso.sharedSecretForAuthelia.request;
      settings.content = "ssoPassword";
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

    testScript = commonTestScript.access;
  };

  backup = pkgs.testers.runNixOSTest {
    name = "forgejo_backup";

    nodes.server = { config, ... }: {
      imports = [
        base
        basic
        (testLib.backup config.shb.forgejo.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
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

    testScript = commonTestScript.access;
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
  
    testScript = commonTestScript.access;
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

    testScript = commonTestScript.access;
  };
}
