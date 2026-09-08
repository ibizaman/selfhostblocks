{
  shb,
  ...
}:
let
  port = 2283;

  adminEmail = "admin@example.com";
  adminPassword = "immichadmin";

  commonTestScript = shb.test.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.immich.ssl);
    waitForServices =
      { ... }:
      [
        "immich-server.service"
        "postgresql.service"
        "nginx.service"
      ];
    waitForPorts =
      { ... }:
      [
        port
        80
      ];
    waitForUrls = { proto_fqdn, ... }: [ "${proto_fqdn}" ];
  };

  basic =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        ../../modules/services/immich.nix
      ];
      # Immich requires that much memory
      virtualisation.memorySize = 4096;
      virtualisation.cores = 2;

      test = {
        subdomain = "i";
      };

      shb.immich = {
        enable = true;
        inherit (config.test) subdomain domain;

        initialAdmin = {
          name = "Admin";
          email = adminEmail;
          passwordFile.result = config.shb.hardcodedsecret.adminPassword.result;
        };
        skipOnboarding = true;

        debug = true;
      };
      shb.hardcodedsecret.adminPassword = {
        request = config.shb.immich.initialAdmin.passwordFile.request;
        settings.content = adminPassword;
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
        subdomain = "j";
      };

      test.login = {
        browser = "firefox";
        startUrl = "${config.test.proto}://${config.test.fqdn}";
        usernameFieldLabelRegex = "[Ee]mail";
        loginButtonNameRegex = "Login";
        testLoginWith = [
          {
            username = adminEmail;
            password = "badpassword";
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).to_be_visible(timeout=10000)"
            ];
          }
          {
            username = adminEmail;
            password = adminPassword;
            nextPageExpect = [
              "expect(page.get_by_text(re.compile('[Ii]ncorrect'))).not_to_be_visible(timeout=10000)"
              "expect(page.get_by_label(re.compile('^[Ee]mail'))).not_to_be_visible(timeout=10000)"
              "expect(page.get_by_label(re.compile('^[Pp]assword$'))).not_to_be_visible(timeout=10000)"
              "expect(page.get_by_text(re.compile('Click to upload'))).to_be_visible(timeout=10000)"
            ];
          }
        ];
      };
    };

  https =
    { config, ... }:
    {
      test.hasSSL = true;
      shb.immich.ssl = config.shb.certs.certs.selfsigned.n;
    };

  sso =
    { config, ... }:
    {
      imports = [
        https
        shb.test.ldap
        (shb.test.sso config.shb.certs.certs.selfsigned.n)
      ];

      shb.immich.sso = {
        enable = true;
        provider = "Authelia";
        endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        clientID = "immich";
        autoLaunch = true;
        sharedSecret.result = config.shb.hardcodedsecret.immichSSOSecret.result;
        sharedSecretForAuthelia.result = config.shb.hardcodedsecret.immichSSOSecretAuthelia.result;
      };

      shb.hardcodedsecret.immichSSOSecret = {
        request = config.shb.immich.sso.sharedSecret.request;
        settings.content = "immichSSOSecret";
      };

      shb.hardcodedsecret.immichSSOSecretAuthelia = {
        request = config.shb.immich.sso.sharedSecretForAuthelia.request;
        settings.content = "immichSSOSecret";
      };

      # Configure LDAP groups for group-based access control
      shb.lldap.ensureGroups.immich_user = { };

      shb.lldap.ensureUsers.immich_test_user = {
        email = "immich_user@example.com";
        groups = [ "immich_user" ];
        password.result = config.shb.hardcodedsecret.ldapImmichUserPassword.result;
      };

      shb.lldap.ensureUsers.regular_test_user = {
        email = "regular_user@example.com";
        groups = [ ];
        password.result = config.shb.hardcodedsecret.ldapRegularUserPassword.result;
      };

      shb.hardcodedsecret.ldapImmichUserPassword = {
        request = config.shb.lldap.ensureUsers.immich_test_user.password.request;
        settings.content = "immich_user_password";
      };

      shb.hardcodedsecret.ldapRegularUserPassword = {
        request = config.shb.lldap.ensureUsers.regular_test_user.password.request;
        settings.content = "regular_user_password";
      };
    };
in
{
  basic = shb.test.runNixOSTest {
    name = "immich_basic";

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

  https = shb.test.runNixOSTest {
    name = "immich_https";

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

  backup = shb.test.runNixOSTest {
    name = "immich_backup";

    nodes.server =
      { config, ... }:
      {
        imports = [
          basic
          (shb.test.backup config.shb.immich.backup)
        ];
      };

    nodes.client = { };

    testScript = commonTestScript.backup;
  };
}
