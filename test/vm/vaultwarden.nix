{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "v";
  domain = "example.com";

  commonTestScript = lib.makeOverridable testLib.accessScript {
    inherit subdomain domain;
    hasSSL = { node, ... }: !(isNull node.config.shb.vaultwarden.ssl);
    waitForServices = { ... }: [
      "vaultwarden.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      8222
      5432
    ];
  };

  base = testLib.base pkgs' [
    ../../modules/services/vaultwarden.nix
  ];

  basic = { config, ... }: {
    shb.vaultwarden = {
      enable = true;
      inherit subdomain domain;

      port = 8222;
      databasePasswordFile = pkgs.writeText "pwfile" "DBPASSWORDFILE";
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
  #   #   ldapEndpoint = "http://127.0.0.1:${builtins.toString config.shb.ldap.webUIListenPort}";
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
        base
        basic
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  https = pkgs.testers.runNixOSTest {
    name = "vaultwarden_https";

    nodes.server = {
      imports = [
        base
        (testLib.certs domain)
        basic
        https
      ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  # Not yet supported
  #
  # ldap = pkgs.testers.runNixOSTest {
  #   name = "vaultwarden_ldap";
  #
  #   nodes.server = lib.mkMerge [ 
  #     base
  #     basic
  #     ldap
  #   ];
  #
  #   nodes.client = {};
  #
  #   testScript = commonTestScript;
  # };

  sso = pkgs.testers.runNixOSTest {
    name = "vaultwarden_sso";

    nodes.server = { config, ... }: {
      imports = [
        base
        (testLib.certs domain)
        basic
        https
        (testLib.ldap domain pkgs')
        (testLib.sso domain pkgs' config.shb.certs.certs.selfsigned.n)
        sso
      ];
    };

    nodes.client = {};

    testScript = commonTestScript.override {
      extraScript = { proto_fqdn, ... }: ''
      with subtest("unauthenticated access is not granted to /admin"):
          response = curl(client, """{"code":%{response_code},"auth_host":"%{urle.host}","auth_query":"%{urle.query}","all":%{json}}""", "${proto_fqdn}/admin")

          if response['code'] != 200:
              raise Exception(f"Code is {response['code']}")
          if response['auth_host'] != "auth.${domain}":
              raise Exception(f"auth host should be auth.${domain} but is {response['auth_host']}")
          if response['auth_query'] != "rd=${proto_fqdn}/admin":
              raise Exception(f"auth query should be rd=${proto_fqdn}/admin but is {response['auth_query']}")
      '';
    };
  };
}
