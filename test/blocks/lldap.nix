{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  password = "securepassword";
  charliePassword = "CharliePassword";
in
{
  auth = lib.shb.runNixOSTest {
    name = "ldap-auth";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        (pkgs'.path + "/nixos/modules/profiles/headless.nix")
        (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
        {
          options = {
            shb.ssl.enable = lib.mkEnableOption "ssl";
          };
        }
        ../../modules/blocks/hardcodedsecret.nix
        ../../modules/blocks/lldap.nix
      ];

      shb.lldap = {
        enable = true;
        dcdomain = "dc=example,dc=com";
        subdomain = "ldap";
        domain = "example.com";
        ldapUserPassword.result = config.shb.hardcodedsecret.ldapUserPassword.result;
        jwtSecret.result = config.shb.hardcodedsecret.jwtSecret.result;

        ensureUsers = {
          "charlie" = {
            email = "charlie@example.com";
            password.result = config.shb.hardcodedsecret."charlie".result;
          };
        };

        ensureGroups = {
          "family" = {};
        };
      };
      shb.hardcodedsecret.ldapUserPassword = {
        request = config.shb.lldap.ldapUserPassword.request;
        settings.content = password;
      };
      shb.hardcodedsecret.jwtSecret = {
        request = config.shb.lldap.jwtSecret.request;
        settings.content = "jwtSecret";
      };
      shb.hardcodedsecret."charlie" = {
        request = config.shb.lldap.ensureUsers."charlie".password.request;
        settings.content = charliePassword;
      };

      networking.firewall.allowedTCPPorts = [ 80 ]; # nginx port

      environment.systemPackages = [ pkgs.openldap ];

      specialisation = {
        withDebug.configuration = {
          shb.lldap.debug = true;
        };
      };
    };

    nodes.client = {};

    # Inspired from https://github.com/lldap/lldap/blob/33f50d13a2e2d24a3e6bb05a148246bc98090df0/example_configs/lldap-ha-auth.sh
    testScript = { nodes, ... }:
    let
      specializations = "${nodes.server.system.build.toplevel}/specialisation";
    in
    ''
    import json

    start_all()

    def tests():
        server.wait_for_unit("lldap.service")
        server.wait_for_open_port(${toString nodes.server.shb.lldap.webUIListenPort})
        server.wait_for_open_port(${toString nodes.server.shb.lldap.ldapPort})

        with subtest("fail without authenticating"):
            client.fail(
                "curl -f -s -X GET"
                + """ -H "Content-type: application/json" """
                + """ -H "Host: ldap.example.com" """
                + " http://server/api/graphql"
            )

        with subtest("fail authenticating with wrong credentials"):
            resp = client.fail(
                "curl -f -s -X POST"
                + """ -H "Content-type: application/json" """
                + """ -H "Host: ldap.example.com" """
                + " http://server/auth/simple/login"
                + """ -d '{"username": "admin", "password": "wrong"}'"""
            )

            print(resp)

        with subtest("succeed with correct authentication"):
            token = json.loads(client.succeed(
                "curl -f -s -X POST "
                + """ -H "Content-type: application/json" """
                + """ -H "Host: ldap.example.com" """
                + " http://server/auth/simple/login "
                + """ -d '{"username": "admin", "password": "${password}"}' """
            ))['token']

            data = json.loads(client.succeed(
                "curl -f -s -X POST "
                + """ -H "Content-type: application/json" """
                + """ -H "Host: ldap.example.com" """
                + """ -H "Authorization: Bearer {token}" """.format(token=token)
                + " http://server/api/graphql "
                + """ -d '{"variables": {"id": "admin"}, "query":"query($id:String!){user(userId:$id){displayName groups{displayName}}}"}' """
            ))['data']

            assert data['user']['displayName'] == "Administrator"
            assert data['user']['groups'][0]['displayName'] == "lldap_admin"

        with subtest("succeed charlie"):
            resp = client.succeed(
                "curl -f -s -X POST "
                + """ -H "Content-type: application/json" """
                + """ -H "Host: ldap.example.com" """
                + " http://server/auth/simple/login "
                + """ -d '{"username": "charlie", "password": "${charliePassword}"}' """
            )
            print(resp)

        with subtest("ldap user search"):
            resp = server.succeed('ldapsearch -H ldap://127.0.0.1:${toString nodes.server.shb.lldap.ldapPort} -D uid=admin,ou=people,dc=example,dc=com -b "ou=people,dc=example,dc=com" -w ${password}')
            print(resp)

            if "uid=admin" not in resp:
                raise Exception("Expected to find admin")

            if "uid=charlie" not in resp:
                raise Exception("Expected to find charlie")

    with subtest("no debug"):
        tests()

    with subtest("with debug"):
        server.succeed('${specializations}/withDebug/bin/switch-to-configuration test')
        tests()
    '';
  };
}
