{ pkgs, ... }:
let
  testLib = pkgs.callPackage ../common.nix {};

  commonTestScript = testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.home-assistant.ssl);
    waitForServices = { ... }: [
      "home-assistant.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      8123
    ];
  };

  basic = { config, ... }: {
    imports = [
      testLib.baseModule
      ../../modules/services/home-assistant.nix
    ];

    test = {
      subdomain = "ha";
    };

    shb.home-assistant = {
      enable = true;
      inherit (config.test) subdomain domain;

      config = {
        name = "Tiserbox";
        country = "CH";
        latitude = "01.0000000000";
        longitude.source = pkgs.writeText "longitude" "01.0000000000";
        time_zone = "Europe/Zurich";
        unit_system = "metric";
      };
    };
  };

  clientLogin = { config, ... }: {
    imports = [
      testLib.baseModule
      testLib.clientLoginModule
    ];
    virtualisation.memorySize = 4096;

    test = {
      subdomain = "ha";
    };

    test.login = {
      startUrl = "http://${config.test.fqdn}";
      testLoginWith = [
        { nextPageExpect = [
            "page.get_by_role('button', name=re.compile('Create my smart home')).click()"

            "expect(page.get_by_text('Create user')).to_be_visible()"
            "page.get_by_label(re.compile('Name')).fill('Admin')"
            "page.get_by_label(re.compile('Username')).fill('admin')"
            "page.get_by_label(re.compile('Password')).fill('adminpassword')"
            "page.get_by_label(re.compile('Confirm password')).fill('adminpassword')"
            "page.get_by_role('button', name=re.compile('Create account')).click()"

            "expect(page.get_by_text('We found compatible devices')).to_be_visible()"
            "page.get_by_role('button', name=re.compile('Finish')).click()"

            "expect(page).to_have_title(re.compile('Overview'), timeout=15000)"
          ]; }
      ];
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

    nodes.client = {
      imports = [
        clientLogin
      ];
    };
    nodes.server = {
      imports = [
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
        basic
        testLib.certs
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
        basic
        testLib.ldap
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
  #     basic
  #     (testLib.certs domain)
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
        basic
        voice
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript.access;
  };
}
