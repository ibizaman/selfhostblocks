{
  pkgs,
  lib,
  shb,
}:
let
  subdomain = "p";
  domain = "example.com";

  commonTestScript = shb.test.accessScript {
    hasSSL = { node, ... }: !(isNull node.config.shb.paperless.ssl);
    waitForServices =
      { ... }:
      [
        "paperless-web.service"
        "nginx.service"
      ];
    waitForPorts =
      { ... }:
      [
        28981
        80
      ];
    waitForUrls = { proto_fqdn, ... }: [ "${proto_fqdn}" ];
  };

  base =
    { config, ... }:
    {
      imports = [
        shb.test.baseModule
        ../../modules/services/paperless.nix
      ];

      virtualisation.memorySize = 4096;
      virtualisation.cores = 2;

      test = {
        inherit subdomain domain;
      };

      shb.paperless = {
        enable = true;
        inherit subdomain domain;
      };

      # Required for tests
      environment.systemPackages = [ pkgs.curl ];
    };

  basic =
    { config, ... }:
    {
      imports = [ base ];

      test.hasSSL = false;
    };

  https =
    { config, ... }:
    {
      imports = [
        base
        shb.test.certs
      ];

      test.hasSSL = true;
      shb.paperless.ssl = config.shb.certs.certs.selfsigned.n;
    };

  backup =
    { config, ... }:
    {
      imports = [
        https
        (shb.test.backup config.shb.paperless.backup)
      ];
    };

  sso =
    { config, ... }:
    {
      imports = [
        https
        shb.test.ldap
        (shb.test.sso config.shb.certs.certs.selfsigned.n)
      ];

      shb.paperless.sso = {
        enable = true;
        provider = "Authelia";
        endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
        clientID = "paperless";
        autoLaunch = true;
        sharedSecret.result = config.shb.hardcodedsecret.paperlessSSOSecret.result;
        sharedSecretForAuthelia.result = config.shb.hardcodedsecret.paperlessSSOSecretAuthelia.result;
      };

      shb.hardcodedsecret.paperlessSSOSecret = {
        request = config.shb.paperless.sso.sharedSecret.request;
        settings.content = "paperlessSSOSecret";
      };

      shb.hardcodedsecret.paperlessSSOSecretAuthelia = {
        request = config.shb.paperless.sso.sharedSecretForAuthelia.request;
        settings.content = "paperlessSSOSecret";
      };

      # Configure LDAP groups for group-based access control
      shb.lldap.ensureGroups.paperless_user = { };

      shb.lldap.ensureUsers.paperless_test_user = {
        email = "paperless_user@example.com";
        groups = [ "paperless_user" ];
        password.result = config.shb.hardcodedsecret.ldappaperlessUserPassword.result;
      };

      shb.lldap.ensureUsers.regular_test_user = {
        email = "regular_user@example.com";
        groups = [ ];
        password.result = config.shb.hardcodedsecret.ldapRegularUserPassword.result;
      };

      shb.hardcodedsecret.ldappaperlessUserPassword = {
        request = config.shb.lldap.ensureUsers.paperless_test_user.password.request;
        settings.content = "paperless_user_password";
      };

      shb.hardcodedsecret.ldapRegularUserPassword = {
        request = config.shb.lldap.ensureUsers.regular_test_user.password.request;
        settings.content = "regular_user_password";
      };
    };
in
{
  basic = pkgs.nixosTest {
    name = "paperless-basic";

    nodes.server = basic;
    nodes.client = { };

    testScript = commonTestScript;
  };

  https = pkgs.nixosTest {
    name = "paperless-https";

    nodes.server = https;
    nodes.client = { };

    testScript = commonTestScript;
  };

  sso = pkgs.nixosTest {
    name = "paperless-https";

    nodes.server = sso;
    nodes.client = { };

    testScript = commonTestScript;
  };

  backup = pkgs.nixosTest {
    name = "paperless-backup";

    nodes.server = backup;
    nodes.client = { };

    testScript =
      (shb.test.mkScripts {
        hasSSL = args: !(isNull args.node.config.shb.paperless.ssl);
        waitForServices = args: [
          "paperless-web.service"
          "nginx.service"
        ];
        waitForPorts = args: [
          28981
          80
        ];
        waitForUrls = args: [ "${args.proto_fqdn}" ];
      }).backup;
  };

}
