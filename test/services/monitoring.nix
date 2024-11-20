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
      adminPassword.result = config.shb.hardcodedsecret."admin_password".result;
      secretKey.result = config.shb.hardcodedsecret."secret_key".result;
    };

    shb.hardcodedsecret."admin_password" = {
      request = config.shb.monitoring.adminPassword.request;
      settings.content = password;
    };
    shb.hardcodedsecret."secret_key" = {
      request = config.shb.monitoring.secretKey.request;
      settings.content = "secret_key_pw";
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
