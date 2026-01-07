{ pkgs, shb, ... }:
let
  pkgs' = pkgs;

  ldapAdminPassword = "ldapAdminPassword";
in
{
  basic = shb.test.runNixOSTest {
    name = "authelia-basic";

    nodes.machine =
      { config, pkgs, ... }:
      {
        imports = [
          (pkgs'.path + "/nixos/modules/profiles/headless.nix")
          (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
          ../../modules/blocks/authelia.nix
          ../../modules/blocks/hardcodedsecret.nix
        ];

        networking.hosts = {
          "127.0.0.1" = [
            "machine.com"
            "client1.machine.com"
            "client2.machine.com"
            "ldap.machine.com"
            "authelia.machine.com"
          ];
        };

        shb.lldap = {
          enable = true;
          dcdomain = "dc=example,dc=com";
          subdomain = "ldap";
          domain = "machine.com";
          ldapUserPassword.result = config.shb.hardcodedsecret.ldapUserPassword.result;
          jwtSecret.result = config.shb.hardcodedsecret.jwtSecret.result;
        };

        shb.hardcodedsecret.ldapUserPassword = {
          request = config.shb.lldap.ldapUserPassword.request;
          settings.content = ldapAdminPassword;
        };
        shb.hardcodedsecret.jwtSecret = {
          request = config.shb.lldap.jwtSecret.request;
          settings.content = "jwtsecret";
        };

        shb.authelia = {
          enable = true;
          subdomain = "authelia";
          domain = "machine.com";
          ldapHostname = "${config.shb.lldap.subdomain}.${config.shb.lldap.domain}";
          ldapPort = config.shb.lldap.ldapPort;
          dcdomain = config.shb.lldap.dcdomain;
          secrets = {
            jwtSecret.result = config.shb.hardcodedsecret.autheliaJwtSecret.result;
            ldapAdminPassword.result = config.shb.hardcodedsecret.ldapAdminPassword.result;
            sessionSecret.result = config.shb.hardcodedsecret.sessionSecret.result;
            storageEncryptionKey.result = config.shb.hardcodedsecret.storageEncryptionKey.result;
            identityProvidersOIDCHMACSecret.result =
              config.shb.hardcodedsecret.identityProvidersOIDCHMACSecret.result;
            identityProvidersOIDCIssuerPrivateKey.result =
              config.shb.hardcodedsecret.identityProvidersOIDCIssuerPrivateKey.result;
          };

          oidcClients = [
            {
              client_id = "client1";
              client_name = "My Client 1";
              client_secret.source = pkgs.writeText "secret" "$pbkdf2-sha512$310000$LR2wY11djfLrVQixdlLJew$rPByqFt6JfbIIAITxzAXckwh51QgV8E5YZmA8rXOzkMfBUcMq7cnOKEXF6MAFbjZaGf3J/B1OzLWZTCuZtALVw";
              public = false;
              authorization_policy = "one_factor";
              redirect_uris = [ "http://client1.machine.com/redirect" ];
            }
            {
              client_id = "client2";
              client_name = "My Client 2";
              client_secret.source = pkgs.writeText "secret" "$pbkdf2-sha512$310000$76EqVU1N9K.iTOvD4WJ6ww$hqNJU.UHphiCjMChSqk27lUTjDqreuMuyV/u39Esc6HyiRXp5Ecx89ypJ5M0xk3Na97vbgDpwz7il5uwzQ4bfw";
              public = false;
              authorization_policy = "one_factor";
              redirect_uris = [ "http://client2.machine.com/redirect" ];
            }
          ];
        };

        shb.hardcodedsecret.autheliaJwtSecret = {
          request = config.shb.authelia.secrets.jwtSecret.request;
          settings.content = "jwtSecret";
        };
        shb.hardcodedsecret.ldapAdminPassword = {
          request = config.shb.authelia.secrets.ldapAdminPassword.request;
          settings.content = ldapAdminPassword;
        };
        shb.hardcodedsecret.sessionSecret = {
          request = config.shb.authelia.secrets.sessionSecret.request;
          settings.content = "sessionSecret";
        };
        shb.hardcodedsecret.storageEncryptionKey = {
          request = config.shb.authelia.secrets.storageEncryptionKey.request;
          settings.content = "storageEncryptionKey";
        };
        shb.hardcodedsecret.identityProvidersOIDCHMACSecret = {
          request = config.shb.authelia.secrets.identityProvidersOIDCHMACSecret.request;
          settings.content = "identityProvidersOIDCHMACSecret";
        };
        shb.hardcodedsecret.identityProvidersOIDCIssuerPrivateKey = {
          request = config.shb.authelia.secrets.identityProvidersOIDCIssuerPrivateKey.request;
          settings.source =
            (pkgs.runCommand "gen-private-key" { } ''
              mkdir $out
              ${pkgs.openssl}/bin/openssl genrsa -out $out/private.pem 4096
            '')
            + "/private.pem";
        };

        specialisation = {
          withDebug.configuration = {
            shb.authelia.debug = true;
          };
        };
      };

    testScript =
      { nodes, ... }:
      let
        specializations = "${nodes.machine.system.build.toplevel}/specialisation";
      in
      ''
        import json

        start_all()

        def tests():
            machine.wait_for_unit("lldap.service")
            machine.wait_for_unit("authelia-authelia.machine.com.target")
            machine.wait_for_open_port(9091)

            endpoints = json.loads(machine.succeed("curl -s http://machine.com/.well-known/openid-configuration"))
            auth_endpoint = endpoints['authorization_endpoint']
            print(f"auth_endpoint: {auth_endpoint}")
            if auth_endpoint != "http://machine.com/api/oidc/authorization":
                raise Exception("Unexpected auth_endpoint")

            resp = machine.succeed(
                "curl -f -s '"
                + auth_endpoint
                + "?client_id=other"
                + "&redirect_uri=http://client1.machine.com/redirect"
                + "&scope=openid%20profile%20email"
                + "&response_type=code"
                + "&state=99999999'"
            )
            print(resp)
            if resp != "":
                raise Exception("unexpected response")

            resp = machine.succeed(
                "curl -f -s '"
                + auth_endpoint
                + "?client_id=client1"
                + "&redirect_uri=http://client1.machine.com/redirect"
                + "&scope=openid%20profile%20email"
                + "&response_type=code"
                + "&state=11111111'"
            )
            print(resp)
            if "Found" not in resp:
                raise Exception("unexpected response")

            resp = machine.succeed(
                "curl -f -s '"
                + auth_endpoint
                + "?client_id=client2"
                + "&redirect_uri=http://client2.machine.com/redirect"
                + "&scope=openid%20profile%20email"
                + "&response_type=code"
                + "&state=22222222'"
            )
            print(resp)
            if "Found" not in resp:
                raise Exception("unexpected response")

        with subtest("no debug"):
            tests()

        with subtest("with debug"):
            machine.succeed('${specializations}/withDebug/bin/switch-to-configuration test')
            tests()
      '';
  };
}
