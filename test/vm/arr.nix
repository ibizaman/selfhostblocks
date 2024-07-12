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
      fqdn = "${appname}.${domain}";
    in testLib.accessScript {
      inherit fqdn;
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

  basic = appname: cfgPathFn: pkgs.testers.runNixOSTest {
    name = "arr-${appname}-basic";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        {
          options = {
            shb.backup = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/blocks/authelia.nix
        ../../modules/blocks/postgresql.nix
        ../../modules/blocks/nginx.nix
        ../../modules/services/arr.nix
        (pkgs'.path + "/nixos/modules/profiles/headless.nix")
        (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
      ];

      shb.arr.${appname} = {
        enable = true;
        inherit domain;
        subdomain = appname;

        settings.ApiKey.source = pkgs.writeText "APIKey" "01234567890123456789"; # Needs to be >=20 characters.
      };
      # Nginx port.
      networking.firewall.allowedTCPPorts = [ 80 ];
    };

    nodes.client = {};

    testScript = commonTestScript appname cfgPathFn;
  };
in
{
  radarr_basic = basic "radarr" (cfg: "${cfg.dataDir}/config.xml");
  sonarr_basic = basic "sonarr" (cfg: "${cfg.dataDir}/config.xml");
  bazarr_basic = basic "bazarr" (cfg: "/var/lib/bazarr/config.xml");
  readarr_basic = basic "readarr" (cfg: "${cfg.dataDir}/config.xml");
  lidarr_basic = basic "lidarr" (cfg: "${cfg.dataDir}/config.xml");
  jackett_basic = basic "jackett" (cfg: "${cfg.dataDir}/ServerConfig.json");
}
