{ pkgs, shb, ... }:
let
  port = 9096;

  adminUser = "jellyfin2";
  adminPassword = "admin";

  commonTestScript = shb.test.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.jellyfin.ssl);
    waitForServices =
      { ... }:
      [
        "jellyfin.service"
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
    extraScript =
      { node, ... }:
      ''
        server.wait_until_succeeds("journalctl --since -1m --unit jellyfin --grep 'Startup complete'")
        headers = unline_with(" ", """
            -H 'Content-Type: application/json'
            -H 'Authorization: MediaBrowser Client="Android TV", Device="Nvidia Shield", DeviceId="ZQ9YQHHrUzk24vV", Version="0.15.3"'
        """)
        import time
        with subtest("api login success"):
            ok = False
            for i in range(1, 5):
                response = curl(client, """{"code":%{response_code}}""", "${node.config.test.proto_fqdn}/Users/AuthenticateByName",
                    data="""{"Username": "${adminUser}", "Pw": "${adminPassword}"}""",
                    extra=headers)
                if response['code'] == 200:
                    ok = True
                    break
                time.sleep(5)
            if not ok:
                raise Exception(f"Expected success, got: {response['code']}")

        with subtest("api login failure"):
            response = curl(client, """{"code":%{response_code}}""", "${node.config.test.proto_fqdn}/Users/AuthenticateByName",
                data="""{"Username": "${adminUser}", "Pw": "badpassword"}""",
                extra=headers)
            if response['code'] != 401:
                raise Exception(f"Expected failure, got: {response['code']}")
      '';
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
      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];
      virtualisation.memorySize = 4096;

      test = {
        subdomain = "j";
      };

      test.login = {
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
      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];
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
      extraScript =
        {
          node,
          ...
        }:
        # I have no idea why the LDAP Authentication_19.0.0.0 plugin disappears.
        ''
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
}
