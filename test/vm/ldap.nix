{ pkgs, lib, ... }:
let
  pkgs' = pkgs;
in
{
  auth = pkgs.testers.runNixOSTest {
    name = "ldap-auth";

    nodes.server = { config, pkgs, ... }: {
      imports = [
        (pkgs'.path + "/nixos/modules/profiles/headless.nix")
        (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
        {
          options = {
            shb.ssl.enable = lib.mkEnableOption "ssl";
            shb.backup = lib.mkOption { type = lib.types.anything; };
          };
        }
        ../../modules/blocks/ldap.nix
      ];

      shb.ldap = {
        enable = true;
        dcdomain = "dc=example,dc=com";
        subdomain = "ldap";
        domain = "example.com";
        ldapUserPasswordFile = pkgs.writeText "user_password" "securepw";
        jwtSecretFile = pkgs.writeText "jwt_secret" "securejwtsecret";
        debug = true;

        # groups = {
        #   "test-group" = {};
        # };
        # users = {
        #   "42" = {
        #     email = "my@test.com";
        #     displayName = "My Test";
        #     firstName = "My";
        #     lastName = "My";
        #     groups = [ "test-group" ];
        #     passwordFile = pkgs.writeText "userpw" "userpw78";
        #   };
        # };
      };
      networking.firewall.allowedTCPPorts = [ 80 ]; # nginx port
    };

    nodes.client = {};

    # Inspired from https://github.com/lldap/lldap/blob/33f50d13a2e2d24a3e6bb05a148246bc98090df0/example_configs/lldap-ha-auth.sh
    testScript = { nodes, ... }: ''
    import json

    start_all()
    server.wait_for_unit("lldap.service")
    server.wait_for_open_port(${toString nodes.server.services.lldap.settings.http_port})

    with subtest("fail without authenticating"):
        client.fail(
            "curl -f -s -X GET"
            + """ -H "Content-type: application/json" """
            + """ -H "Host: ldap.example.com" """
            + " http://server/api/graphql"
        )

    with subtest("fail authenticating with wrong credentials"):
        client.fail(
            "curl -f -s -X POST"
            + """ -H "Content-type: application/json" """
            + """ -H "Host: ldap.example.com" """
            + " http://server/auth/simple/login"
            + """ -d '{"username": "admin", "password": "wrong"}'"""
        )

    with subtest("succeed with correct authentication"):
        token = json.loads(client.succeed(
            "curl -f -s -X POST "
            + """ -H "Content-type: application/json" """
            + """ -H "Host: ldap.example.com" """
            + " http://server/auth/simple/login "
            + """ -d '{"username": "admin", "password": "securepw"}' """
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

    # with subtest("check user exists"):
    #     ids = server.succeed("lldap-cli user list uid").splitlines()
    #     print(ids)
    #     if "42" not in ids:
    #         raise Exception("Did not find user for email my@test.com")

    #     groups = server.succeed("lldap-cli user group list 42").splitlines()
    #     print(groups)
    #     if "test-group" not in groups:
    #         raise Exception("Did not find group for email my@test.com")

    # with subtest("service updates attributes"):
    #     server.succeed("lldap-cli user update set 42 mail other@test.com")

    #     emails = server.succeed("lldap-cli user list email").splitlines()
    #     print("after update", emails)
    #     if "my@test.com" in emails:
    #         raise Exception("Did not find user for email other@test.com")

    #     server.succeed("systemctl restart lldap")

    #     emails = server.succeed("lldap-cli user list email").splitlines()
    #     print("after restart", emails)
    #     if "my@test.com" not in emails:
    #         raise Exception("Did not find user for email my@test.com")

    # print(server.succeed("systemctl cat lldap | grep Post"))
    '';
  };
}
