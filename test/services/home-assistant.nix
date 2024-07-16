{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  testLib = pkgs.callPackage ../common.nix {};

  subdomain = "ha";
  domain = "example.com";

  commonTestScript = lib.makeOverridable testLib.accessScript {
    inherit subdomain domain;
    hasSSL = { node, ... }: !(isNull node.config.shb.home-assistant.ssl);
    waitForServices = { ... }: [
      "home-assistant.service"
      "nginx.service"
    ];
    waitForPorts = { node, ... }: [
      8123
    ];
  };

  base = testLib.base pkgs' [
    ../../modules/services/home-assistant.nix
  ];

  basic = { config, ... }: {
    shb.home-assistant = {
      enable = true;
      inherit subdomain domain;

      config = {
        name = "Tiserbox";
        country = "My Country";
        latitude = "01.0000000000";
        longitude.source = pkgs.writeText "longitude" "01.0000000000";
        time_zone = "America/Los_Angeles";
        unit_system = "metric";
      };
    };
  };

  https = { config, ...}: {
    shb.home-assistant = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  ldap = { config, ... }: {
    shb.home-assistant = {
      ldap = {
        enable = true;
        host = "127.0.0.1";
        port = config.shb.ldap.webUIListenPort;
        userGroup = "homeassistant_user";
      };
    };
  };

  # Not yet supported
  #
  # sso = { config, ... }: {
  #   shb.home-assistant = {
  #     sso = {
  #     };
  #   };
  # };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "homeassistant_basic";

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
    name = "homeassistant_https";

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

  ldap = pkgs.testers.runNixOSTest {
    name = "homeassistant_ldap";
  
    nodes.server = {
      imports = [ 
        base
        basic
        (testLib.ldap domain pkgs')
        ldap
      ];
    };
  
    nodes.client = {};
  
    testScript = commonTestScript;
  };

  # Not yet supported
  #
  # sso = pkgs.testers.runNixOSTest {
  #   name = "vaultwarden_sso";
  #
  #   nodes.server = lib.mkMerge [ 
  #     base
  #     (testLib.certs domain)
  #     basic
  #     https
  #     ldap
  #     (testLib.ldap domain pkgs')
  #     (testLib.sso domain pkgs' config.shb.certs.certs.selfsigned.n)
  #     sso
  #   ];
  #
  #   nodes.client = {};
  #
  #   testScript = commonTestScript;
  # };
}
