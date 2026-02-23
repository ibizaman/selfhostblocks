{ shb, ... }:
let
  commonTestScript = shb.test.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.homepage.ssl);
    waitForServices =
      { ... }:
      [
        "homepage-dashboard.service"
        "nginx.service"
      ];
    waitForPorts =
      { node, ... }:
      [
        node.config.services.homepage-dashboard.listenPort
      ];
  };

  basic =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        ../../modules/blocks/hardcodedsecret.nix
        ../../modules/services/homepage.nix
      ];

      test = {
        subdomain = "h";
      };

      shb.homepage = {
        enable = true;
        inherit (config.test) subdomain domain;

        servicesGroups.MyHomeGroup.services.TestService.dashboard = { };
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
        subdomain = "h";
      };

      test.login = {
        startUrl = "http://${config.test.fqdn}";
        # There is no login without SSO integration.
        testLoginWith = [
          {
            username = null;
            password = null;
            nextPageExpect = [
              "expect(page.get_by_text('TestService')).to_be_visible()"
            ];
          }
        ];
      };
    };

  https =
    { config, ... }:
    {
      shb.homepage = {
        ssl = config.shb.certs.certs.selfsigned.n;
      };
    };

  ldap =
    { config, ... }:
    {
      shb.homepage = {
        ldap = {
          userGroup = "user_group";
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
        subdomain = "h";
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
              "expect(page.get_by_text('TestService')).to_be_visible(timeout=10000)"
            ];
          }
          # Bob, with its admin role only, cannot login into Karakeep because admins do not exist in Karakeep.
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
      shb.homepage = {
        sso = {
          enable = true;
          authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        };
      };
    };
in
{
  basic = shb.test.runNixOSTest {
    name = "homepage_basic";

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

  https = shb.test.runNixOSTest {
    name = "homepage_https";

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
    name = "homepage_sso";

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
}
