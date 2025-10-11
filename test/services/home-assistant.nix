{ pkgs, lib, ... }:
let
  commonTestScript = lib.shb.mkScripts {
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
      lib.shb.baseModule
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
      lib.shb.baseModule
      lib.shb.clientLoginModule
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

            "expect(page.get_by_text('All set!')).to_be_visible()"
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
        port = config.shb.lldap.webUIListenPort;
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

  voice = { config, ... }: {
    # For now, verifying the packages can build is good enough.
    environment.systemPackages = [
      config.services.wyoming.piper.package
      config.services.wyoming.openwakeword.package
      config.services.wyoming.faster-whisper.package
    ];

    # TODO: enable this back. The issue id the services cannot talk to the internet
    # to download the models so they fail to start..
    # shb.home-assistant.voice.text-to-speech = {
    #   "fr" = {
    #     enable = true;
    #     voice = "fr-siwis-medium";
    #     uri = "tcp://0.0.0.0:10200";
    #     speaker = 0;
    #   };
    #   "en" = {
    #     enable = true;
    #     voice = "en_GB-alba-medium";
    #     uri = "tcp://0.0.0.0:10201";
    #     speaker = 0;
    #   };
    # };
    # shb.home-assistant.voice.speech-to-text = {
    #   "tiny-fr" = {
    #     enable = true;
    #     model = "base-int8";
    #     language = "fr";
    #     uri = "tcp://0.0.0.0:10300";
    #     device = "cpu";
    #   };
    #   "tiny-en" = {
    #     enable = true;
    #     model = "base-int8";
    #     language = "en";
    #     uri = "tcp://0.0.0.0:10301";
    #     device = "cpu";
    #   };
    # };
    # shb.home-assistant.voice.wakeword = {
    #   enable = true;
    #   uri = "tcp://127.0.0.1:10400";
    #   preloadModels = [
    #     "alexa"
    #     "hey_jarvis"
    #     "hey_mycroft"
    #     "hey_rhasspy"
    #     "ok_nabu"
    #   ];
    # };
  };
in
{
  basic = lib.shb.runNixOSTest {
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

    testScript = commonTestScript.access;
  };

  backup = lib.shb.runNixOSTest {
    name = "homeassistant_backup";

    nodes.server = { config, ... }: {
      imports = [
        basic
        (lib.shb.backup config.shb.home-assistant.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };

  https = lib.shb.runNixOSTest {
    name = "homeassistant_https";

    nodes.server = {
      imports = [
        basic
        lib.shb.certs
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  ldap = lib.shb.runNixOSTest {
    name = "homeassistant_ldap";
  
    nodes.server = {
      imports = [ 
        basic
        lib.shb.ldap
        ldap
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript.access;
  };

  # Not yet supported
  #
  # sso = lib.shb.runNixOSTest {
  #   name = "vaultwarden_sso";
  #
  #   nodes.server = lib.mkMerge [ 
  #     basic
  #     (lib.shb.certs domain)
  #     https
  #     ldap
  #     (lib.shb.ldap domain pkgs')
  #     (lib.shb.sso domain pkgs' config.shb.certs.certs.selfsigned.n)
  #     sso
  #   ];
  #
  #   nodes.client = {};
  #
  #   testScript = commonTestScript.access;
  # };

  voice = lib.shb.runNixOSTest {
    name = "homeassistant_voice";
  
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
