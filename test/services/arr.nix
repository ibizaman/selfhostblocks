{ pkgs, lib, ... }:
let
  healthUrl = "/health";
  loginUrl = "/UI/Login";

  testLib = pkgs.callPackage ../common.nix {};

  # TODO: Test login
  commonTestScript = appname: cfgPathFn: testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.arr.${appname}.ssl);
    waitForServices = { ... }: [
      "${appname}.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      node.config.shb.arr.${appname}.settings.Port
    ];
    extraScript = { node, fqdn, proto_fqdn, ... }: let
      shbapp = node.config.shb.arr.${appname};
      cfgPath = cfgPathFn shbapp;
      apiKey = if (shbapp.settings ? ApiKey) then "01234567890123456789" else null;
    in ''
      # These curl requests still return a 200 even with sso redirect.
      with subtest("health"):
          response = curl(client, """{"code":%{response_code}}""", "${fqdn}${healthUrl}")
          print("response =", response)

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

  basic = appname: { config, ... }: {
    imports = [
      testLib.baseModule
      ../../modules/services/arr.nix
    ];

    test = {
      subdomain = appname;
    };

    shb.arr.${appname} = {
      enable = true;
      inherit (config.test) subdomain domain;

      settings.ApiKey.source = pkgs.writeText "APIKey" "01234567890123456789"; # Needs to be >=20 characters.
    };
  };

  clientLogin = appname: { config, ... }: {
    imports = [
      testLib.baseModule
      testLib.clientLoginModule
    ];

    test = {
      subdomain = appname;
    };

    test.login = {
      startUrl = "http://${config.test.fqdn}";
      usernameFieldLabelRegex = "[Uu]sername";
      passwordFieldLabelRegex = "^ *[Pp]assword";
      loginButtonNameRegex = "[Ll]og [Ii]n";
      testLoginWith = [
        { nextPageExpect = [
            "expect(page).to_have_title(re.compile('${appname}', re.IGNORECASE))"
          ]; }
      ];
    };
  };

  basicTest = appname: cfgPathFn: pkgs.testers.runNixOSTest {
    name = "arr_${appname}_basic";

    nodes.client = {
      imports = [
        (clientLogin appname)
      ];
    };
    nodes.server = {
      imports = [
        (basic appname)
      ];
    };

    testScript = (commonTestScript appname cfgPathFn).access;
  };

  backupTest = appname: cfgPathFn: pkgs.testers.runNixOSTest {
    name = "arr_${appname}_backup";

    nodes.server = { config, ... }: {
      imports = [
        (basic appname)
        (testLib.backup config.shb.arr.${appname}.backup)
      ];
    };

    nodes.client = {};

    testScript = (commonTestScript appname cfgPathFn).backup;
  };

  https = appname: { config, ...}: {
    shb.arr.${appname} = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  httpsTest = appname: cfgPathFn: pkgs.testers.runNixOSTest {
    name = "arr_${appname}_https";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        (basic appname)
        testLib.certs
        (https appname)
      ];
    };

    nodes.client = {};

    testScript = (commonTestScript appname cfgPathFn).access;
  };

  sso = appname: { config, ...}: {
    shb.arr.${appname} = {
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
  };

  ssoTest = appname: cfgPathFn: pkgs.testers.runNixOSTest {
    name = "arr_${appname}_sso";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        (basic appname)
        testLib.certs
        (https appname)
        testLib.ldap
        (testLib.sso config.shb.certs.certs.selfsigned.n)
        (sso appname)
      ];
    };

    nodes.client = {};

    testScript = (commonTestScript appname cfgPathFn).access.override {
      redirectSSO = true;
    };
  };

  radarrCfgFn = cfg: "${cfg.dataDir}/config.xml";
  sonarrCfgFn = cfg: "${cfg.dataDir}/config.xml";
  bazarrCfgFn = cfg: "/var/lib/bazarr/config.xml";
  readarrCfgFn = cfg: "${cfg.dataDir}/config.xml";
  lidarrCfgFn = cfg: "${cfg.dataDir}/config.xml";
  jackettCfgFn = cfg: "${cfg.dataDir}/ServerConfig.json";
in
{
  radarr_basic  = basicTest "radarr" radarrCfgFn;
  radarr_backup = backupTest "radarr" radarrCfgFn;
  radarr_https  = httpsTest "radarr" radarrCfgFn;
  radarr_sso    = ssoTest   "radarr" radarrCfgFn;

  sonarr_basic  = basicTest "sonarr" sonarrCfgFn;
  sonarr_backup = backupTest "sonarr" sonarrCfgFn;
  sonarr_https  = httpsTest "sonarr" sonarrCfgFn;
  sonarr_sso    = ssoTest   "sonarr" sonarrCfgFn;

  bazarr_basic  = basicTest "bazarr" bazarrCfgFn;
  bazarr_backup = backupTest "bazarr" bazarrCfgFn;
  bazarr_https  = httpsTest "bazarr" bazarrCfgFn;
  bazarr_sso    = ssoTest   "bazarr" bazarrCfgFn;

  readarr_basic  = basicTest "readarr" readarrCfgFn;
  readarr_backup = backupTest "readarr" readarrCfgFn;
  readarr_https  = httpsTest "readarr" readarrCfgFn;
  readarr_sso    = ssoTest   "readarr" readarrCfgFn;

  lidarr_basic  = basicTest "lidarr" lidarrCfgFn;
  lidarr_backup = backupTest "lidarr" lidarrCfgFn;
  lidarr_https  = httpsTest "lidarr" lidarrCfgFn;
  lidarr_sso    = ssoTest   "lidarr" lidarrCfgFn;

  jackett_basic  = basicTest "jackett" jackettCfgFn;
  jackett_backup = backupTest "jackett" jackettCfgFn;
  jackett_https  = httpsTest "jackett" jackettCfgFn;
  jackett_sso    = ssoTest   "jackett" jackettCfgFn;
}
