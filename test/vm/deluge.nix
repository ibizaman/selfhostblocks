{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  subdomain = "d";
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";

  testLib = pkgs.callPackage ../common.nix {};

  commonTestScript = testLib.accessScript {
    inherit fqdn;
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
    extraScript = { node, ... }: ''
    print(${node.name}.succeed('journalctl -n100 -u deluged'))
    print(${node.name}.succeed('systemctl status deluged'))
    print(${node.name}.succeed('systemctl status delugeweb'))
    '';
  };

  # TODO: Test login directly to deluge daemon to exercise extraUsers
  authTestScript = { nodes, ... }:
    let
      hasSSL = !(isNull nodes.server.shb.deluge.ssl);
      proto_fqdn = if hasSSL then "https://${fqdn}" else "http://${fqdn}";
      delugeCurlCfg = pkgs.writeText "curl.cfg" ''
      request = "POST"
      compressed
      cookie = "cookie_deluge.txt"
      cookie-jar = "cookie_deluge.txt"
      header = "Content-Type: application/json"
      header = "Accept: application/json"
      url = "${proto_fqdn}/json"
      write-out = "\n"
      '';
    in
    ''
    with subtest("web connect"):
        print(server.succeed("cat ${nodes.server.services.deluge.dataDir}/.config/deluge/auth"))

        response = json.loads(client.succeed(
            "curl --fail-with-body --show-error -K ${delugeCurlCfg}"
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + """ --data '{"method": "auth.login", "params": ["deluge"], "id": 1}'"""
        ))
        print(response)
        if not response['result']:
            raise Exception(f"result is {response['code']}")

        response = json.loads(client.succeed(
            "curl --fail-with-body --show-error -K ${delugeCurlCfg}"
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + """ --data '{"method": "web.get_hosts", "params": [], "id": 1}'"""
        ))
        print(response)

        hostID = response['result'][0][0]
        response = json.loads(client.succeed(
            "curl --fail-with-body --show-error -K ${delugeCurlCfg}"
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + f""" --data '{{"method": "web.connect", "params": ["{hostID}"], "id": 1}}'"""
        ))
        print(response)
        if response['error']:
            raise Exception(f"result had an error {response['error']}")
    '';

  prometheusTestScript = { nodes, ... }:
    let
      hasSSL = !(isNull nodes.server.shb.deluge.ssl);
      proto_fqdn = if hasSSL then "https://${fqdn}" else "http://${fqdn}";
    in
    ''
    server.wait_for_open_port(${toString nodes.server.services.prometheus.exporters.deluge.port})
    with subtest("prometheus"):
        response = server.succeed(
            "curl -sSf "
            + " http://localhost:${toString nodes.server.services.prometheus.exporters.deluge.port}/metrics"
        )
        print(response)
    '';

  base = {
    imports = [
      (pkgs'.path + "/nixos/modules/profiles/headless.nix")
      (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
      {
        options = {
          shb.backup = lib.mkOption { type = lib.types.anything; };
          shb.arr.radarr.enable = lib.mkEnableOption "radarr";
          shb.arr.sonarr.enable = lib.mkEnableOption "sonarr";
          shb.arr.bazarr.enable = lib.mkEnableOption "bazarr";
          shb.arr.readarr.enable = lib.mkEnableOption "readarr";
          shb.arr.lidarr.enable = lib.mkEnableOption "lidarr";
        };
      }
      ../../modules/blocks/nginx.nix
    ];

    # Nginx port.
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };

  certs = { config, ... }: {
    imports = [
      ../../modules/blocks/ssl.nix
    ];

    shb.certs = {
      cas.selfsigned.myca = {
        name = "My CA";
      };
      certs.selfsigned = {
        n = {
          ca = config.shb.certs.cas.selfsigned.myca;
          domain = "*.${domain}";
          group = "nginx";
        };
      };
    };

    systemd.services.nginx.after = [ config.shb.certs.certs.selfsigned.n.systemdService ];
    systemd.services.nginx.requires = [ config.shb.certs.certs.selfsigned.n.systemdService ];
  };

  basic = { config, ... }: {
    imports = [
      ../../modules/services/deluge.nix
    ];

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

  ldap = { config, ... }: {
    imports = [
      ../../modules/blocks/ldap.nix
    ];

    shb.ldap = {
      enable = true;
      inherit domain;
      subdomain = "ldap";
      ldapPort = 3890;
      webUIListenPort = 17170;
      dcdomain = "dc=example,dc=com";
      ldapUserPasswordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
      jwtSecretFile = pkgs.writeText "jwtSecret" "jwtSecret";
    };

    networking.hosts = {
      "127.0.0.1" = [ "${config.shb.ldap.subdomain}.${domain}" ];
    };
  };

  sso = { config, ... }: {
    imports = [
      ../../modules/blocks/authelia.nix
      ../../modules/blocks/postgresql.nix
    ];

    shb.authelia = {
      enable = true;
      inherit domain;
      subdomain = "auth";
      ssl = config.shb.certs.certs.selfsigned.n;

      ldapEndpoint = "ldap://127.0.0.1:${builtins.toString config.shb.ldap.ldapPort}";
      dcdomain = config.shb.ldap.dcdomain;

      secrets = {
        jwtSecretFile = pkgs.writeText "jwtSecret" "jwtSecret";
        ldapAdminPasswordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
        sessionSecretFile = pkgs.writeText "sessionSecret" "sessionSecret";
        storageEncryptionKeyFile = pkgs.writeText "storageEncryptionKey" "storageEncryptionKey";
        identityProvidersOIDCHMACSecretFile = pkgs.writeText "identityProvidersOIDCHMACSecret" "identityProvidersOIDCHMACSecret";
        identityProvidersOIDCIssuerPrivateKeyFile = (pkgs.runCommand "gen-private-key" {} ''
          mkdir $out
          ${pkgs.openssl}/bin/openssl genrsa -out $out/private.pem 4096
        '') + "/private.pem";
      };
    };

    networking.hosts = {
      "127.0.0.1" = [ "${config.shb.authelia.subdomain}.${domain}" ];
    };

    shb.deluge = {
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "deluge_basic";

    nodes.server = lib.mkMerge [
      base
      basic
      {
        options = {
          shb.authelia = lib.mkOption { type = lib.types.anything; };
        };
      }
    ];

    nodes.client = {};

    testScript = inputs:
      (commonTestScript inputs)
      + (authTestScript inputs);
  };

  https = pkgs.testers.runNixOSTest {
    name = "deluge_https";

    nodes.server = lib.mkMerge [
      base
      certs
      basic
      https
      {
        options = {
          shb.authelia = lib.mkOption { type = lib.types.anything; };
        };
      }
    ];

    nodes.client = {};

    testScript = inputs:
      (commonTestScript inputs)
      + (authTestScript inputs);
  };

  # TODO: make this work, needs to authenticate to Authelia
  #
  # sso = pkgs.testers.runNixOSTest {
  #   name = "deluge_sso";
  #
  #   nodes.server = lib.mkMerge [ 
  #     base
  #     basic
  #     certs
  #     https
  #     ldap
  #     sso
  #   ];
  #
  #   nodes.client = {};
  #
  #   testScript = commonTestScript;
  # };

  prometheus = pkgs.testers.runNixOSTest {
    name = "deluge_https";

    nodes.server = lib.mkMerge [
      base
      certs
      basic
      https
      prometheus
      {
        options = {
          shb.authelia = lib.mkOption { type = lib.types.anything; };
        };
      }
    ];

    nodes.client = {};

    testScript = inputs:
      (commonTestScript inputs)
      + (prometheusTestScript inputs);
  };
}
