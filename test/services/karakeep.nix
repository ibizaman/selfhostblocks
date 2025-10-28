{ pkgs, ... }:
let
  nextauthSecret = "nextauthSecret";
  oidcSecret = "oidcSecret";

  testLib = pkgs.callPackage ../common.nix { };

  commonTestScript = testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.karakeep.ssl);
    waitForServices =
      { ... }:
      [
        "karakeep-init.service"
        "karakeep-browser.service"
        "karakeep-web.service"
        "karakeep-workers.service"
        "nginx.service"
      ];
    waitForPorts =
      { node, ... }:
      [
        node.config.shb.karakeep.port
      ];
  };

  basic =
    { config, ... }:
    {
      imports = [
        testLib.baseModule
        ../../modules/blocks/hardcodedsecret.nix
        ../../modules/blocks/lldap.nix
        ../../modules/services/karakeep.nix
      ];

      test = {
        subdomain = "k";
      };

      shb.karakeep = {
        enable = true;
        inherit (config.test) subdomain domain;

        nextauthSecret.result = config.shb.hardcodedsecret.nextauthSecret.result;
        meilisearchMasterKey.result = config.shb.hardcodedsecret.meilisearchMasterKey.result;
      };

      shb.hardcodedsecret.nextauthSecret = {
        request = config.shb.karakeep.nextauthSecret.request;
        settings.content = nextauthSecret;
      };
      shb.hardcodedsecret.meilisearchMasterKey = {
        request = config.shb.karakeep.meilisearchMasterKey.request;
        settings.content = "meilisearch-master-key";
      };

      networking.hosts = {
        "127.0.0.1" = [ "${config.test.subdomain}.${config.test.domain}" ];
      };
    };

  https =
    { config, ... }:
    {
      shb.karakeep = {
        ssl = config.shb.certs.certs.selfsigned.n;
      };
    };

  ldap =
    { config, ... }:
    {
      shb.karakeep = {
        ldap = {
          userGroup = "user_group";
        };
      };
    };

  clientLoginSso =
    { config, ... }:
    {
      imports = [
        testLib.baseModule
        testLib.clientLoginModule
      ];
      test = {
        subdomain = "k";
      };

      test.login = {
        startUrl = "https://${config.test.fqdn}";
        beforeHook = ''
          page.get_by_role("button", name="single sign-on").click()
        '';
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
              "expect(page.get_by_text('new item')).to_be_visible()"
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
              "expect(page.get_by_text('new item')).to_be_visible()"
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
              # "page.get_by_role('button', name=re.compile('Accept')).click()" # I don't understand why this is not needed. Maybe it keeps somewhere the previous token?
              "expect(page.get_by_text(re.compile('login failed'))).to_be_visible(timeout=10000)"
            ];
          }
        ];
      };
    };

  sso =
    { config, ... }:
    {
      shb.karakeep = {
        sso = {
          enable = true;
          authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          clientID = "karakeep";

          sharedSecret.result = config.shb.hardcodedsecret.oidcSecret.result;
          sharedSecretForAuthelia.result = config.shb.hardcodedsecret.oidcAutheliaSecret.result;
        };
      };

      shb.hardcodedsecret.oidcSecret = {
        request = config.shb.karakeep.sso.sharedSecret.request;
        settings.content = oidcSecret;
      };
      shb.hardcodedsecret.oidcAutheliaSecret = {
        request = config.shb.karakeep.sso.sharedSecretForAuthelia.request;
        settings.content = oidcSecret;
      };
    };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "karakeep_basic";

    nodes.client = { };
    nodes.server = {
      imports = [
        basic
      ];
    };

    testScript = commonTestScript.access;
  };

  backup = pkgs.testers.runNixOSTest {
    name = "karakeep_backup";

    nodes.server =
      { config, ... }:
      {
        imports = [
          basic
          (testLib.backup config.shb.karakeep.backup)
        ];
      };

    nodes.client = { };

    testScript = commonTestScript.backup;
  };

  https = pkgs.testers.runNixOSTest {
    name = "karakeep_https";

    nodes.client = { };
    nodes.server = {
      imports = [
        basic
        testLib.certs
        https
      ];
    };

    testScript = commonTestScript.access;
  };

  sso = pkgs.testers.runNixOSTest {
    name = "karakeep_sso";
    interactive.sshBackdoor.enable = true;

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
          testLib.certs
          https
          testLib.ldap
          ldap
          (testLib.sso config.shb.certs.certs.selfsigned.n)
          sso
        ];

        virtualisation.memorySize = 4096;
      };

    testScript = commonTestScript.access;
  };
}
