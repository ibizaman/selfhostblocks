{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  subdomain = "d";
  domain = "example.com";

  testLib = pkgs.callPackage ../common.nix {};

  commonTestScript = lib.makeOverridable testLib.accessScript {
    inherit subdomain domain;
    hasSSL = { node, ... }: !(isNull node.config.shb.deluge.ssl);
    waitForServices = { ... }: [
      "nginx.service"
      "deluged.service"
      "delugeweb.service"
    ];
    waitForPorts = { node, ... }: [
      node.config.shb.deluge.daemonPort
      node.config.shb.deluge.webPort
    ];
    extraScript = { node, proto_fqdn, ... }: ''
    print(${node.name}.succeed('journalctl -n100 -u deluged'))
    print(${node.name}.succeed('systemctl status deluged'))
    print(${node.name}.succeed('systemctl status delugeweb'))

    with subtest("web connect"):
        print(server.succeed("cat ${node.config.services.deluge.dataDir}/.config/deluge/auth"))

        response = curl(client, "", "${proto_fqdn}/json", extra = unline_with(" ", """
          -H "Content-Type: application/json"
          -H "Accept: application/json"
          """), data = unline_with(" ", """
          {"method": "auth.login", "params": ["deluge"], "id": 1}
          """))
        print(response)
        if response['error']:
            raise Exception(f"error is {response['error']}")
        if not response['result']:
            raise Exception(f"response is {response}")

        response = curl(client, "", "${proto_fqdn}/json", extra = unline_with(" ", """
          -H "Content-Type: application/json"
          -H "Accept: application/json"
          """), data = unline_with(" ", """
          {"method": "web.get_hosts", "params": [], "id": 1}
          """))
        print(response)
        if response['error']:
            raise Exception(f"error is {response['error']}")

        hostID = response['result'][0][0]
        response = curl(client, "", "${proto_fqdn}/json", extra = unline_with(" ", """
          -H "Content-Type: application/json"
          -H "Accept: application/json"
          """), data = unline_with(" ", f"""
          {{"method": "web.connect", "params": ["{hostID}"], "id": 1}}
          """))
        print(response)
        if response['error']:
            raise Exception(f"result had an error {response['error']}")
    '';
  };

  prometheusTestScript = { nodes, ... }:
    ''
    server.wait_for_open_port(${toString nodes.server.services.prometheus.exporters.deluge.port})
    with subtest("prometheus"):
        response = server.succeed(
            "curl -sSf "
            + " http://localhost:${toString nodes.server.services.prometheus.exporters.deluge.port}/metrics"
        )
        print(response)
    '';

  base = testLib.base pkgs' [
    ../../modules/services/deluge.nix
  ];

  basic = { config, ... }: {
    shb.deluge = {
      enable = true;
      inherit domain subdomain;

      settings = {
        downloadLocation = "/var/lib/deluge";
      };

      extraUsers = {
        user.password.source = pkgs.writeText "userpw" "userpw";
      };

      localclientPasswordFile = pkgs.writeText "localclientpw" "localclientpw";
    };
  };

  prometheus = {
    shb.deluge = {
      prometheusScraperPasswordFile = pkgs.writeText "prompw" "prompw";
    };
  };

  https = { config, ...}: {
    shb.deluge = {
      ssl = config.shb.certs.certs.selfsigned.n;
    };
  };

  sso = { config, ... }: {
    shb.deluge = {
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "deluge_basic";

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
    name = "deluge_https";

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

  sso = pkgs.testers.runNixOSTest {
    name = "deluge_sso";
  
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
      redirectSSO = true;
    };
  };

  prometheus = pkgs.testers.runNixOSTest {
    name = "deluge_https";

    nodes.server = {
      imports = [
        base
        (testLib.certs domain)
        basic
        https
        prometheus
      ];
    };

    nodes.client = {};

    testScript = inputs:
      (commonTestScript inputs)
      + (prometheusTestScript inputs);
  };
}
