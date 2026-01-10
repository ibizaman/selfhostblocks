{ pkgs, shb, ... }:
let
  port = 9096;

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
      ];
    extraScript =
      { node, ... }:
      ''
        headers = unline_with(" ", """
            -H 'Content-Type: application/json'
            -H 'Authorization: MediaBrowser Client="Android TV", Device="Nvidia Shield", DeviceId="ZQ9YQHHrUzk24vV", Version="0.15.3"'
        """)
        with subtest("api login success"):
            response = curl(client, """{"code":%{response_code}}""", "${node.config.test.proto_fqdn}/Users/AuthenticateByName",
                data="""{"Username": "jellyfin", "Pw": "admin"}""",
                extra=headers)
            if response['code'] != 200:
                raise Exception(f"Expected success, got: {response['code']}")

        with subtest("api login failure"):
            response = curl(client, """{"code":%{response_code}}""", "${node.config.test.proto_fqdn}/Users/AuthenticateByName",
                data="""{"Username": "jellyfin", "Pw": "badpassword"}""",
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
      test = {
        subdomain = "j";
      };

      shb.jellyfin = {
        enable = true;
        inherit (config.test) subdomain domain;
        inherit port;
        admin = {
          username = "jellyfin";
          password.result = config.shb.hardcodedsecret.jellyfinAdminPassword.result;
        };
        debug = true;
      };

      shb.hardcodedsecret.jellyfinAdminPassword = {
        request = config.shb.jellyfin.admin.password.request;
        settings.content = "admin";
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
            username = "jellyfin";
            password = "badpassword";
            nextPageExpect = [
              "expect(page).to_have_title(re.compile('Jellyfin'))"
              "expect(page.get_by_text(re.compile('[Ii]nvalid'))).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = "jellyfin";
            password = "admin";
            nextPageExpect = [
              "expect(page).to_have_title(re.compile('Jellyfin'))"
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
    { config, ... }:
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
            username = "jellyfin";
            password = "badpassword";
            nextPageExpect = [
              "expect(page).to_have_title(re.compile('Jellyfin'))"
              "expect(page.get_by_text(re.compile('[Ii]nvalid'))).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = "jellyfin";
            password = "admin";
            nextPageExpect = [
              "expect(page).to_have_title(re.compile('Jellyfin'))"
              "expect(page.get_by_text(re.compile('[Ii]nvalid'))).not_to_be_visible(timeout=10000)"
              "expect(page.get_by_label(re.compile('^[Uu]ser'))).not_to_be_visible(timeout=10000)"
              "expect(page.get_by_label(re.compile('^[Pp]assword$'))).not_to_be_visible(timeout=10000)"
            ];
          }
          {
            username = "alice";
            password = "AlicePassword";
            nextPageExpect = [
              "expect(page).to_have_title(re.compile('Jellyfin'))"
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
              "expect(page).to_have_title(re.compile('Jellyfin'))"
              "expect(page.get_by_text(re.compile('[Ii]nvalid'))).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = "bob";
            password = "BobPassword";
            nextPageExpect = [
              "expect(page).to_have_title(re.compile('Jellyfin'))"
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
              "expect(page).to_have_title(re.compile('Jellyfin'))"
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
              "expect(page).to_have_title(re.compile('Jellyfin'))"
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
              "expect(page).to_have_title(re.compile('Jellyfin'))"
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
              "expect(page).to_have_title(re.compile('Jellyfin'))"
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
              "expect(page).to_have_title(re.compile('Jellyfin'))"
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

    testScript = commonTestScript.access;
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
