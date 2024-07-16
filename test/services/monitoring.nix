{ pkgs, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "grafana";
  domain = "example.com";

  password = "securepw";

  commonTestScript = testLib.accessScript {
    inherit subdomain domain;
    hasSSL = { node, ... }: !(isNull node.config.shb.monitoring.ssl);
    waitForServices = { ... }: [
      "grafana.service"
    ];
    waitForPorts = { node, ... }: [
      node.config.shb.monitoring.grafanaPort
    ];
  };

  base = testLib.base pkgs' [
    ../../modules/blocks/monitoring.nix
  ];

  basic = { config, ... }: {
    shb.monitoring = {
      enable = true;
      inherit subdomain domain;

      grafanaPort = 3000;
      adminPasswordFile = pkgs.writeText "admin_password" password;
      secretKeyFile = pkgs.writeText "secret_key" "secret_key";
    };
  };

  https = { config, ...}: {
    shb.monitoring = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "monitoring_basic";

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
    name = "monitoring_https";

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
