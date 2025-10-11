{ pkgs, lib }:
let
  subdomain = "i";
  domain = "example.com";

  commonTestScript = lib.shb.accessScript {
    hasSSL = { node, ... }: !(isNull node.config.shb.immich.ssl);
    waitForServices = { ... }: [ "immich-server.service" "postgresql.service" "nginx.service" ];
    waitForPorts = { ... }: [ 2283 80 ];
    waitForUrls = { proto_fqdn, ... }: [ "${proto_fqdn}" ];
  };

  base = { config, ... }: {
    imports = [
      lib.shb.baseModule
      ../../modules/services/immich.nix
    ];

    virtualisation.memorySize = 4096;
    virtualisation.cores = 2;

    test = {
      inherit subdomain domain;
    };

    shb.immich = {
      enable = true;
      inherit subdomain domain;

      debug = true;
    };

    # Required for tests
    environment.systemPackages = [ pkgs.curl ];
  };

  basic = { config, ... }: {
    imports = [ base ];

    test.hasSSL = false;
  };

  https = { config, ... }: {
    imports = [
      base
      lib.shb.certs
    ];

    test.hasSSL = true;
    shb.immich.ssl = config.shb.certs.certs.selfsigned.n;
  };

  backup = { config, ... }: {
    imports = [
      https
      (lib.shb.backup config.shb.immich.backup)
    ];
  };

  sso = { config, ... }: {
    imports = [
      https
      lib.shb.ldap
      (lib.shb.sso config.shb.certs.certs.selfsigned.n)
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
    shb.lldap.ensureGroups.immich_user = {};

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
  basic = pkgs.nixosTest {
    name = "immich-basic";

    nodes.server = basic;
    nodes.client = {};

    testScript = commonTestScript;
  };

  https = pkgs.nixosTest {
    name = "immich-https";

    nodes.server = https;
    nodes.client = {};

    testScript = commonTestScript;
  };

  backup = pkgs.nixosTest {
    name = "immich-backup";

    nodes.server = backup;
    nodes.client = {};

    testScript = (lib.shb.mkScripts { 
      hasSSL = args: !(isNull args.node.config.shb.immich.ssl);
      waitForServices = args: [ "immich-server.service" "postgresql.service" "nginx.service" ];
      waitForPorts = args: [ 2283 80 ];
      waitForUrls = args: [ "${args.proto_fqdn}" ];
    }).backup;
  };
}
