{ lib, ... }:
let
  password = "securepw";
  oidcSecret = "oidcSecret";

  commonTestScript = lib.shb.accessScript {
    hasSSL = { node, ... }: !(isNull node.config.shb.monitoring.ssl);
    waitForServices =
      { ... }:
      [
        "grafana.service"
      ];
    waitForPorts =
      { node, ... }:
      [
        node.config.shb.monitoring.grafanaPort
      ];
  };

  basic =
    { config, ... }:
    {
      imports = [
        lib.shb.baseModule
        ../../modules/blocks/monitoring.nix
      ];

      test = {
        subdomain = "g";
      };

      shb.monitoring = {
        enable = true;
        inherit (config.test) subdomain domain;

        grafanaPort = 3000;
        adminPassword.result = config.shb.hardcodedsecret."admin_password".result;
        secretKey.result = config.shb.hardcodedsecret."secret_key".result;
      };

      shb.hardcodedsecret."admin_password" = {
        request = config.shb.monitoring.adminPassword.request;
        settings.content = password;
      };
      shb.hardcodedsecret."secret_key" = {
        request = config.shb.monitoring.secretKey.request;
        settings.content = "secret_key_pw";
      };
    };

  https =
    { config, ... }:
    {
      shb.monitoring = {
        ssl = config.shb.certs.certs.selfsigned.n;
      };
    };

  ldap =
    { config, ... }:
    {
      shb.monitoring = {
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
        lib.shb.baseModule
        lib.shb.clientLoginModule
      ];
      test = {
        subdomain = "g";
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
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = "alice";
            password = "AlicePassword";
            nextPageExpect = [
              "page.get_by_role('button', name=re.compile('Accept')).click()"
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible(timeout=10000)"
              "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
              "expect(page.get_by_text('Welcome to Grafana')).to_be_visible()"
            ];
          }
          {
            username = "bob";
            password = "NotBobPassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = "bob";
            password = "BobPassword";
            nextPageExpect = [
              "page.get_by_role('button', name=re.compile('Accept')).click()"
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible(timeout=10000)"
              "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
              "expect(page.get_by_text('Welcome to Grafana')).to_be_visible()"
            ];
          }
          {
            username = "charlie";
            password = "NotCharliePassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = "charlie";
            password = "CharliePassword";
            nextPageExpect = [
              "page.get_by_role('button', name=re.compile('Accept')).click()" # I don't understand why this is not needed. Maybe it keeps somewhere the previous token?
              "expect(page.get_by_text(re.compile('[Ll]ogin failed'))).to_be_visible(timeout=10000)"
            ];
          }
        ];
      };
    };

  sso =
    { config, ... }:
    {
      shb.monitoring = {
        sso = {
          enable = true;
          authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

          sharedSecret.result = config.shb.hardcodedsecret.oidcSecret.result;
          sharedSecretForAuthelia.result = config.shb.hardcodedsecret.oidcAutheliaSecret.result;
        };
      };

      shb.hardcodedsecret.oidcSecret = {
        request = config.shb.monitoring.sso.sharedSecret.request;
        settings.content = oidcSecret;
      };
      shb.hardcodedsecret.oidcAutheliaSecret = {
        request = config.shb.monitoring.sso.sharedSecretForAuthelia.request;
        settings.content = oidcSecret;
      };
    };
in
{
  basic = lib.shb.runNixOSTest {
    name = "monitoring_basic";

    nodes.server = {
      imports = [
        basic
      ];
    };

    nodes.client = { };

    testScript = commonTestScript;
  };

  https = lib.shb.runNixOSTest {
    name = "monitoring_https";

    nodes.server = {
      imports = [
        basic
        lib.shb.certs
        https
      ];
    };

    nodes.client = { };

    testScript = commonTestScript;
  };

  sso = lib.shb.runNixOSTest {
    name = "monitoring_sso";

    nodes.client = {
      imports = [
        clientLoginSso
      ];

      virtualisation.memorySize = 4096;
    };
    nodes.server =
      { config, pkgs, ... }:
      {
        imports = [
          basic
          lib.shb.certs
          https
          lib.shb.ldap
          ldap
          (lib.shb.sso config.shb.certs.certs.selfsigned.n)
          sso
        ];

        # virtualisation.memorySize = 4096;
      };

    testScript = commonTestScript;
  };
}
