{ pkgs, ... }:
let
  testLib = pkgs.callPackage ../common.nix {};

  adminPassword = "AdminPassword";

  commonTestScript = testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.forgejo.ssl);
    waitForServices = { ... }: [
      "forgejo.service"
      "nginx.service"
    ];
    waitForUnixSocket = { node, ... }: [
      node.config.services.forgejo.settings.server.HTTP_ADDR
    ];
    extraScript = { node, ... }: ''
    server.wait_for_unit("gitea-runner-local.service", timeout=10)
    server.succeed("journalctl -o cat -u gitea-runner-local.service | grep -q 'Runner registered successfully'")
    '';
  };

  basic = { config, ... }: {
    imports = [
      testLib.baseModule
      ../../modules/blocks/hardcodedsecret.nix
      ../../modules/services/forgejo.nix
    ];

    test = {
      subdomain = "f";
    };

    shb.forgejo = {
      enable = true;
      inherit (config.test) subdomain domain;

      users = {
        "theadmin" = {
          isAdmin = true;
          email = "theadmin@example.com";
          password.result = config.shb.hardcodedsecret.forgejoAdminPassword.result;
        };
        "theuser" = {
          email = "theuser@example.com";
          password.result = config.shb.hardcodedsecret.forgejoUserPassword.result;
        };
      };
      databasePassword.result = config.shb.hardcodedsecret.forgejoDatabasePassword.result;
    };

    # Needed for gitea-runner-local to be able to ping forgejo.
    networking.hosts = {
      "127.0.0.1" = [ "${config.test.subdomain}.${config.test.domain}" ];
    };

    shb.hardcodedsecret.forgejoAdminPassword = {
      request = config.shb.forgejo.users."theadmin".password.request;
      settings.content = adminPassword;
    };

    shb.hardcodedsecret.forgejoUserPassword = {
      request = config.shb.forgejo.users."theuser".password.request;
      settings.content = "userPassword";
    };

    shb.hardcodedsecret.forgejoDatabasePassword = {
      request = config.shb.forgejo.databasePassword.request;
      settings.content = "databasePassword";
    };
  };

  clientLogin = { config, ... }: {
    imports = [
      testLib.baseModule
      testLib.clientLoginModule
    ];
    test = {
      subdomain = "f";
    };

    test.login = {
      startUrl = "http://${config.test.fqdn}/user/login";
      usernameFieldLabelRegex = "Username or email address";
      passwordFieldLabelRegex = "Password";
      loginButtonNameRegex = "Sign In";
      testLoginWith = [
        { username = "theadmin"; password = adminPassword + "oops"; nextPageExpect = [
            "expect(page.get_by_text('Username or password is incorrect.')).to_be_visible()"
          ]; }
        { username = "theadmin"; password = adminPassword; nextPageExpect = [
            "expect(page.get_by_text('Username or password is incorrect.')).not_to_be_visible()"
            "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
            "expect(page).to_have_title(re.compile('Dashboard'))"
          ]; }
        { username = "theuser"; password = "userPasswordOops"; nextPageExpect = [
            "expect(page.get_by_text('Username or password is incorrect.')).to_be_visible()"
          ]; }
        { username = "theuser"; password = "userPassword"; nextPageExpect = [
            "expect(page.get_by_text('Username or password is incorrect.')).not_to_be_visible()"
            "expect(page.get_by_role('button', name=re.compile('Sign In'))).not_to_be_visible()"
            "expect(page).to_have_title(re.compile('Dashboard'))"
          ]; }
      ];
    };
  };

  https = { config, ... }: {
    shb.forgejo = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  ldap = { config, ... }: {
    shb.forgejo = {
      ldap = {
        enable = true;
        host = "127.0.0.1";
        port = config.shb.ldap.ldapPort;
        dcdomain = config.shb.ldap.dcdomain;
        adminPassword.result = config.shb.hardcodedsecret.forgejoLdapUserPassword.result;
      };
    };

    shb.hardcodedsecret.forgejoLdapUserPassword = {
      request = config.shb.forgejo.ldap.adminPassword.request;
      settings.content = "ldapUserPassword";
    };
  };

  sso = { config, ... }: {
    shb.forgejo = {
      sso = {
        enable = true;
        endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        sharedSecret.result = config.shb.hardcodedsecret.forgejoSSOPassword.result;
        sharedSecretForAuthelia.result = config.shb.hardcodedsecret.forgejoSSOPasswordAuthelia.result;
      };
    };

    shb.hardcodedsecret.forgejoSSOPassword = {
      request = config.shb.forgejo.sso.sharedSecret.request;
      settings.content = "ssoPassword";
    };

    shb.hardcodedsecret.forgejoSSOPasswordAuthelia = {
      request = config.shb.forgejo.sso.sharedSecretForAuthelia.request;
      settings.content = "ssoPassword";
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "forgejo_basic";

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

  backup = pkgs.testers.runNixOSTest {
    name = "forgejo_backup";

    nodes.server = { config, ... }: {
      imports = [
        basic
        (testLib.backup config.shb.forgejo.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };

  https = pkgs.testers.runNixOSTest {
    name = "forgejo_https";

    nodes.server = {
      imports = [
        basic
        testLib.certs
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  ldap = pkgs.testers.runNixOSTest {
    name = "forgejo_ldap";

    nodes.server = {
      imports = [
        basic
        testLib.ldap
        ldap
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript.access;
  };

  sso = pkgs.testers.runNixOSTest {
    name = "forgejo_sso";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        basic
        testLib.certs
        https
        testLib.ldap
        (testLib.sso config.shb.certs.certs.selfsigned.n)
        sso
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };
}
