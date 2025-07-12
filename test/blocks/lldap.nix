{ pkgs, lib, ... }:
let
  pkgs' = pkgs;

  password = "securepassword";
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
        debug = true;
      };
      shb.hardcodedsecret.ldapUserPassword = {
        request = config.shb.lldap.ldapUserPassword.request;
        settings.content = password;
      };
      shb.hardcodedsecret.jwtSecret = {
        request = config.shb.lldap.jwtSecret.request;
        settings.content = "jwtSecret";
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
    '';
  };
}
