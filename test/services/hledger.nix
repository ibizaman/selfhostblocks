{ pkgs, ... }:
let
  testLib = pkgs.callPackage ../common.nix {};

  adminPassword = "AdminPassword";

  commonTestScript = testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.hledger.ssl);
    waitForServices = { ... }: [
      "hledger-web.service"
      "nginx.service"
    ];
  };

  basic = { config, ... }: {
    imports = [
      testLib.baseModule
      ../../modules/services/hledger.nix
    ];

    test = {
      subdomain = "h";
    };

    shb.hledger = {
      enable = true;
      inherit (config.test) subdomain domain;
    };
  };

  clientLogin = { config, ... }: {
    imports = [
      testLib.baseModule
      testLib.clientLoginModule
    ];

    test = {
      subdomain = "h";
    };

    test.login = {
      startUrl = "http://${config.test.fqdn}";
      testLoginWith = [
        { nextPageExpect = [
            "expect(page).to_have_title('journal - hledger-web')"
          ]; }
      ];
    };
  };

  https = { config, ... }: {
    shb.hledger = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  sso = { config, ... }: {
    shb.hledger = {
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "hledger_basic";

    nodes.client = {
      imports = [
        clientLogin
      ];
    };

    nodes.server = {
      imports = [
        basic
      ];
    };

    testScript = commonTestScript.access;
  };

  backup = pkgs.testers.runNixOSTest {
    name = "hledger_backup";

    nodes.server = { config, ... }: {
      imports = [
        basic
        (testLib.backup config.shb.hledger.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };

  https = pkgs.testers.runNixOSTest {
    name = "hledger_https";

    nodes.server = {
      imports = [
        basic
        testLib.certs
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  sso = pkgs.testers.runNixOSTest {
    name = "hledger_sso";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        basic
        testLib.certs
        https
        testLib.ldap
        (testLib.sso config.shb.certs.certs.selfsigned.n)
        sso
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access.override {
      redirectSSO = true;
    };
  };
}
