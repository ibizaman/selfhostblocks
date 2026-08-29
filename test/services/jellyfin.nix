{
  pkgs,
  lib,
  shb,
  ...
}:
let
  port = 9096;

  adminUser = "jellyfin";
  adminPassword = "admin";

  commonExtraScript =
    { node, ... }:
    ''
      headers = unline_with(" ", """
          -H 'Content-Type: application/json'
          -H 'Authorization: MediaBrowser Client="Android TV", Device="Nvidia Shield", DeviceId="ZQ9YQHHrUzk24vV", Version="0.15.3"'
      """)

      with subtest("api login success"):
          def admin_login_succeeds(_):
              response = curl(client, """{"code":%{response_code}}""", "${node.config.test.proto_fqdn}/Users/AuthenticateByName",
                  data="""{"Username": "${adminUser}", "Pw": "${adminPassword}"}""",
                  extra=headers)
              return isinstance(response, dict) and response.get('code') == 200

          retry(admin_login_succeeds, timeout_seconds=300)

      with subtest("api login failure"):
          response = curl(client, """{"code":%{response_code}}""", "${node.config.test.proto_fqdn}/Users/AuthenticateByName",
              data="""{"Username": "${adminUser}", "Pw": "badpassword"}""",
              extra=headers)
          if response['code'] != 401:
              raise Exception(f"Expected failure, got: {response['code']}")
    '';

  commonTestScript = shb.test.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.jellyfin.ssl);
    waitForServices =
      { ... }:
      [
        "multi-user.target"
        "nginx.service"
      ];
    waitForPorts =
      { node, ... }:
      [
        port
      ];
    waitForUrls =
      { proto_fqdn, ... }:
      [
        "${proto_fqdn}/System/Info/Public"
        {
          url = "${proto_fqdn}/Users/AuthenticateByName";
          status = 401;
        }
      ];
    preLoginScript = commonExtraScript;
  };

  basic =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        ../../modules/services/jellyfin.nix
      ];
      # Jellyfin checks for minimum 2Gib on startup.
      virtualisation.diskSize = 4096;
      virtualisation.memorySize = 4096;
      test = {
        subdomain = "j";
      };

      shb.jellyfin = {
        enable = true;
        inherit (config.test) subdomain domain;
        inherit port;
        admin = {
          username = adminUser;
          password.result = config.shb.hardcodedsecret.jellyfinAdminPassword.result;
        };
        debug = true;
      };

      shb.hardcodedsecret.jellyfinAdminPassword = {
        request = config.shb.jellyfin.admin.password.request;
        settings.content = adminPassword;
      };

      environment.systemPackages = [
        pkgs.sqlite
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
        subdomain = "j";
      };

      test.login = {
        browser = "firefox";
        startUrl = "${config.test.proto}://${config.test.fqdn}";
        usernameFieldLabelRegex = "[Uu]ser";
        loginButtonNameRegex = "Sign In";
        testLoginWith = [
          {
            username = adminUser;
            password = "badpassword";
            nextPageExpect = [
              # "expect(page).to_have_title(re.compile('Jellyfin'))"
              "expect(page.get_by_text(re.compile('[Ii]nvalid'))).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = adminUser;
            password = adminPassword;
            nextPageExpect = [
              # "expect(page).to_have_title(re.compile('Jellyfin'))"
              "expect(page.get_by_text(re.compile('[Ii]nvalid'))).not_to_be_visible(timeout=10000)"
              "expect(page.get_by_label(re.compile('^[Uu]ser'))).not_to_be_visible(timeout=10000)"
              "expect(page.get_by_label(re.compile('^[Pp]assword$'))).not_to_be_visible(timeout=10000)"
            ];
          }
        ];
      };
    };

  https =
    { config, ... }:
    {
      shb.jellyfin = {
        ssl = config.shb.certs.certs.selfsigned.n;
      };
      test = {
        hasSSL = true;
      };
    };

  ldap =
    { config, lib, ... }:
    {
      shb.jellyfin = {
        ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.lldap.ldapPort;
          dcdomain = config.shb.lldap.dcdomain;
          userGroup = "user_group";
          adminGroup = "admin_group";
          adminPassword.result = config.shb.hardcodedsecret.jellyfinLdapUserPassword.result;
        };
      };

      # There's something weird happending here
      # where this plugin disappears after a jellyfin restart.
      # I don't know why this is the case.
      # I tried using a real plugin here instead of a mock or just creating a meta.json file.
      # But this didn't help.
      shb.jellyfin.plugins = lib.mkBefore [
        (shb.mkJellyfinPlugin (rec {
          pname = "jellyfin-plugin-ldapauth";
          version = "19";
          url = "https://github.com/jellyfin/${pname}/releases/download/v${version}/ldap-authentication_${version}.0.0.0.zip";
          hash = "sha256-NunkpdYjsxYT6a4RaDXLkgRn4scRw8GaWvyHGs9IdWo=";
        }))
      ];

      shb.hardcodedsecret.jellyfinLdapUserPassword = {
        request = config.shb.jellyfin.ldap.adminPassword.request;
        settings.content = "ldapUserPassword";
      };
    };

  clientLoginLdap =
    { config, ... }:
    {
      options = {
        test.login.onlyAlice = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };

      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];

      config = {
        virtualisation.memorySize = 4096;

        test = {
          subdomain = "j";
        };

        test.login = {
          startUrl = "${config.test.proto}://${config.test.fqdn}";
          usernameFieldLabelRegex = "[Uu]ser";
          loginButtonNameRegex = "Sign In";
          testLoginWith =
            lib.optionals (!config.test.login.onlyAlice) [
              {
                username = adminUser;
                password = "badpassword";
                nextPageExpect = [
                  # "expect(page).to_have_title(re.compile('Jellyfin'))"
                  "expect(page.get_by_text(re.compile('[Ii]nvalid'))).to_be_visible(timeout=10000)"
                ];
              }
              {
                username = adminUser;
                password = adminPassword;
                nextPageExpect = [
                  # "expect(page).to_have_title(re.compile('Jellyfin'))"
                  "expect(page.get_by_text(re.compile('[Ii]nvalid'))).not_to_be_visible(timeout=10000)"
                  "expect(page.get_by_label(re.compile('^[Uu]ser'))).not_to_be_visible(timeout=10000)"
                  "expect(page.get_by_label(re.compile('^[Pp]assword$'))).not_to_be_visible(timeout=10000)"
                ];
              }
            ]
            ++ [
              {
                username = "alice";
                password = "AlicePassword";
                nextPageExpect = [
                  # "expect(page).to_have_title(re.compile('Jellyfin'))"
                  # For a reason I can't explain, redirection needs to happen manually.
                  "page.goto('${config.test.proto}://${config.test.fqdn}/web/')"
                  "expect(page.get_by_text(re.compile('[Ii]nvalid'))).not_to_be_visible(timeout=10000)"
                  "expect(page.get_by_label(re.compile('^[Uu]ser'))).not_to_be_visible(timeout=10000)"
                  "expect(page.get_by_label(re.compile('^[Pp]assword$'))).not_to_be_visible(timeout=10000)"
                ];
              }
            ]
            ++ lib.optionals (!config.test.login.onlyAlice) [
              {
                username = "alice";
                password = "NotAlicePassword";
                nextPageExpect = [
                  # "expect(page).to_have_title(re.compile('Jellyfin'))"
                  "expect(page.get_by_text(re.compile('[Ii]nvalid'))).to_be_visible(timeout=10000)"
                ];
              }
              {
                username = "bob";
                password = "BobPassword";
                nextPageExpect = [
                  # "expect(page).to_have_title(re.compile('Jellyfin'))"
                  # For a reason I can't explain, redirection needs to happen manually.
                  "page.goto('${config.test.proto}://${config.test.fqdn}/web/')"
                  "expect(page.get_by_text(re.compile('[Ii]nvalid'))).not_to_be_visible(timeout=10000)"
                  "expect(page.get_by_label(re.compile('^[Uu]ser'))).not_to_be_visible(timeout=10000)"
                  "expect(page.get_by_label(re.compile('^[Pp]assword$'))).not_to_be_visible(timeout=10000)"
                ];
              }
              {
                username = "bob";
                password = "NotBobPassword";
                nextPageExpect = [
                  # "expect(page).to_have_title(re.compile('Jellyfin'))"
                  "expect(page.get_by_text(re.compile('[Ii]nvalid'))).to_be_visible(timeout=10000)"
                ];
              }
            ];
        };
      };
    };

  sso =
    { config, ... }:
    {
      shb.jellyfin = {
        ldap = {
          userGroup = "user_group";
          adminGroup = "admin_group";
        };

        sso = {
          enable = true;
          endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          sharedSecret.result = config.shb.hardcodedsecret.jellyfinSSOPassword.result;
          sharedSecretForAuthelia.result = config.shb.hardcodedsecret.jellyfinSSOPasswordAuthelia.result;
        };
      };

      shb.hardcodedsecret.jellyfinSSOPassword = {
        request = config.shb.jellyfin.sso.sharedSecret.request;
        settings.content = "ssoPassword";
      };

      shb.hardcodedsecret.jellyfinSSOPasswordAuthelia = {
        request = config.shb.jellyfin.sso.sharedSecretForAuthelia.request;
        settings.content = "ssoPassword";
      };
    };

  clientLoginSso =
    { config, ... }:
    {
      options = {
        test.login.onlyAlice = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };

      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];

      config = {
        virtualisation.memorySize = 4096;

        test = {
          subdomain = "j";
        };

        test.login = {
          startUrl = "${config.test.proto}://${config.test.fqdn}";
          beforeHook = ''
            page.locator('text=Sign in with Authelia').click()
          '';
          usernameFieldLabelRegex = "Username";
          passwordFieldLabelRegex = "Password";
          loginButtonNameRegex = "[Ss]ign [Ii]n";
          loginSpawnsNewPage = true;
          testLoginWith = [
            {
              username = "alice";
              password = "AlicePassword";
              nextPageExpect = [
                "page.get_by_text(re.compile('[Aa]ccept')).click()"
                # For a reason I can't explain, redirection needs to happen manually.
                "page.goto('${config.test.proto}://${config.test.fqdn}/web/')"
                # "expect(page).to_have_title(re.compile('Jellyfin'))"
                "expect(page.get_by_text(re.compile('[Ii]nvalid'))).not_to_be_visible(timeout=10000)"
                "expect(page.get_by_label(re.compile('^[Uu]ser'))).not_to_be_visible(timeout=10000)"
                "expect(page.get_by_label(re.compile('^[Pp]assword$'))).not_to_be_visible(timeout=10000)"
              ];
            }
          ]
          ++ lib.optionals (!config.test.login.onlyAlice) [
            {
              username = "alice";
              password = "NotAlicePassword";
              nextPageExpect = [
                # For a reason I can't explain, redirection needs to happen manually.
                # So for failing auth, we check we're back on the login page.
                "page.goto('${config.test.proto}://${config.test.fqdn}/web/')"
                # "expect(page).to_have_title(re.compile('Jellyfin'))"
                "expect(page.get_by_label(re.compile('^[Uu]ser'))).to_be_visible(timeout=10000)"
                "expect(page.get_by_label(re.compile('^[Pp]assword$'))).to_be_visible(timeout=10000)"
              ];
            }
            {
              username = "bob";
              password = "BobPassword";
              nextPageExpect = [
                "page.get_by_text(re.compile('[Aa]ccept')).click()"
                # For a reason I can't explain, redirection needs to happen manually.
                "page.goto('${config.test.proto}://${config.test.fqdn}/web/')"
                # "expect(page).to_have_title(re.compile('Jellyfin'))"
                "expect(page.get_by_text(re.compile('[Ii]nvalid'))).not_to_be_visible(timeout=10000)"
                "expect(page.get_by_label(re.compile('^[Uu]ser'))).not_to_be_visible(timeout=10000)"
                "expect(page.get_by_label(re.compile('^[Pp]assword$'))).not_to_be_visible(timeout=10000)"
              ];
            }
            {
              username = "bob";
              password = "NotBobPassword";
              nextPageExpect = [
                # For a reason I can't explain, redirection needs to happen manually.
                "page.goto('${config.test.proto}://${config.test.fqdn}/web/')"
                # "expect(page).to_have_title(re.compile('Jellyfin'))"
                "expect(page.get_by_label(re.compile('^[Uu]ser'))).to_be_visible(timeout=10000)"
                "expect(page.get_by_label(re.compile('^[Pp]assword$'))).to_be_visible(timeout=10000)"
              ];
            }
          ];
        };
      };
    };

  jellyfinTest =
    name:
    { nodes, testScript }:
    shb.test.runNixOSTest {
      name = "jellyfin_${name}";

      interactive.sshBackdoor.enable = true;
      interactive.nodes.server = {
        environment.systemPackages = [
          pkgs.sqlite
        ];
      };

      inherit nodes;
      inherit testScript;
    };
in
{
  basic = jellyfinTest "basic" {
    nodes.server = {
      imports = [
        basic
      ];
    };

    nodes.client = {
      imports = [
        clientLogin
      ];
    };

    testScript = commonTestScript.access;
  };

  backup = jellyfinTest "backup" {
    nodes.server =
      { config, ... }:
      {
        imports = [
          basic
          (shb.test.backup config.shb.jellyfin.backup)
        ];
      };

    nodes.client = { };

    testScript = commonTestScript.backup;
  };

  https = jellyfinTest "https" {
    nodes.server = {
      imports = [
        basic
        shb.test.certs
        https
      ];
    };

    nodes.client =
      { config, lib, ... }:
      {
        imports = [
          clientLogin
        ];
      };

    testScript = commonTestScript.access;
  };

  ldap = jellyfinTest "ldap" {
    nodes.server = {
      imports = [
        basic
        shb.test.certs
        https
        shb.test.ldap
        ldap
      ];
    };

    nodes.client = {
      imports = [
        clientLoginLdap
      ];
    };

    testScript = commonTestScript.access.override {
      preLoginScript =
        args@{
          node,
          ...
        }:
        (commonExtraScript args)
        # I have no idea why the LDAP Authentication_19.0.0.0 plugin disappears.
        + ''
          r = server.execute('cat "${node.config.services.jellyfin.dataDir}/plugins/LDAP Authentication_19.0.0.0/meta.json"')
          if r[0] != 0:
              print("meta.json for plugin LDAP Authentication_19.0.0.0 not found")
          else:
              c = json.loads(r[1])
              if "status" in c and c["status"] != "Disabled":
                  raise Exception(f'meta.json status: expected Disabled, got: {c["status"]}')
        '';
    };
  };

  sso = jellyfinTest "sso" {
    nodes.server =
      { config, pkgs, ... }:
      {
        imports = [
          basic
          shb.test.certs
          https
          shb.test.ldap
          (shb.test.sso config.shb.certs.certs.selfsigned.n)
          sso
        ];
      };

    nodes.client = {
      imports = [
        clientLoginSso
      ];
    };

    testScript = commonTestScript.access;
  };

  users = shb.test.runNixOSTest {
    name = "jellyfin_user";

    nodes.server = {
      imports = [
        basic
        shb.test.certs
        https
      ];

      specialisation.ldap.configuration = {
        imports = [
          shb.test.ldap
          ldap
        ];
      };

      specialisation.sso.configuration =
        { config, ... }:
        {
          imports = [
            shb.test.ldap
            (shb.test.sso config.shb.certs.certs.selfsigned.n)
            sso
          ];

          # https://github.com/ibizaman/selfhostblocks/issues/843
          shb.jellyfin.admin.username = lib.mkForce "jellyfin2";
        };
    };

    nodes.client = {
      imports = [
        {
          # Somehow this needs to be in the top level import otherwise it is not applied.
          environment.variables = {
            PLAYWRIGHT_BROWSERS_PATH = pkgs.playwright-driver.browsers;
          };
        }
      ];
      specialisation.ldap.configuration = {
        imports = [
          clientLoginLdap
        ];

        test.login.onlyAlice = true;
      };
      specialisation.sso.configuration = {
        imports = [
          clientLoginSso
        ];

        test.login.onlyAlice = true;
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
            with subtest(f"switch specialization to {name}"):
                client.succeed(f'${specializationsClient}/{name}/bin/switch-to-configuration test')
                server.succeed(f'${specializationsServer}/{name}/bin/switch-to-configuration test')
                server.wait_for_unit("multi-user.target")
                client.wait_for_unit("multi-user.target")

        start_all()
        server.wait_for_unit("multi-user.target")
      ''
      # Logging in as Alice without LDAP is not possible currently declaratively.
      # Only the Jellyfin admin user can be created declaratively.
      # I'm leaving this commentted out as a TODO item for later.
      # +
      #   (commonTestScript.access.override {
      #     init = true;
      #     preLoginScript = _: "";
      #   })
      #     args
      # + ''
      #   with subtest("find alice"):
      #       users = json.loads(server.succeed("sqlite3 /var/lib/jellyfin/data/jellyfin.db -json 'SELECT * FROM Users;'"))
      #       aliceUsers = [u for u in users if u["Username"] == "alice"]
      #       if len(aliceUsers) != 1:
      #           raise Exception(f"Unexpected number of users for alice, got {len(aliceUsers)}\n{json.dumps(users, indent=4)}")
      #       alice = aliceUsers[0]
      #       if alice["AuthenticationProviderId"] != "Jellyfin.Plugin.LDAP_Auth.LdapAuthenticationProviderPlugin":
      #           raise Exception("Unexpected authentication provider id, got {alice['AuthenticationProviderId']}")
      #       if alice["PasswordResetProviderId"] != "Jellyfin.Plugin.LDAP_Auth.LdapAuthenticationProviderPlugin":
      #           raise Exception("Unexpected password resiet provider id, got {alice['PasswordResetProviderId']}")
      #       print(f"Users: \n{json.dumps(users, indent=4)}")

      #   with subtest("find alice devices"):
      #       devices = json.loads(server.succeed("sqlite3 /var/lib/jellyfin/data/jellyfin.db -json 'SELECT * FROM Devices;'"))
      #       aliceDevices = [d for d in devices if d["UserId"] == alice["Id"]]
      #       if len(aliceDevices) != 1:
      #           raise Exception(f"Unexpected number of devices for alice, got {len(aliceDevices)}\nUsers:\n{json.dumps(users, indent=4)}\nDevices:\n{json.dumps(devices, indent=4)}")
      # ''
      + ''
        switch_to_specialization("ldap")

        # This sleep is needed because Jellyfin reports it is ready before it truly is ready.
        # See ticket https://github.com/ibizaman/selfhostblocks/issues/842
        print("sleeping 60 seconds...")
        import time
        time.sleep(60)
      ''
      +
        (commonTestScript.access.override {
          init = true;
          preLoginScript = _: "";
        })
          (
            lib.recursiveUpdate args {
              nodes.server = nodes.server.specialisation.ldap.configuration;
              nodes.client = nodes.client.specialisation.ldap.configuration;
            }
          )
      + ''
        with subtest("find alice"):
            users = json.loads(server.succeed("sqlite3 /var/lib/jellyfin/data/jellyfin.db -json 'SELECT * FROM Users;'"))
            aliceUsers = [u for u in users if u["Username"] == "alice"]
            if len(aliceUsers) != 1:
                raise Exception(f"Unexpected number of users for alice, got {len(aliceUsers)}\n{json.dumps(users, indent=4)}")
            alice = aliceUsers[0]
            print(f"Users: \n{json.dumps(users, indent=4)}")
            if alice["AuthenticationProviderId"] != "Jellyfin.Plugin.LDAP_Auth.LdapAuthenticationProviderPlugin":
                raise Exception("Unexpected authentication provider id, got {alice['AuthenticationProviderId']}")
            if alice["PasswordResetProviderId"] != "Jellyfin.Plugin.LDAP_Auth.LdapAuthenticationProviderPlugin":
                raise Exception("Unexpected password resiet provider id, got {alice['PasswordResetProviderId']}")

        switch_to_specialization("sso")
        time.sleep(60)
      ''
      +
        (commonTestScript.access.override {
          init = false;
          preLoginScript = _: "";
        })
          (
            lib.recursiveUpdate args {
              nodes.server = nodes.server.specialisation.sso.configuration;
              nodes.client = nodes.client.specialisation.sso.configuration;
            }
          )
      + ''
        with subtest("find alice"):
            users = json.loads(server.succeed("sqlite3 /var/lib/jellyfin/data/jellyfin.db -json 'SELECT * FROM Users;'"))
            aliceUsers = [u for u in users if u["Username"] == "alice"]
            if len(aliceUsers) != 1:
                raise Exception(f"Unexpected number of users for alice, got {len(aliceUsers)}\n{json.dumps(users, indent=4)}")
            alice = aliceUsers[0]
            if alice["AuthenticationProviderId"] != "Jellyfin.Plugin.LDAP_Auth.LdapAuthenticationProviderPlugin":
                raise Exception("Unexpected authentication provider id, got {alice['AuthenticationProviderId']}")
            if alice["PasswordResetProviderId"] != "Jellyfin.Plugin.LDAP_Auth.LdapAuthenticationProviderPlugin":
                raise Exception("Unexpected password resiet provider id, got {alice['PasswordResetProviderId']}")
            print(f"Users: \n{json.dumps(users, indent=4)}")
      '';
  };
}
