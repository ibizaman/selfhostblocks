{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  commonTestScript = { nodes, extraPorts ? [], ... }:
    let
      hasSSL = !(isNull nodes.server.shb.home-assistant.ssl);
      fqdn = if hasSSL then "https://ha.example.com" else "http://ha.example.com";
    in
    ''
    import json
    import os
    import pathlib

    start_all()
    server.wait_for_unit("home-assistant.service")
    server.wait_for_open_port(${toString nodes.server.services.home-assistant.config.http.server_port})
    ''
    + lib.concatMapStringsSep "\n" (port: ''
    server.wait_for_open_port(${toString port})
    '') extraPorts
    + ''

    if ${if hasSSL then "True" else "False"}:
        server.copy_from_vm("/etc/ssl/certs/ca-certificates.crt")
        client.succeed("rm -r /etc/ssl/certs")
        client.copy_from_host(str(pathlib.Path(os.environ.get("out", os.getcwd())) / "ca-certificates.crt"), "/etc/ssl/certs/ca-certificates.crt")

    def curl(target, format, endpoint, succeed=True):
        return json.loads(target.succeed(
            "curl --fail-with-body --silent --show-error --output /dev/null --location"
            + " --connect-to ha.example.com:443:server:443"
            + " --connect-to ha.example.com:80:server:80"
            + f" --write-out '{format}'"
            + " " + endpoint
        ))

    print(server.succeed("cat /var/lib/hass/configuration.yaml"))
    print(server.succeed("systemctl cat home-assistant"))
    print(server.succeed("cat ''$(systemctl cat home-assistant | grep ExecStartPre | cut -d= -f2)"))
    print(server.succeed("cat /var/lib/hass/secrets.yaml.template"))
    print(server.succeed("cat /var/lib/hass/secrets.yaml"))

    with subtest("access"):
        response = curl(client, """{"code":%{response_code}}""", "${fqdn}")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")
    '';

  modules = {
    base = {
      imports = [
        (pkgs'.path + "/nixos/modules/profiles/headless.nix")
        (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
        ../../modules/blocks/nginx.nix
        ../../modules/services/home-assistant.nix
      ];

      # Nginx port.
      networking.firewall.allowedTCPPorts = [ 80 ];
      # VM needs a bit more memory than default.
      # virtualisation.memorySize = 4096;
    };

    basic = {
      imports = [
        {
          options = {
            shb.backup = lib.mkOption { type = lib.types.anything; };
            shb.authelia = lib.mkOption { type = lib.types.anything; };
          };
        }
      ];

      shb.home-assistant = {
        enable = true;
        domain = "example.com";
        subdomain = "ha";

        config = {
          name = "SHB Test";
          country = "BE"; # https://en.wikipedia.org/wiki/ISO_3166-1
          latitude = "0";
          longitude = "0";
          time_zone.source = pkgs.writeText "timeZoneSecret" "UTC"; # https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
          unit_system = "metric";
        };
      };
    };

    ldap = { config, ... }: {
      imports = [
        ../../modules/blocks/ldap.nix
      ];

      shb.ldap = {
        enable = true;
        domain = "example.com";
        subdomain = "ldap";
        ldapPort = 3890;
        webUIListenPort = 17170;
        dcdomain = "dc=example,dc=com";
        ldapUserPasswordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
        jwtSecretFile = pkgs.writeText "jwtSecret" "jwtSecret";
      };

      shb.home-assistant = {
        ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.ldap.ldapPort;
          userGroup = "homeassistant_user";
        };
      };
    };

    voice = {
      shb.home-assistant.voice.text-to-speech = {
        "fr" = {
          enable = true;
          voice = "fr-siwis-medium";
          uri = "tcp://0.0.0.0:10200";
          speaker = 0;
        };
        "en" = {
          enable = true;
          voice = "en_GB-alba-medium";
          uri = "tcp://0.0.0.0:10201";
          speaker = 0;
        };
      };
      shb.home-assistant.voice.speech-to-text = {
        "tiny-fr" = {
          enable = true;
          model = "base-int8";
          language = "fr";
          uri = "tcp://0.0.0.0:10300";
          device = "cpu";
        };
        "tiny-en" = {
          enable = true;
          model = "base-int8";
          language = "en";
          uri = "tcp://0.0.0.0:10301";
          device = "cpu";
        };
      };
      shb.home-assistant.voice.wakeword = {
        enable = true;
        uri = "tcp://127.0.0.1:10400";
        preloadModels = [
          "alexa"
          "hey_jarvis"
          "hey_mycroft"
          "hey_rhasspy"
          "ok_nabu"
        ];
      };
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "home-assistant-basic";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        modules.base
        modules.basic
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  ldap = pkgs.testers.runNixOSTest {
    name = "home-assistant-ldap";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        modules.base
        modules.basic
        modules.ldap
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  voice = pkgs.testers.runNixOSTest {
    name = "home-assistant-basic";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        modules.base
        modules.basic
        modules.voice
      ];
    };

    nodes.client = {};

    testScript = { nodes, ... }: commonTestScript {
      inherit nodes;
      extraPorts = [
        10200
        10201
        # 10300
        # 10301
        10400
      ];
    };
  };
}
