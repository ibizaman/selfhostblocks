{
  pkgs,
  shb,
  lib,
  ...
}:
let
  commonTestScript = shb.test.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.home-assistant.ssl);
    waitForServices =
      { ... }:
      [
        "home-assistant.service"
        "nginx.service"
      ];
    waitForPorts =
      { node, ... }:
      [
        8123
      ];
  };

  basic =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
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
      services.home-assistant.extraComponents = [
        # this is effecitvely default_config (2026.5.0), but with components
        # skipped that would cause ERRORs in the sandbox
        "bluetooth"
        "cloud"
        "conversation"
        "dhcp"
        "energy"
        "file"
        # Requires go2rtc service
        # "go2rtc"
        "history"
        # Requires DNS and HTTP queries
        # "homeassistant_alerts"
        "logbook"
        "media_source"
        "mobile_app"
        "my"
        "ssdp"
        "stream"
        "sun"
        "usage_prediction"
        "usb"
        "webhook"
        "zeroconf"

        # include some popular integrations, that absolutely shouldn't break
        "knx"
        "zha"
      ];
    };

  clientLogin =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];
      virtualisation.memorySize = 4096;

      test = {
        subdomain = "ha";
      };

      test.login = {
        startUrl = "http://${config.test.fqdn}";
        usernameFieldSelector = ''get_by_role("textbox", name="Username")'';
        passwordFieldSelector = ''get_by_role("textbox", name="Password")'';
        loginButtonSelector = ''get_by_role("button", name="Log in")'';
        testLoginWith = [
          {
            nextPageExpect = [
              "page.get_by_role('button', name=re.compile('Create my smart home')).click()"

              "expect(page.get_by_text('Create user')).to_be_visible()"
              ''page.get_by_role("textbox", name="Name*", exact=True).fill('Admin')''
              ''page.get_by_role("textbox", name="Username*").fill('admin')''
              ''page.get_by_role("textbox", name="Password*", exact=True).fill('adminpassword')''
              ''page.get_by_role("textbox", name="Confirm password*").fill('adminpassword')''
              "page.get_by_role('button', name=re.compile('Create account')).click()"

              "expect(page.get_by_text('All set!')).to_be_visible()"
              "page.get_by_role('button', name=re.compile('Finish')).click()"

              "expect(page).to_have_title(re.compile('Overview'), timeout=15000)"
            ];
          }
        ];
      };
    };

  clientLdapLogin =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];

      config = {
        virtualisation.memorySize = 4096;

        test = {
          subdomain = "ha";
        };

        test.login = {
          startUrl = "http://${config.test.fqdn}";
          usernameFieldSelector = ''get_by_role("textbox", name="Username")'';
          passwordFieldSelector = ''get_by_role("textbox", name="Password")'';
          loginButtonSelector = ''get_by_role("button", name="Log in")'';
          testLoginWith = [
            {
              username = "alice";
              password = "AlicePassword";
              nextPageExpect = [
                "expect(page.get_by_text('All set!')).to_be_visible(timeout=30000)"
                "page.get_by_role('button', name=re.compile('Finish')).click()"
                "expect(page).to_have_title(re.compile('Overview'), timeout=15000)"
              ];
            }
            {
              username = "alice";
              password = "notAlicePassword";
              nextPageExpect = [
                "expect(page.get_by_text('Invalid!')).to_be_visible()"
              ];
            }
            {
              username = "bob";
              password = "BobPassword";
              nextPageExpect = [
                "expect(page.get_by_text('All set!')).to_be_visible(timeout=30000)"
                "page.get_by_role('button', name=re.compile('Finish')).click()"
                "expect(page).to_have_title(re.compile('Overview'), timeout=15000)"
              ];
            }
            {
              username = "bob";
              password = "notBobPassword";
              nextPageExpect = [
                "expect(page.get_by_text('Invalid!')).to_be_visible()"
              ];
            }
            {
              username = "charlie";
              password = "CharliePassword";
              nextPageExpect = [
                "expect(page.get_by_text('Invalid!')).to_be_visible()"
              ];
            }
          ];
        };
      };
    };

  https =
    { config, ... }:
    {
      shb.home-assistant = {
        ssl = config.shb.certs.certs.selfsigned.n;
      };
    };

  ldap =
    { config, ... }:
    {
      shb.lldap.debug = lib.mkForce true;
      shb.home-assistant = {
        ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.lldap.webUIListenPort;
          userGroup = "user_group";
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

  voice =
    { config, ... }:
    {
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
  basic = shb.test.runNixOSTest {
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

  backup = shb.test.runNixOSTest {
    name = "homeassistant_backup";

    nodes.server =
      { config, ... }:
      {
        imports = [
          basic
          (shb.test.backup config.shb.home-assistant.backup)
        ];
      };

    nodes.client = { };

    testScript = commonTestScript.backup;
  };

  https = shb.test.runNixOSTest {
    name = "homeassistant_https";

    nodes.server = {
      imports = [
        basic
        shb.test.certs
        https
      ];
    };

    nodes.client = { };

    testScript = commonTestScript.access;
  };

  ldap = shb.test.runNixOSTest {
    name = "homeassistant_ldap";

    nodes.client = {
      imports = [
        clientLdapLogin
      ];
    };
    nodes.server = {
      imports = [
        basic
        shb.test.ldap
        ldap
      ];
    };

    testScript = commonTestScript.access.override {
      waitForPorts =
        { node, ... }:
        [
          8123
          node.config.shb.lldap.webUIListenPort
        ];
    };
  };

  # Not yet supported
  #
  # sso = shb.test.runNixOSTest {
  #   name = "vaultwarden_sso";
  #
  #   nodes.server = lib.mkMerge [
  #     basic
  #     (shb.certs domain)
  #     https
  #     ldap
  #     (shb.ldap domain pkgs')
  #     (shb.test.sso domain pkgs' config.shb.certs.certs.selfsigned.n)
  #     sso
  #   ];
  #
  #   nodes.client = {};
  #
  #   testScript = commonTestScript.access;
  # };

  voice = shb.test.runNixOSTest {
    name = "homeassistant_voice";

    nodes.server = {
      imports = [
        basic
        voice
      ];
    };

    nodes.client = { };

    testScript = commonTestScript.access;
  };
}
