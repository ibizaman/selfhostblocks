{ lib, ... }:
let
  commonTestScript = lib.shb.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.hledger.ssl);
    waitForServices =
      { ... }:
      [
        "hledger-web.service"
        "nginx.service"
      ];
  };

  basic =
    { config, ... }:
    {
      imports = [
        lib.shb.baseModule
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

  clientLogin =
    { config, ... }:
    {
      imports = [
        lib.shb.baseModule
        lib.shb.clientLoginModule
      ];

      test = {
        subdomain = "h";
      };

      test.login = {
        startUrl = "http://${config.test.fqdn}";
        testLoginWith = [
          {
            nextPageExpect = [
              "expect(page).to_have_title('journal - hledger-web')"
            ];
          }
        ];
      };
    };

  https =
    { config, ... }:
    {
      shb.hledger = {
        ssl = config.shb.certs.certs.selfsigned.n;
      };
    };

  sso =
    { config, ... }:
    {
      shb.hledger = {
        authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
      };
    };
in
{
  basic = lib.shb.runNixOSTest {
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

  backup = lib.shb.runNixOSTest {
    name = "hledger_backup";

    nodes.server =
      { config, ... }:
      {
        imports = [
          basic
          (lib.shb.backup config.shb.hledger.backup)
        ];
      };

    nodes.client = { };

    testScript = commonTestScript.backup;
  };

  https = lib.shb.runNixOSTest {
    name = "hledger_https";

    nodes.server = {
      imports = [
        basic
        lib.shb.certs
        https
      ];
    };

    nodes.client = { };

    testScript = commonTestScript.access;
  };

  sso = lib.shb.runNixOSTest {
    name = "hledger_sso";

    nodes.server =
      { config, pkgs, ... }:
      {
        imports = [
          basic
          lib.shb.certs
          https
          lib.shb.ldap
          (lib.shb.sso config.shb.certs.certs.selfsigned.n)
          sso
        ];
      };

    nodes.client = { };

    testScript = commonTestScript.access.override {
      redirectSSO = true;
    };
  };
}
