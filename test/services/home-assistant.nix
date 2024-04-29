{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "ha";
  domain = "example.com";

  commonTestScript = testLib.mkScripts {
    inherit subdomain domain;
    hasSSL = { node, ... }: !(isNull node.config.shb.home-assistant.ssl);
    waitForServices = { ... }: [
      "home-assistant.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      8123
    ];
  };

  base = testLib.base pkgs' [
    ../../modules/services/home-assistant.nix
  ];

  basic = { config, ... }: {
    shb.home-assistant = {
      enable = true;
      inherit subdomain domain;

      config = {
        name = "Tiserbox";
        country = "My Country";
        latitude = "01.0000000000";
        longitude.source = pkgs.writeText "longitude" "01.0000000000";
        time_zone = "America/Los_Angeles";
        unit_system = "metric";
      };
    };
  };

  https = { config, ...}: {
    shb.home-assistant = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  ldap = { config, ... }: {
    shb.home-assistant = {
      ldap = {
        enable = true;
        host = "127.0.0.1";
        port = config.shb.ldap.webUIListenPort;
        userGroup = "homeassistant_user";
      };
    };
  };

  # Not yet supported
  #
  # sso = { config, ... }: {
  #   shb.home-assistant = {
  #     sso = {
  #     };
  #   };
  # };

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
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "homeassistant_basic";

    nodes.server = {
      imports = [
        base
        basic
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  backup = pkgs.testers.runNixOSTest {
    name = "homeassistant_backup";

    nodes.server = { config, ... }: {
      imports = [
        base
        basic
        (testLib.backup config.shb.home-assistant.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };

  https = pkgs.testers.runNixOSTest {
    name = "homeassistant_https";

    nodes.server = {
      imports = [
        base
        (testLib.certs domain)
        basic
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  ldap = pkgs.testers.runNixOSTest {
    name = "homeassistant_ldap";
  
    nodes.server = {
      imports = [ 
        base
        basic
        (testLib.ldap domain pkgs')
        ldap
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript.access;
  };

  # Not yet supported
  #
  # sso = pkgs.testers.runNixOSTest {
  #   name = "vaultwarden_sso";
  #
  #   nodes.server = lib.mkMerge [ 
  #     base
  #     (testLib.certs domain)
  #     basic
  #     https
  #     ldap
  #     (testLib.ldap domain pkgs')
  #     (testLib.sso domain pkgs' config.shb.certs.certs.selfsigned.n)
  #     sso
  #   ];
  #
  #   nodes.client = {};
  #
  #   testScript = commonTestScript.access;
  # };

  voice = pkgs.testers.runNixOSTest {
    name = "homeassistant_ldap";
  
    nodes.server = {
      imports = [ 
        base
        basic
        voice
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript.access;
  };
}
