{ pkgs, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "j";
  domain = "example.com";

  commonTestScript = testLib.accessScript {
    inherit subdomain domain;
    hasSSL = { node, ... }: !(isNull node.config.shb.jellyfin.ssl);
    waitForServices = { ... }: [
      "jellyfin.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      8096
    ];
  };

  base = testLib.base pkgs' [
    ../../modules/services/jellyfin.nix
  ];

  basic = {
    shb.jellyfin = {
      enable = true;
      inherit domain subdomain;
    };
  };

  https = { config, ... }: {
    shb.jellyfin = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  ldap = { config, ... }: {
    shb.jellyfin = {
      ldap = {
        enable = true;
        host = "127.0.0.1";
        port = config.shb.ldap.ldapPort;
        dcdomain = config.shb.ldap.dcdomain;
        adminPassword.result.path = config.shb.hardcodedsecret.jellyfinLdapUserPassword.path;
      };
    };

    shb.hardcodedsecret.jellyfinLdapUserPassword = config.shb.jellyfin.ldap.adminPassword.request // {
      content = "ldapUserPassword";
    };
  };

  sso = { config, ... }: {
    shb.jellyfin = {
      sso = {
        enable = true;
        endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        sharedSecret.result.path = config.shb.hardcodedsecret.jellyfinSSOPassword.path;
        sharedSecretForAuthelia.result.path = config.shb.hardcodedsecret.jellyfinSSOPasswordAuthelia.path;
      };
    };

    shb.hardcodedsecret.jellyfinSSOPassword = config.shb.jellyfin.sso.sharedSecret.request // {
      content = "ssoPassword";
    };

    shb.hardcodedsecret.jellyfinSSOPasswordAuthelia = config.shb.jellyfin.sso.sharedSecretForAuthelia.request // {
      content = "ssoPassword";
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "jellyfin_basic";

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
    name = "jellyfin_https";

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
    name = "jellyfin_ldap";

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
    name = "jellyfin_sso";

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
