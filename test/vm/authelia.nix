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
        domain = "example.com";
        ldapUserPasswordFile = pkgs.writeText "user_password" ldapAdminPassword;
        jwtSecretFile = pkgs.writeText "jwt_secret" "securejwtsecret";
      };

      shb.authelia = {
        enable = true;
        subdomain = "authelia";
        domain = "example.com";
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
            id = "myclient";
            description = "My Client";
            secretFile = pkgs.writeText "secret" "mysecuresecret";
            public = "false";
            authorization_policy = "one_factor";
            redirect_uris = [ "https://myclient.exapmle.com/redirect" ];
          }
        ];
      };
    };

    testScript = { nodes, ... }: ''
    start_all()
    machine.wait_for_unit("lldap.service")
    machine.wait_for_unit("authelia-authelia.example.com.service")

    '';
  };
}
