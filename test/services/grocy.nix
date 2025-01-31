{ pkgs, lib, ... }:
let
  testLib = pkgs.callPackage ../common.nix {};

  commonTestScript = lib.makeOverridable testLib.accessScript {
    hasSSL = { node, ... }: !(isNull node.config.shb.grocy.ssl);
    waitForServices = { ... }: [
      "phpfpm-grocy.service"
      "nginx.service"
    ];
    waitForUnixSocket = { node, ... }: [
      node.config.services.phpfpm.pools.grocy.socket
    ];
  };

  basic = { config, ... }: {
    imports = [
      testLib.baseModule
      ../../modules/services/grocy.nix
    ];

    test = {
      subdomain = "g";
    };

    shb.grocy = {
      enable = true;
      inherit (config.test) subdomain domain;
    };
  };

  clientLogin = { config, ... }: {
    imports = [
      testLib.baseModule
      testLib.clientLoginModule
    ];
    virtualisation.memorySize = 4096;

    test = {
      subdomain = "g";
    };

    test.login = {
      startUrl = "http://${config.test.fqdn}";
      usernameFieldLabelRegex = "Username";
      passwordFieldLabelRegex = "Password";
      loginButtonNameRegex = "OK";
      testLoginWith = [
        { username = "admin"; password = "admin oops"; nextPageExpect = [
            "expect(page.get_by_text('Invalid credentials, please try again')).to_be_visible()"
          ]; }
        { username = "admin"; password = "admin"; nextPageExpect = [
            "expect(page.get_by_text('Invalid credentials, please try again')).not_to_be_visible()"
            "expect(page.get_by_role('button', name=re.compile('OK'))).not_to_be_visible()"
            "expect(page).to_have_title(re.compile('Grocy'))"
          ]; }
      ];
    };
  };

  https = { config, ...}: {
    shb.grocy = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "grocy_basic";

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

    nodes.client = {};

    testScript = commonTestScript;
  };

  https = pkgs.testers.runNixOSTest {
    name = "grocy_https";

    nodes.server = {
      imports = [
        basic
        testLib.certs
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };
}
