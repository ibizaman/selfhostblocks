{ pkgs, shb, ... }:
let
  commonTestScript = shb.test.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.firefly-iii.ssl);
    waitForServices =
      { ... }:
      [
        "phpfpm-firefly-iii.service"
        "phpfpm-firefly-iii-data-importer.service"
        "nginx.service"
      ];
    waitForPorts =
      { node, ... }:
      [
        # node.config.shb.firefly-iii.port
      ];
  };

  basic =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        ../../modules/blocks/hardcodedsecret.nix
        ../../modules/services/firefly-iii.nix
      ];

      test = {
        subdomain = "f";
      };

      shb.firefly-iii = {
        enable = true;
        debug = true;
        inherit (config.test) subdomain domain;
        siteOwnerEmail = "mail@example.com";
        appKey.result = config.shb.hardcodedsecret.appKey.result;
        dbPassword.result = config.shb.hardcodedsecret.dbPassword.result;
        importer.firefly-iii-accessToken.result = config.shb.hardcodedsecret.accessToken.result;
      };

      # systemd.tmpfiles.rules = [
      #   "d '/src/firefly-iii' 0750 pinchflat pinchflat - -"
      # ];

      # Needed for gitea-runner-local to be able to ping firefly-iii.
      # networking.hosts = {
      #   "127.0.0.1" = [ "${config.test.subdomain}.${config.test.domain}" ];
      # };

      shb.hardcodedsecret.appKey = {
        request = config.shb.firefly-iii.appKey.request;
        # Firefly-iir requires this to be exactly 32 characters.
        settings.content = pkgs.lib.strings.replicate 32 "Z";
      };
      shb.hardcodedsecret.dbPassword = {
        request = config.shb.firefly-iii.dbPassword.request;
        settings.content = pkgs.lib.strings.replicate 64 "Y";
      };
      shb.hardcodedsecret.accessToken = {
        request = config.shb.firefly-iii.importer.firefly-iii-accessToken.request;
        settings.content = pkgs.lib.strings.replicate 64 "X";
      };
    };

  clientLogin =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];
      test = {
        subdomain = "f";
      };

      test.login = {
        startUrl = "http://${config.test.fqdn}";
        # There is no login without SSO integration.
        testLoginWith = [
          {
            username = null;
            password = null;
            nextPageExpect = [
              "expect(page.get_by_text('Register a new account')).to_be_visible()"
            ];
          }
        ];
      };
    };

  clientLoginDataImporter =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];
      test = {
        subdomain = "f-importer";
      };

      test.login = {
        startUrl = "http://${config.test.fqdn}";
        # There is no login without SSO integration.
        testLoginWith = [
          {
            username = null;
            password = null;
            nextPageExpect = [
              # The error to connect is expected since the access token must be created manually in Firefly-iii.
              "expect(page.get_by_text('The importer could not connect')).to_be_visible()"
            ];
          }
        ];
      };
    };

  https =
    { config, ... }:
    {
      shb.firefly-iii = {
        ssl = config.shb.certs.certs.selfsigned.n;
      };
    };

  ldap =
    { config, ... }:
    {
      shb.firefly-iii = {
        ldap = {
          userGroup = "user_group";
          adminGroup = "admin_group";
        };
      };
    };

  clientLoginSso =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];
      test = {
        subdomain = "f";
      };

      test.login = {
        startUrl = "https://${config.test.fqdn}";
        usernameFieldLabelRegex = "Username";
        passwordFieldLabelRegex = "Password";
        loginButtonNameRegex = "[sS]ign [iI]n";
        testLoginWith = [
          {
            username = "alice";
            password = "NotAlicePassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
            ];
          }
          {
            username = "alice";
            password = "AlicePassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible()"
              "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
              "expect(page.get_by_text('Dashboard')).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = "bob";
            password = "NotBobPassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
            ];
          }
          {
            username = "bob";
            password = "BobPassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible()"
              "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
              "expect(page.get_by_text('Dashboard')).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = "charlie";
            password = "NotCharliePassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
            ];
          }
          {
            username = "charlie";
            password = "CharliePassword";
            nextPageExpect = [
              "expect(page).to_have_url(re.compile('.*/authenticated'))"
            ];
          }
        ];
      };
    };

  clientLoginSsoDataImporter =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        shb.test.clientLoginModule
      ];
      test = {
        subdomain = "f-importer";
      };

      test.login = {
        startUrl = "https://${config.test.fqdn}";
        usernameFieldLabelRegex = "Username";
        passwordFieldLabelRegex = "Password";
        loginButtonNameRegex = "[sS]ign [iI]n";
        testLoginWith = [
          {
            username = "alice";
            password = "NotAlicePassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
            ];
          }
          {
            username = "alice";
            password = "AlicePassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible()"
              "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
              # Only admins have access
              "expect(page.get_by_text('Authenticated')).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = "bob";
            password = "NotBobPassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
            ];
          }
          {
            username = "bob";
            password = "BobPassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible()"
              "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
              # The error to connect is expected since the access token must be created manually in Firefly-iii.
              "expect(page.get_by_text('The importer could not connect')).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = "charlie";
            password = "NotCharliePassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible()"
            ];
          }
          {
            username = "charlie";
            password = "CharliePassword";
            nextPageExpect = [
              "expect(page).to_have_url(re.compile('.*/authenticated'))"
            ];
          }
        ];
      };
    };

  sso =
    { config, ... }:
    {
      shb.firefly-iii = {
        sso = {
          enable = true;
          authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        };
      };
    };
in
{
  basic = shb.test.runNixOSTest {
    name = "firefly-iii_basic";

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

  data-importer_basic = shb.test.runNixOSTest {
    name = "firefly-iii-data-importer_basic";

    nodes.client = {
      imports = [
        clientLoginDataImporter
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
    name = "firefly-iii_backup";

    nodes.server =
      { config, ... }:
      {
        imports = [
          basic
          (shb.test.backup config.shb.firefly-iii.backup)
        ];
      };

    nodes.client = { };

    testScript = commonTestScript.backup;
  };

  https = shb.test.runNixOSTest {
    name = "firefly-iii_https";

    nodes.client = {
      imports = [
        clientLogin
      ];
    };
    nodes.server = {
      imports = [
        basic
        shb.test.certs
        https
      ];
    };

    testScript = commonTestScript.access;
  };

  sso = shb.test.runNixOSTest {
    name = "firefly-iii_sso";

    nodes.client = {
      imports = [
        clientLoginSso
      ];
    };
    nodes.server =
      { config, pkgs, ... }:
      {
        imports = [
          basic
          shb.test.certs
          https
          shb.test.ldap
          ldap
          (shb.test.sso config.shb.certs.certs.selfsigned.n)
          sso
        ];
      };

    testScript = commonTestScript.access.override {
      redirectSSO = true;
    };
  };

  data-importer_sso = shb.test.runNixOSTest {
    name = "firefly-iii-data-importer_sso";

    nodes.client = {
      imports = [
        clientLoginSsoDataImporter
      ];
    };
    nodes.server =
      { config, pkgs, ... }:
      {
        imports = [
          basic
          shb.test.certs
          https
          shb.test.ldap
          ldap
          (shb.test.sso config.shb.certs.certs.selfsigned.n)
          sso
        ];
      };

    testScript = commonTestScript.access;
  };
}
