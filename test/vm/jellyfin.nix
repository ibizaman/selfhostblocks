{ pkgs, lib, ... }:
let
  # TODO: Test login
  commonTestScript = { nodes, ... }:
    let
      hasSSL = !(isNull nodes.server.shb.jellyfin.ssl);
      fqdn = if hasSSL then "https://j.example.com" else "http://j.example.com";
    in
    ''
    import json
    import os
    import pathlib

    start_all()
    server.wait_for_unit("jellyfin.service")
    server.wait_for_unit("nginx.service")
    server.wait_for_open_port(8096)

    if ${if hasSSL then "True" else "False"}:
        server.copy_from_vm("/etc/ssl/certs/ca-certificates.crt")
        client.succeed("rm -r /etc/ssl/certs")
        client.copy_from_host(str(pathlib.Path(os.environ.get("out", os.getcwd())) / "ca-certificates.crt"), "/etc/ssl/certs/ca-certificates.crt")

    def curl(target, format, endpoint, succeed=True):
        return json.loads(target.succeed(
            "curl --fail-with-body --silent --show-error --output /dev/null --location"
            + " --connect-to j.example.com:443:server:443"
            + " --connect-to j.example.com:80:server:80"
            + f" --write-out '{format}'"
            + " " + endpoint
        ))

    with subtest("access"):
        response = curl(client, """{"code":%{response_code}}""", "${fqdn}")

        if response['code'] != 200:
            raise Exception(f"Code is {response['code']}")
    '';
in
{
  basic = pkgs.nixosTest {
    name = "jellyfin-basic";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        {
          options = {
            shb.backup = lib.mkOption { type = lib.types.anything; };
            shb.authelia = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/services/jellyfin.nix
      ];

      shb.jellyfin = {
        enable = true;
        domain = "example.com";
        subdomain = "j";
      };
      # Nginx port.
      networking.firewall.allowedTCPPorts = [ 80 ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  ldap = pkgs.nixosTest {
    name = "jellyfin-ldap";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        {
          options = {
            shb.backup = lib.mkOption { type = lib.types.anything; };
            shb.authelia = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/blocks/ldap.nix
        ../../modules/services/jellyfin.nix
      ];

      shb.ldap = {
        enable = true;
        domain = "example.com";
        subdomain = "ldap";
        ldapPort = 3890;
        webUIListenPort = 17170;
        dcdomain = "dc=example,dc=com";
        ldapUserPasswordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
        jwtSecretFile = pkgs.writeText "jwtSecret" "jwtSecret";
      };

      shb.jellyfin = {
        enable = true;
        domain = "example.com";
        subdomain = "j";

        ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.ldap.ldapPort;
          dcdomain = config.shb.ldap.dcdomain;
          passwordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
        };
      };
      # Nginx port.
      networking.firewall.allowedTCPPorts = [ 80 ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  cert = pkgs.nixosTest {
    name = "jellyfin_cert";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        {
          options = {
            shb.backup = lib.mkOption { type = lib.types.anything; };
            shb.authelia = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/blocks/nginx.nix
        ../../modules/blocks/postgresql.nix
        ../../modules/blocks/ssl.nix
        ../../modules/services/jellyfin.nix
      ];

      shb.certs = {
        cas.selfsigned.myca = {
          name = "My CA";
        };
        certs.selfsigned = {
          n = {
            ca = config.shb.certs.cas.selfsigned.myca;
            domain = "*.example.com";
            group = "nginx";
          };
        };
      };

      systemd.services.nginx.after = [ config.shb.certs.certs.selfsigned.n.systemdService ];
      systemd.services.nginx.requires = [ config.shb.certs.certs.selfsigned.n.systemdService ];

      shb.jellyfin = {
        enable = true;
        domain = "example.com";
        subdomain = "j";
        ssl = config.shb.certs.certs.selfsigned.n;
      };
      # Nginx port.
      networking.firewall.allowedTCPPorts = [ 80 443 ];

      shb.nginx.accessLog = true;
    };

    nodes.client = {};

    testScript = commonTestScript;
  };

  sso = pkgs.nixosTest {
    name = "jellyfin_sso";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        {
          options = {
            shb.backup = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/blocks/authelia.nix
        ../../modules/blocks/ldap.nix
        ../../modules/blocks/postgresql.nix
        ../../modules/blocks/ssl.nix
        ../../modules/services/jellyfin.nix
      ];

      shb.ldap = {
        enable = true;
        domain = "example.com";
        subdomain = "ldap";
        ldapPort = 3890;
        webUIListenPort = 17170;
        dcdomain = "dc=example,dc=com";
        ldapUserPasswordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
        jwtSecretFile = pkgs.writeText "jwtSecret" "jwtSecret";
      };

      shb.certs = {
        cas.selfsigned.myca = {
          name = "My CA";
        };
        certs.selfsigned = {
          n = {
            ca = config.shb.certs.cas.selfsigned.myca;
            domain = "*.example.com";
            group = "nginx";
          };
        };
      };

      systemd.services.nginx.after = [ config.shb.certs.certs.selfsigned.n.systemdService ];
      systemd.services.nginx.requires = [ config.shb.certs.certs.selfsigned.n.systemdService ];

      shb.authelia = {
        enable = true;
        domain = "example.com";
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

      shb.jellyfin = {
        enable = true;
        domain = "example.com";
        subdomain = "j";
        ssl = config.shb.certs.certs.selfsigned.n;

        ldap = {
          enable = true;
          host = "127.0.0.1";
          port = config.shb.ldap.ldapPort;
          dcdomain = config.shb.ldap.dcdomain;
          passwordFile = pkgs.writeText "ldapUserPassword" "ldapUserPassword";
        };

        sso = {
          enable = true;
          endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
          secretFile = pkgs.writeText "ssoSecretFile" "ssoSecretFile";
        };
      };
      # Nginx port.
      networking.firewall.allowedTCPPorts = [ 80 443 ];
    };

    nodes.client = {};

    testScript = commonTestScript;
  };
}
