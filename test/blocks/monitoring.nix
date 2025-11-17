{ lib, ... }:
let
  password = "securepw";

  commonTestScript = lib.shb.accessScript {
    hasSSL = { node, ... }: !(isNull node.config.shb.monitoring.ssl);
    waitForServices =
      { ... }:
      [
        "grafana.service"
      ];
    waitForPorts =
      { node, ... }:
      [
        node.config.shb.monitoring.grafanaPort
      ];
  };

  basic =
    { config, ... }:
    {
      test = {
        subdomain = "g";
      };

      shb.monitoring = {
        enable = true;
        inherit (config.test) subdomain domain;

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

  https =
    { config, ... }:
    {
      shb.monitoring = {
        ssl = config.shb.certs.certs.selfsigned.n;
      };
    };
in
{
  basic = lib.shb.runNixOSTest {
    name = "monitoring_basic";

    nodes.server = {
      imports = [
        lib.shb.baseModule
        ../../modules/blocks/monitoring.nix
        basic
      ];
    };

    nodes.client = { };

    testScript = commonTestScript;
  };

  https = lib.shb.runNixOSTest {
    name = "monitoring_https";

    nodes.server = {
      imports = [
        lib.shb.baseModule
        ../../modules/blocks/monitoring.nix
        lib.shb.certs
        basic
        https
      ];
    };

    nodes.client = { };

    testScript = commonTestScript;
  };
}
