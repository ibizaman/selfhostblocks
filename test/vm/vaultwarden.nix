{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  subdomain = "v";
  domain = "example.com";
  fqdn = "${subdomain}.${domain}";

  # TODO: Test login
  commonTestScript = { nodes, ... }:
    let
      hasSSL = !(isNull nodes.server.shb.vaultwarden.ssl);
      proto_fqdn = if hasSSL then "https://${fqdn}" else "http://${fqdn}";
    in
    ''
    import json
    import os
    import pathlib

    start_all()
    server.wait_for_unit("vaultwarden.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_open_port(8222)
    server.wait_for_open_port(5432)

    if ${if hasSSL then "True" else "False"}:
        server.copy_from_vm("/etc/ssl/certs/ca-certificates.crt")
        client.succeed("rm -r /etc/ssl/certs")
        client.copy_from_host(str(pathlib.Path(os.environ.get("out", os.getcwd())) / "ca-certificates.crt"), "/etc/ssl/certs/ca-certificates.crt")

    def curl(target, format, endpoint, succeed=True):
        return json.loads(target.succeed(
            "curl --fail-with-body --silent --show-error --output /dev/null --location"
            + " --connect-to ${fqdn}:443:server:443"
            + " --connect-to ${fqdn}:80:server:80"
            + f" --write-out '{format}'"
            + " " + endpoint
        ))

    with subtest("access"):
        response = curl(client, """{"code":%{response_code}}""", "${proto_fqdn}")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")
    '';

  base = { config, ... }: {
    imports = [
      (pkgs'.path + "/nixos/modules/profiles/headless.nix")
      (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
      {
        options = {
          shb.backup = lib.mkOption { type = lib.types.anything; };
        };
      }
      ../../modules/blocks/nginx.nix
      ../../modules/blocks/postgresql.nix
      ../../modules/blocks/ssl.nix
      ../../modules/services/vaultwarden.nix
    ];

    # Nginx port.
    networking.firewall.allowedTCPPorts = [ 80 443 ];

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
    shb.vaultwarden = {
      enable = true;
      inherit subdomain domain;
      ssl = config.shb.certs.certs.selfsigned.n;
      port = 8222;
      databasePasswordFile = pkgs.writeText "pwfile" "DBPASSWORDFILE";
    };

    networking.hosts = {
      "127.0.0.1" = [ fqdn ];
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

    # Not yet supported
    # shb.vaultwarden = {
    #   ldapEndpoint = "http://127.0.0.1:${builtins.toString config.shb.ldap.webUIListenPort}";
    # };
  };

  sso = { config, ... }: {
    imports = [
      ../../modules/blocks/authelia.nix
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

    shb.vaultwarden = {
      authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };
  };
in
{
  basic = pkgs.testers.runNixOSTest {
    name = "vaultwarden_basic";

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

    nodes.server = lib.mkMerge [ 
      base
      basic
      ldap
      sso
    ];

    nodes.client = {};

    testScript = commonTestScript;
  };
}
