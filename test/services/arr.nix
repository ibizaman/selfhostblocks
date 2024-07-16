{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  domain = "example.com";
  healthUrl = "/health";
  loginUrl = "/UI/Login";

  testLib = pkgs.callPackage ../common.nix {};

  # TODO: Test login
  commonTestScript = appname: cfgPathFn:
    let
      subdomain = appname;
      fqdn = "${subdomain}.${domain}";
    in testLib.accessScript {
      inherit subdomain domain;
      hasSSL = { node, ... }: !(isNull node.config.shb.arr.${appname}.ssl);
      waitForServices = { ... }: [
        "${appname}.service"
        "nginx.service"
      ];
      waitForPorts = { node, ... }: [
        node.config.shb.arr.${appname}.settings.Port
      ];
      extraScript = { node, proto_fqdn, ... }: let
        shbapp = node.config.shb.arr.${appname};
        cfgPath = cfgPathFn shbapp;
        apiKey = if (shbapp.settings ? ApiKey) then "01234567890123456789" else null;
      in ''
        with subtest("health"):
            response = curl(client, """{"code":%{response_code}}""", "${fqdn}${healthUrl}")

            if response['code'] != 200:
                raise Exception(f"Code is {response['code']}")

        with subtest("login"):
            response = curl(client, """{"code":%{response_code}}""", "${fqdn}${loginUrl}")

            if response['code'] != 200:
                raise Exception(f"Code is {response['code']}")
      '' + lib.optionalString (apiKey != null) ''

        with subtest("apikey"):
            config = server.succeed("cat ${cfgPath}")
            if "${apiKey}" not in config:
                raise Exception(f"Unexpected API Key. Want '${apiKey}', got '{config}'")
      '';
    };

  base = testLib.base pkgs' [
    ../../modules/services/arr.nix
  ];

  basic = appname: { ... }: {
    shb.arr.${appname} = {
      enable = true;
      inherit domain;
      subdomain = appname;

      settings.ApiKey.source = pkgs.writeText "APIKey" "01234567890123456789"; # Needs to be >=20 characters.
    };
  };

  basicTest = appname: cfgPathFn: pkgs.testers.runNixOSTest {
    name = "arr-${appname}-basic";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        base
        (basic appname)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript appname cfgPathFn;
  };

  https = appname: { config, ...}: {
    shb.arr.${appname} = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  httpsTest = appname: cfgPathFn: pkgs.testers.runNixOSTest {
    name = "arr-${appname}-https";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        base
        (basic appname)
        (testLib.certs domain)
        (https appname)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript appname cfgPathFn;
  };

  radarrCfgFn = cfg: "${cfg.dataDir}/config.xml";
  sonarrCfgFn = cfg: "${cfg.dataDir}/config.xml";
  bazarrCfgFn = cfg: "/var/lib/bazarr/config.xml";
  readarrCfgFn = cfg: "${cfg.dataDir}/config.xml";
  lidarrCfgFn = cfg: "${cfg.dataDir}/config.xml";
  jackettCfgFn = cfg: "${cfg.dataDir}/ServerConfig.json";
in
{
  radarr_basic = basicTest "radarr" radarrCfgFn;
  radarr_https = httpsTest "radarr" radarrCfgFn;

  sonarr_basic = basicTest "sonarr" sonarrCfgFn;
  sonarr_https = httpsTest "sonarr" sonarrCfgFn;

  bazarr_basic = basicTest "bazarr" bazarrCfgFn;
  bazarr_https = httpsTest "bazarr" bazarrCfgFn;

  readarr_basic = basicTest "readarr" readarrCfgFn;
  readarr_https = httpsTest "readarr" readarrCfgFn;

  lidarr_basic = basicTest "lidarr" lidarrCfgFn;
  lidarr_https = httpsTest "lidarr" lidarrCfgFn;

  jackett_basic = basicTest "jackett" jackettCfgFn;
  jackett_https = httpsTest "jackett" jackettCfgFn;
}
