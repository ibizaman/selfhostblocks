{ pkgs, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "h";
  domain = "example.com";

  adminPassword = "AdminPassword";

  commonTestScript = testLib.mkScripts {
    inherit subdomain domain;
    hasSSL = { node, ... }: !(isNull node.config.shb.hledger.ssl);
    waitForServices = { ... }: [
      "hledger-web.service"
      "nginx.service"
    ];
  };

  base = testLib.base pkgs' [
    ../../modules/services/hledger.nix
  ];

  basic = { config, ... }: {
    shb.hledger = {
      enable = true;
      inherit domain subdomain;
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
        base
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
        base
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
        base
        (testLib.certs domain)
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

    testScript = commonTestScript.access.override {
      redirectSSO = true;
    };
  };
}
