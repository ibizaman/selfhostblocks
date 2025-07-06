{ pkgs, lib, ... }:
let
  testLib = pkgs.callPackage ../common.nix {};

  commonTestScript = testLib.mkScripts {
    hasSSL = { node, ... }: !(isNull node.config.shb.vaultwarden.ssl);
    waitForServices = { ... }: [
      "vaultwarden.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      8222
      5432
    ];
    # to get the get token test to succeed we need:
    # 1. add group Vaultwarden_admin to LLDAP
    # 2. add an Authelia user with to that group
    # 3. login in Authelia with that user
    # 4. go to the Vaultwarden /admin endpoint
    # 5. create a Vaultwarden user
    # 6. now login with that new user to Vaultwarden
    extraScript = { node, proto_fqdn, ... }: ''
    with subtest("prelogin"):
        response = curl(client, "", "${proto_fqdn}/identity/accounts/prelogin", data=unline_with("", """
            {"email": "me@example.com"}
        """))
        print(response)
        if 'kdf' not in response:
            raise Exception("Unrecognized response: {}".format(response))

    with subtest("get token"):
        response = curl(client, "", "${proto_fqdn}/identity/connect/token", data=unline_with("", """
          scope=api%20offline_access
          &client_id=web
          &deviceType=10
          &deviceIdentifier=a60323bf-4686-4b4d-96e0-3c241fa5581c
          &deviceName=firefox
          &grant_type=password&username=me
          &password=mypassword
        """))
        print(response)
        if response["message"] != "Username or password is incorrect. Try again":
            raise Exception("Unrecognized response: {}".format(response))
    '';
  };

  basic = { config, ... }: {
    test = {
      subdomain = "v";
    };

    shb.vaultwarden = {
      enable = true;
      inherit (config.test) subdomain domain;

      port = 8222;
      databasePassword.result = config.shb.hardcodedsecret.passphrase.result;
    };
    shb.hardcodedsecret.passphrase = {
      request = config.shb.vaultwarden.databasePassword.request;
      settings.content = "PassPhrase";
    };

    # networking.hosts = {
    #   "127.0.0.1" = [ fqdn ];
    # };
  };

  https = { config, ... }: {
    shb.vaultwarden = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  # Not yet supported
  # ldap = { config, ... }: {
  #   # shb.vaultwarden = {
  #   #   ldapHostname = "127.0.0.1";
  #   #   ldapPort = config.shb.ldap.webUIListenPort;
  #   # };
  # };

  sso = { config, ... }: {
    shb.vaultwarden = {
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "vaultwarden_basic";

    nodes.server = {
      imports = [
        testLib.baseModule
        ../../modules/blocks/hardcodedsecret.nix
        ../../modules/services/vaultwarden.nix
        basic
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  https = pkgs.testers.runNixOSTest {
    name = "vaultwarden_https";

    nodes.server = {
      imports = [
        testLib.baseModule
        ../../modules/blocks/hardcodedsecret.nix
        ../../modules/services/vaultwarden.nix
        testLib.certs
        basic
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access;
  };

  # Not yet supported
  #
  # ldap = pkgs.testers.runNixOSTest {
  #   name = "vaultwarden_ldap";
  #
  #   nodes.server = lib.mkMerge [ 
  #     testLib.baseModule
  #     ../../modules/blocks/hardcodedsecret.nix
  #     ../../modules/services/vaultwarden.nix
  #     basic
  #     ldap
  #   ];
  #
  #   nodes.client = {};
  #
  #   testScript = commonTestScript.access;
  # };

  sso = pkgs.testers.runNixOSTest {
    name = "vaultwarden_sso";

    nodes.server = { config, ... }: {
      imports = [
        testLib.baseModule
        ../../modules/blocks/hardcodedsecret.nix
        ../../modules/services/vaultwarden.nix
        testLib.certs
        basic
        https
        testLib.ldap
        (testLib.sso config.shb.certs.certs.selfsigned.n)
        sso
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.access.override {
      waitForPorts = { node, ... }: [
        8222
        5432
        9091
      ];
      extraScript = { node, proto_fqdn, ... }: ''
      with subtest("unauthenticated access is not granted to /admin"):
          response = curl(client, """{"code":%{response_code},"auth_host":"%{urle.host}","auth_query":"%{urle.query}","all":%{json}}""", "${proto_fqdn}/admin")

          if response['code'] != 200:
              raise Exception(f"Code is {response['code']}")
          if response['auth_host'] != "auth.${node.config.test.domain}":
              raise Exception(f"auth host should be auth.${node.config.test.domain} but is {response['auth_host']}")
          if response['auth_query'] != "rd=${proto_fqdn}/admin":
              raise Exception(f"auth query should be rd=${proto_fqdn}/admin but is {response['auth_query']}")
      '';
    };
  };

  backup = pkgs.testers.runNixOSTest {
    name = "vaultwarden_backup";

    nodes.server = { config, ... }: {
      imports = [
        testLib.baseModule
        ../../modules/blocks/hardcodedsecret.nix
        ../../modules/services/vaultwarden.nix
        basic
        (testLib.backup config.shb.vaultwarden.backup)
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.backup;
  };
}
