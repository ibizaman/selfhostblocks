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
    test = {
      subdomain = "h";
    };

    shb.hledger = {
      enable = true;
      inherit (config.test) subdomain domain;
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

    nodes.server = {
      imports = [
        testLib.baseModule
        ../../modules/services/hledger.nix
        basic
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  backup = pkgs.testers.runNixOSTest {
    name = "hledger_backup";

    nodes.server = { config, ... }: {
      imports = [
        testLib.baseModule
        ../../modules/services/hledger.nix
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
        testLib.baseModule
        ../../modules/services/hledger.nix
        testLib.certs
        basic
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
        testLib.baseModule
        ../../modules/services/hledger.nix
        testLib.certs
        basic
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
