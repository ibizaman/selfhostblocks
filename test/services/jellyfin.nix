{ pkgs, ... }:
let
  testLib = pkgs.callPackage ../common.nix {};

  commonTestScript = testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.jellyfin.ssl);
    waitForServices = { ... }: [
      "jellyfin.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      8096
    ];
    waitForUrls = { proto_fqdn, ... }: [
      "${proto_fqdn}/System/Info/Public"
    ];
  };

  basic = { config, ... }: {
    test = {
      subdomain = "j";
    };

    shb.jellyfin = {
      enable = true;
      inherit (config.test) subdomain domain;
      debug = true;
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
        adminPassword.result = config.shb.hardcodedsecret.jellyfinLdapUserPassword.result;
      };
    };

    shb.hardcodedsecret.jellyfinLdapUserPassword = {
      request = config.shb.jellyfin.ldap.adminPassword.request;
      settings.content = "ldapUserPassword";
    };
  };

  sso = { config, ... }: {
    shb.jellyfin = {
      sso = {
        enable = true;
        endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        sharedSecret.result = config.shb.hardcodedsecret.jellyfinSSOPassword.result;
        sharedSecretForAuthelia.result = config.shb.hardcodedsecret.jellyfinSSOPasswordAuthelia.result;
      };
    };

    shb.hardcodedsecret.jellyfinSSOPassword = {
      request = config.shb.jellyfin.sso.sharedSecret.request;
      settings.content = "ssoPassword";
    };

    shb.hardcodedsecret.jellyfinSSOPasswordAuthelia = {
      request = config.shb.jellyfin.sso.sharedSecretForAuthelia.request;
      settings.content = "ssoPassword";
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "jellyfin_basic";

    nodes.server = {
      imports = [
        testLib.baseModule
        ../../modules/services/jellyfin.nix
        basic
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  backup = pkgs.testers.runNixOSTest {
    name = "jellyfin_backup";

    nodes.server = { config, ... }: {
      imports = [
        testLib.baseModule
        ../../modules/services/jellyfin.nix
        basic
        (testLib.backup config.shb.jellyfin.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };

  https = pkgs.testers.runNixOSTest {
    name = "jellyfin_https";

    nodes.server = {
      imports = [
        testLib.baseModule
        ../../modules/services/jellyfin.nix
        testLib.certs
        basic
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  ldap = pkgs.testers.runNixOSTest {
    name = "jellyfin_ldap";

    nodes.server = {
      imports = [
        testLib.baseModule
        ../../modules/services/jellyfin.nix
        basic
        testLib.ldap
        ldap
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript.access;
  };

  sso = pkgs.testers.runNixOSTest {
    name = "jellyfin_sso";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        testLib.baseModule
        ../../modules/services/jellyfin.nix
        testLib.certs
        basic
        https
        testLib.ldap
        (testLib.sso config.shb.certs.certs.selfsigned.n)
        sso
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };
}
