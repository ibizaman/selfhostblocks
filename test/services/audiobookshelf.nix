{ shb, ... }:
let
  commonTestScript = shb.test.accessScript {
    hasSSL = { node, ... }: !(isNull node.config.shb.audiobookshelf.ssl);
    waitForServices =
      { ... }:
      [
        "audiobookshelf.service"
        "nginx.service"
      ];
    waitForPorts =
      { node, ... }:
      [
        node.config.shb.audiobookshelf.webPort
      ];
    # TODO: Test login
    # extraScript = { ... }: ''
    # '';
  };

  basic =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        ../../modules/services/audiobookshelf.nix
      ];

      test = {
        subdomain = "a";
      };
      shb.audiobookshelf = {
        enable = true;
        inherit (config.test) subdomain domain;
      };
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
        subdomain = "a";
      };

      test.login = {
        startUrl = "http://${config.test.fqdn}";
        usernameFieldLabelRegex = "[Uu]sername";
        passwordFieldLabelRegex = "[Pp]assword";
        loginButtonNameRegex = "[Ll]og [Ii]n";
        testLoginWith = [
          # Failure is after so we're not throttled too much.
          {
            username = "root";
            password = "rootpw";
            nextPageExpect = [
              "expect(page.get_by_text('Wrong username or password')).to_be_visible()"
            ];
          }
          # { username = adminUser; password = adminPass; nextPageExpect = [
          #     "expect(page.get_by_text('Wrong username or password')).not_to_be_visible()"
          #     "expect(page.get_by_role('button', name=re.compile('[Ll]og [Ii]n'))).not_to_be_visible()"
          #     "expect(page).to_have_title(re.compile('Dashboard'))"
          #   ]; }
        ];
      };
    };

  https =
    { config, ... }:
    {
      shb.audiobookshelf = {
        ssl = config.shb.certs.certs.selfsigned.n;
      };
    };

  sso =
    { config, ... }:
    {
      shb.audiobookshelf = {
        sso = {
          enable = true;
          endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          sharedSecret.result = config.shb.hardcodedsecret.audiobookshelfSSOPassword.result;
          sharedSecretForAuthelia.result =
            config.shb.hardcodedsecret.audiobookshelfSSOPasswordAuthelia.result;
        };
      };

      shb.hardcodedsecret.audiobookshelfSSOPassword = {
        request = config.shb.audiobookshelf.sso.sharedSecret.request;
        settings.content = "ssoPassword";
      };

      shb.hardcodedsecret.audiobookshelfSSOPasswordAuthelia = {
        request = config.shb.audiobookshelf.sso.sharedSecretForAuthelia.request;
        settings.content = "ssoPassword";
      };
    };
in
{
  basic = shb.test.runNixOSTest {
    name = "audiobookshelf-basic";

    nodes.client = {
      imports = [
        # TODO: enable this when declarative user management is possible.
        # clientLogin
      ];
    };
    nodes.server = {
      imports = [
        basic
      ];
    };

    testScript = commonTestScript;
  };

  https = shb.test.runNixOSTest {
    name = "audiobookshelf-https";

    nodes.server = {
      imports = [
        basic
        shb.test.certs
        https
      ];
    };

    nodes.client = { };

    testScript = commonTestScript;
  };

  sso = shb.test.runNixOSTest {
    name = "audiobookshelf-sso";

    nodes.server =
      { config, ... }:
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

    nodes.client = { };

    testScript = commonTestScript;
  };
}
