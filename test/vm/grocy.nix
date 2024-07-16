{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "g";
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";

  commonTestScript = lib.makeOverridable testLib.accessScript {
    inherit subdomain domain;
    hasSSL = { node, ... }: !(isNull node.config.shb.grocy.ssl);
    waitForServices = { ... }: [
      "phpfpm-grocy.service"
      "nginx.service"
    ];
    waitForUnixSocket = { node, ... }: [
      node.config.services.phpfpm.pools.grocy.socket
    ];
    # TODO: Test login
    # extraScript = { ... }: ''
    # '';
  };

  base = testLib.base pkgs' [
    ../../modules/services/grocy.nix
  ];

  basic = { config, ... }: {
    shb.grocy = {
      enable = true;
      inherit domain subdomain;
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
    name = "grocy_https";

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
}
