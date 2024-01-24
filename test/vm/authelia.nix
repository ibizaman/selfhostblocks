{ pkgs, lib, ... }:
let
  ldapAdminPassword = "ldapAdminPassword";
in
{
  basic = pkgs.nixosTest {
    name = "authelia-basic";

    nodes.machine = { config, pkgs, ... }: {
      imports = [
        {
          options = {
            shb.ssl.enable = lib.mkEnableOption "ssl";
            shb.backup = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/blocks/authelia.nix
        ../../modules/blocks/ldap.nix
        ../../modules/blocks/postgresql.nix
      ];

      shb.ldap = {
        enable = true;
        dcdomain = "dc=example,dc=com";
        subdomain = "ldap";
        domain = "machine";
        ldapUserPasswordFile = pkgs.writeText "user_password" ldapAdminPassword;
        jwtSecretFile = pkgs.writeText "jwt_secret" "securejwtsecret";
      };

      shb.authelia = {
        enable = true;
        subdomain = "authelia";
        domain = "machine";
        ldapEndpoint = "ldap://127.0.0.1:${builtins.toString config.shb.ldap.ldapPort}";
        dcdomain = config.shb.ldap.dcdomain;
        secrets = {
          jwtSecretFile = pkgs.writeText "jwtSecretFile" "jwtSecretFile";
          ldapAdminPasswordFile = pkgs.writeText "ldapAdminPasswordFile" ldapAdminPassword;
          sessionSecretFile = pkgs.writeText "sessionSecretFile" "sessionSecretFile";
          storageEncryptionKeyFile = pkgs.writeText "storageEncryptionKeyFile" "storageEncryptionKeyFile";
          identityProvidersOIDCHMACSecretFile = pkgs.writeText "identityProvidersOIDCHMACSecretFile" "identityProvidersOIDCHMACSecretFile";
          # This needs to be of the correct shape and at least 2048 bits. Generated with:
          #   nix run nixpkgs#openssl -- genrsa -out keypair.pem 2048
          identityProvidersOIDCIssuerPrivateKeyFile = pkgs.writeText "identityProvidersOIDCIssuerPrivateKeyFile" (builtins.readFile ./keypair.pem);
        };

        oidcClients = [
          {
            id = "client1";
            description = "My Client 1";
            secretFile = pkgs.writeText "secret" "mysecuresecret";
            public = false;
            authorization_policy = "one_factor";
            redirect_uris = [ "http://client1.machine/redirect" ];
          }
          {
            id = "client2";
            description = "My Client 2";
            secretFile = pkgs.writeText "secret" "myothersecret";
            public = false;
            authorization_policy = "one_factor";
            redirect_uris = [ "http://client2.machine/redirect" ];
          }
        ];
      };
    };

    testScript = { nodes, ... }: ''
    import json

    start_all()
    machine.wait_for_unit("lldap.service")
    machine.wait_for_unit("authelia-authelia.machine.service")
    machine.wait_for_open_port(${toString nodes.machine.services.authelia.instances."authelia.machine".settings.server.port})

    endpoints = json.loads(machine.succeed("curl -s http://machine/.well-known/openid-configuration"))
    auth_endpoint = endpoints['authorization_endpoint']

    machine.succeed(
        "curl -f -s '"
        + auth_endpoint
        + "?client_id=other"
        + "&redirect_uri=http://client1.machine/redirect"
        + "&scope=openid%20profile%20email"
        + "&response_type=code"
        + "&state=99999999'"
    )

    machine.succeed(
        "curl -f -s '"
        + auth_endpoint
        + "?client_id=client1"
        + "&redirect_uri=http://client1.machine/redirect"
        + "&scope=openid%20profile%20email"
        + "&response_type=code"
        + "&state=11111111'"
    )

    machine.succeed(
        "curl -f -s '"
        + auth_endpoint
        + "?client_id=client2"
        + "&redirect_uri=http://client2.machine/redirect"
        + "&scope=openid%20profile%20email"
        + "&response_type=code"
        + "&state=22222222'"
    )
    '';
  };
}
