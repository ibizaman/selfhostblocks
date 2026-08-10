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

              "expect(page.get_by_text('All set!')).to_be_visible(timeout=20000)"
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
              # Create and login as owner user.
              # This shouldn't be needed. See https://github.com/ibizaman/selfhostblocks/issues/718
              username = null;
              nextPageExpect = [
                "page.get_by_role('button', name=re.compile('Create my smart home')).click()"

                "expect(page.get_by_text('Create user')).to_be_visible()"
                ''page.get_by_role("textbox", name="Name*", exact=True).fill('Admin')''
                ''page.get_by_role("textbox", name="Username*").fill('admin')''
                ''page.get_by_role("textbox", name="Password*", exact=True).fill('AdminPassword')''
                ''page.get_by_role("textbox", name="Confirm password*").fill('AdminPassword')''
                "page.get_by_role('button', name=re.compile('Create account')).click()"

                "expect(page.get_by_text('All set!')).to_be_visible(timeout=20000)"
                "page.get_by_role('button', name=re.compile('Finish')).click()"
              ];
            }
            {
              beforeHook = "page.get_by_text(re.compile('Command Line')).click()";
              username = "alice";
              password = "AlicePassword";
              nextPageExpect = [
                "expect(page.get_by_text('Welcome Alice Alice')).to_be_visible(timeout=30000)"
              ];
            }
            {
              beforeHook = "page.get_by_text(re.compile('Command Line')).click()";
              username = "alice";
              password = "notAlicePassword";
              nextPageExpect = [
                "expect(page.get_by_text('Invalid')).to_be_visible()"
              ];
            }
            {
              beforeHook = "page.get_by_text(re.compile('Command Line')).click()";
              username = "bob";
              password = "BobPassword";
              nextPageExpect = [
                "expect(page.get_by_text('Welcome Bob Bob')).to_be_visible(timeout=30000)"
              ];
            }
            {
              beforeHook = "page.get_by_text(re.compile('Command Line')).click()";
              username = "bob";
              password = "notBobPassword";
              nextPageExpect = [
                "expect(page.get_by_text('Invalid')).to_be_visible()"
              ];
            }
            {
              beforeHook = "page.get_by_text(re.compile('Command Line')).click()";
              username = "charlie";
              password = "CharliePassword";
              nextPageExpect = [
                "expect(page.get_by_text('Invalid')).to_be_visible()"
              ];
            }
          ];
        };
      };
    };

  clientUsersLogin =
    { config, ... }:
    {
      options.test.init = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

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
          testLoginWith =
            # The first user to login is the owner. LDAP users are users or admins, not owners.
            if config.test.init then
              [
                {
                  username = null;
                  nextPageExpect = [
                    # Create and login as owner user
                    "page.get_by_role('button', name=re.compile('Create my smart home')).click()"

                    "expect(page.get_by_text('Create user')).to_be_visible()"
                    ''page.get_by_role("textbox", name="Name*", exact=True).fill('Admin')''
                    ''page.get_by_role("textbox", name="Username*").fill('admin')''
                    ''page.get_by_role("textbox", name="Password*", exact=True).fill('AdminPassword')''
                    ''page.get_by_role("textbox", name="Confirm password*").fill('AdminPassword')''
                    "page.get_by_role('button', name=re.compile('Create account')).click()"

                    "expect(page.get_by_text('All set!')).to_be_visible(timeout=20000)"
                    "page.get_by_role('button', name=re.compile('Finish')).click()"

                    "expect(page).to_have_title(re.compile('Overview'), timeout=15000)"
                    # Confirm Home Assistant's one-time migration of YAML HTTP settings.
                    "page.get_by_role('button', name='Confirm', exact=True).click()"

                    # Create user alice
                    "page.goto('http://${config.test.fqdn}/config/users')"
                    "page.get_by_role('button', name=re.compile('Add user')).click()"
                    ''page.get_by_role("textbox", name="Username*").fill('alice')''
                    ''page.get_by_role("textbox", name="Display Name*").fill('Alice Alice')''
                    ''page.get_by_role("textbox", name="Password*", exact=True).fill('AlicePassword')''
                    ''page.get_by_role("textbox", name="Confirm password*").fill('AlicePassword')''
                    "page.get_by_role('button', name=re.compile('Create')).click()"
                    "page.wait_for_timeout(5000)"

                    # Logout from owner user
                    "page.goto('http://${config.test.fqdn}/profile/general')"
                    "page.get_by_role('button', name=re.compile('Log out')).click()"
                    "page.get_by_label('Log out?').get_by_role('button', name='Log out').click()"

                    # Login as user alice
                    "page.goto('http://${config.test.fqdn}')"
                    ''page.get_by_role("textbox", name="Username").fill('alice')''
                    ''page.get_by_role("textbox", name="Password", exact=True).fill('AlicePassword')''
                    ''page.get_by_role("button", name="Log in").click()''
                    "expect(page).to_have_title(re.compile('Overview'), timeout=15000)"
                  ];
                }
              ]
            else
              [
                {
                  username = "alice";
                  password = "AlicePassword";
                  nextPageExpect = [
                    "expect(page).to_have_title(re.compile('Overview'), timeout=15000)"

                    "page.goto('http://${config.test.fqdn}/profile/general')"
                    ''expect(page.get_by_role("heading", name="Alice Alice")).to_be_visible(timeout=20000)''
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
          debug = true;
          keepDefaultAuth = true; # Needed for admin login
          host = "127.0.0.1";
          port = config.shb.lldap.webUIListenPort;
          userGroup = "user_group";
          adminGroup = "admin_group";
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
      postLoginScript = { ... }: ''
        auth_db = json.loads(server.succeed("cat /var/lib/hass/.storage/auth"))
        users = auth_db["data"]["users"]

        user_ids = [u['id'] for u in users if u['name'] == 'Alice Alice']
        if len(user_ids) != 1:
            raise Exception(f"Could not find alice in users:\n{json.dumps(auth_db, indent=4)}")
        user_id = user_ids[0]

        creds = auth_db["data"]["credentials"]
        creds_for_user = [c for c in creds if c['user_id'] == user_id]
        if len(creds_for_user) != 1:
            raise Exception(f"Expected 1 cred for alice, got {len(creds_for_user)}:\n{json.dumps(auth_db, indent=4)}")
        if creds_for_user[0]["auth_provider_type"] != "command_line":
            raise Exception(f"Unexpected auth provider, want 'command_line', got {creds_for_user[0]["auth_provider_type"]}:\n{json.dumps(auth_db, indent=4)}")

        refresh_tokens = auth_db["data"]["refresh_tokens"]
        rt_for_user = [r for r in refresh_tokens if r['user_id'] == user_id]
        if len(rt_for_user) != 1:
            raise Exception(f"Expected 1 refresh token for alice, got {len(rt_for_user)}:\n{json.dumps(auth_db, indent=4)}")
      '';
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

  users = shb.test.runNixOSTest {
    name = "homeassistant_user";

    nodes.server = {
      imports = [
        basic
      ];

      specialisation.ldap.configuration = {
        imports = [
          shb.test.ldap
          ldap
        ];
      };
    };

    nodes.client = {
      imports = [
        clientUsersLogin
      ];
      test.init = true;
      specialisation.ldap.configuration = {
        test.init = lib.mkForce false;
      };
    };

    testScript =
      args@{ nodes, ... }:
      let
        specializationsServer = "${nodes.server.system.build.toplevel}/specialisation";
        specializationsClient = "${nodes.client.system.build.toplevel}/specialisation";
      in
      ''
        def switch_to_specialization(name):
            client.succeed('${specializationsClient}/ldap/bin/switch-to-configuration test')
            server.succeed('${specializationsServer}/ldap/bin/switch-to-configuration test')
            server.wait_for_unit("multi-user.target")
            client.wait_for_unit("multi-user.target")

        start_all()
        server.wait_for_unit("multi-user.target")
      ''
      + commonTestScript.access (args)
      + ''
        switch_to_specialization("ldap")
      ''
      + (commonTestScript.access.override { init = false; }) (
        lib.recursiveUpdate args {
          nodes.server = nodes.server.specialisation.ldap.configuration;
          nodes.client = nodes.client.specialisation.ldap.configuration;
        }
      )
      + ''
        auth_db = json.loads(server.succeed("cat /var/lib/hass/.storage/auth"))
        users = auth_db["data"]["users"]

        user_ids = [u['id'] for u in users if u['name'] == 'Alice Alice']
        if len(user_ids) != 1:
            raise Exception(f"Could not find alice in users:\n{json.dumps(auth_db, indent=4)}")
        user_id = user_ids[0]

        creds = auth_db["data"]["credentials"]
        creds_for_user = [c for c in creds if c['user_id'] == user_id]
        if len(creds_for_user) != 1:
            raise Exception(f"Expected 1 cred for alice, got {len(creds_for_user)}:\n{json.dumps(auth_db, indent=4)}")

        # Home Assistant will only create 1 cred, showing it correctly matched the
        # ldap login to the previously created one.
        # But we will still see two refresh tokens, proving we did login twice.
        if creds_for_user[0]["auth_provider_type"] != "homeassistant":
            raise Exception(f"Unexpected auth provider, want 'homeassistant', got {creds_for_user[0]["auth_provider_type"]}:\n{json.dumps(auth_db, indent=4)}")

        refresh_tokens = auth_db["data"]["refresh_tokens"]
        rt_for_user = [r for r in refresh_tokens if r['user_id'] == user_id]
        if len(rt_for_user) != 2:
            raise Exception(f"Expected 2 refresh tokens for alice, got {len(rt_for_user)}:\n{json.dumps(auth_db, indent=4)}")
      '';
  };
}
