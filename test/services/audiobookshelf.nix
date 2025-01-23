{ pkgs, ... }:
let
  testLib = pkgs.callPackage ../common.nix {};

  commonTestScript = testLib.accessScript {
    hasSSL = { node, ... }: !(isNull node.config.shb.audiobookshelf.ssl);
    waitForServices = { ... }: [
      "audiobookshelf.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      node.config.shb.audiobookshelf.webPort
    ];
    # TODO: Test login
    # extraScript = { ... }: ''
    # '';
  };

  basic = { config, ... }: {
    test = {
      subdomain = "a";
    };
    shb.audiobookshelf = {
      enable = true;
      inherit (config.test) subdomain domain;
    };
  };

  https = { config, ... }: {
    shb.audiobookshelf = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  sso = { config, ... }: {
    shb.audiobookshelf = {
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
      ssoSecret.result = config.shb.hardcodedsecret.ssoSecret.result;
    };

    shb.hardcodedsecret.ssoSecret = {
      request = config.shb.audiobookshelf.ssoSecret.request;
      settings.content = "ssoSecret";
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "audiobookshelf-basic";

    nodes.server = {
      imports = [
        testLib.baseModule
        ../../modules/services/audiobookshelf.nix
        basic
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  https = pkgs.testers.runNixOSTest {
    name = "audiobookshelf-https";

    nodes.server = {
      imports = [
        testLib.baseModule
        ../../modules/services/audiobookshelf.nix
        testLib.certs
        basic
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  sso = pkgs.testers.runNixOSTest {
    name = "audiobookshelf-sso";

    nodes.server = { config, ... }: {
      imports = [
        testLib.baseModule
        ../../modules/services/audiobookshelf.nix
        testLib.certs
        basic
        https
        testLib.ldap
        (testLib.sso config.shb.certs.certs.selfsigned.n)
        sso
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };
}
