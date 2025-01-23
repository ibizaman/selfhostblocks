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
    # TODO: Test login
    # extraScript = { ... }: ''
    # '';
  };

  basic = { config, ... }: {
    test = {
      subdomain = "g";
    };

    shb.grocy = {
      enable = true;
      inherit (config.test) subdomain domain;
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
        testLib.baseModule
        ../../modules/services/grocy.nix
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
        testLib.baseModule
        ../../modules/services/grocy.nix
        testLib.certs
        basic
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };
}
