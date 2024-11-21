{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "a";
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";

  commonTestScript = testLib.accessScript {
    inherit subdomain domain;
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

  base = testLib.base pkgs' [
    ../../modules/services/audiobookshelf.nix
  ];

  basic = {
    shb.audiobookshelf = {
      enable = true;
      inherit subdomain domain;
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
        base
        basic
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  https = pkgs.testers.runNixOSTest {
    name = "audiobookshelf-https";

    nodes.server = lib.mkMerge [
      base
      (testLib.certs domain)
      basic
      https
    ];

    nodes.client = {};

    testScript = commonTestScript;
  };

  sso = pkgs.testers.runNixOSTest {
    name = "audiobookshelf-sso";

    nodes.server = { config, ... }: {
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
