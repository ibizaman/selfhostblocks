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
        ../../modules/blocks/ldap.nix
      ];

      shb.ldap = {
        enable = true;
        dcdomain = "dc=example,dc=com";
        subdomain = "ldap";
        domain = "example.com";
        ldapUserPassword.result = config.shb.hardcodedsecret.ldapUserPassword.result;
        jwtSecret.result = config.shb.hardcodedsecret.jwtSecret.result;
        deleteUnmanagedUsers = true;
        debug = false; # Really verbose.
      };
      shb.hardcodedsecret.ldapUserPassword = {
        request = config.shb.ldap.ldapUserPassword.request;
        settings.content = password;
      };
      shb.hardcodedsecret.jwtSecret = {
        request = config.shb.ldap.jwtSecret.request;
        settings.content = "jwtSecret";
      };

      specialisation.withGroupA.configuration = {
        shb.ldap = {
          groups."groupA" = {};
        };
      };
      specialisation.withUserA.configuration = {
        shb.ldap = {
          groups."groupA" = {};
          users = {
            "user_a" = {
              email = "userA@test.com";
              displayName = "UserA";
              firstName = "User";
              lastName = "A";
              groups = [ "groupA" ];
              password.result = config.specialisation.withUserA.configuration.shb.hardcodedsecret.user_a.result;
            };
          };
        };
        shb.hardcodedsecret.user_a = {
          request = config.specialisation.withUserA.configuration.shb.ldap.users."user_a".password.request;
          settings.content = "userpasswordA"; # must be longer than 8 characters.
        };
      };
      specialisation.withOtherGroup.configuration = {
        shb.ldap = {
          groups."groupB" = {};
          groups."groupC" = {};
          users = {
            "user_a" = {
              email = "userA@test.com";
              displayName = "UserA";
              firstName = "User";
              lastName = "A";
              groups = [ "groupB" "groupC" ];
              password.result = config.specialisation.withUserA.configuration.shb.hardcodedsecret.user_a.result;
            };
          };
        };
        shb.hardcodedsecret.user_a = {
          request = config.specialisation.withUserA.configuration.shb.ldap.users."user_a".password.request;
          settings.content = "userpasswordA"; # must be longer than 8 characters.
        };
      };
      specialisation.removeFromGroup.configuration = {
        shb.ldap = {
          groups."groupB" = {};
          groups."groupC" = {};
          users = {
            "user_a" = {
              email = "userA@test.com";
              displayName = "UserA";
              firstName = "User";
              lastName = "A";
              groups = [ "groupB" ];
              password.result = config.specialisation.withUserA.configuration.shb.hardcodedsecret.user_a.result;
            };
          };
        };
        shb.hardcodedsecret.user_a = {
          request = config.specialisation.withUserA.configuration.shb.ldap.users."user_a".password.request;
          settings.content = "userpasswordA"; # must be longer than 8 characters.
        };
      };
      specialisation.changeAttributes.configuration = {
        shb.ldap = {
          groups."groupB" = {};
          users = {
            "user_a" = {
              email = "userA_2@test.com";
              displayName = "UserA_2";
              firstName = "User_2";
              lastName = "A_2";
              groups = [ "groupB" ];
              password.result = config.specialisation.withUserA.configuration.shb.hardcodedsecret.user_a.result;
            };
          };
        };
        shb.hardcodedsecret.user_a = {
          request = config.specialisation.withUserA.configuration.shb.ldap.users."user_a".password.request;
          settings.content = "userpasswordA_2"; # must be longer than 8 characters.
        };
      };
      specialisation.noChangeAttributes.configuration = {
        shb.ldap = {
          groups."groupB" = {};
          users = {
            "user_a" = {
              initialEmail = "userA_3@test.com";
              initialDisplayName = "UserA_3";
              initialFirstName = "User_3";
              initialLastName = "A_3";
              groups = [ "groupB" ];
              initialPassword.result = config.specialisation.withUserA.configuration.shb.hardcodedsecret.user_a.result;
            };
          };
        };
        shb.hardcodedsecret.user_a = {
          request = config.specialisation.withUserA.configuration.shb.ldap.users."user_a".password.request;
          settings.content = "userpasswordA_3"; # must be longer than 8 characters.
        };
      };
      specialisation.leaveUnmanagedUser.configuration = {
        shb.ldap = {
          deleteUnmanagedUsers = lib.mkForce false;
          groups."groupA" = {};
          users = {};
        };
      };

      networking.firewall.allowedTCPPorts = [ 80 ]; # nginx port
    };

    nodes.client = {};

    # Inspired from https://github.com/lldap/lldap/blob/33f50d13a2e2d24a3e6bb05a148246bc98090df0/example_configs/lldap-ha-auth.sh
    testScript = { nodes, ... }: let
      withGroupA = "${nodes.server.system.build.toplevel}/specialisation/withGroupA";
      withUserA = "${nodes.server.system.build.toplevel}/specialisation/withUserA";
      withOtherGroup = "${nodes.server.system.build.toplevel}/specialisation/withOtherGroup";
      removeFromGroup = "${nodes.server.system.build.toplevel}/specialisation/removeFromGroup";
      changeAttributes = "${nodes.server.system.build.toplevel}/specialisation/changeAttributes";
      noChangeAttributes = "${nodes.server.system.build.toplevel}/specialisation/noChangeAttributes";
      leaveUnmanagedUser = "${nodes.server.system.build.toplevel}/specialisation/leaveUnmanagedUser";
    in ''
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
            + f""" -H "Authorization: Bearer {token}" """
            + " http://server/api/graphql "
            + """ -d '{"variables": {"id": "admin"}, "query":"query($id:String!){user(userId:$id){displayName groups{displayName}}}"}' """
        ))['data']

        assert data['user']['displayName'] == "Administrator"
        assert data['user']['groups'][0]['displayName'] == "lldap_admin"

        data = json.loads(client.succeed(
            "curl -f -s -X POST "
            + """ -H "Content-type: application/json" """
            + """ -H "Host: ldap.example.com" """
            + f""" -H "Authorization: Bearer {token}" """
            + " http://server/api/graphql "
            + """ -d '{"variables": {"id": "user_a"}, "query":"query($id:String!){user(userId:$id){displayName groups{displayName}}}"}' """
        ))['data']



    print(server.succeed("cat /run/current-system/sw/bin/lldap-cli"))

    with subtest("Add groupA"):
        groups = [x["displayName"] for x in json.loads(server.succeed("lldap-cli group list"))]
        print("GROUPS=", groups)
        if "groupA" in groups:
            raise Exception("Shouldn't have found groupA yet.")

        server.succeed(
            "${withGroupA}/bin/switch-to-configuration test >&2"
        )

        groups = [x["displayName"] for x in json.loads(server.succeed("lldap-cli group list"))]
        print("GROUPS=", groups)
        if "groupA" not in groups:
            raise Exception("Should have found groupA.")

    with subtest("Add user_a"):
        users = [x["id"] for x in json.loads(server.succeed("lldap-cli user list all"))]
        print("USERS=", users)
        if "user_a" in users:
            raise Exception("Shouldn't have found user_a yet.")

        server.succeed(
            "${withUserA}/bin/switch-to-configuration test >&2"
        )

        users = [x["id"] for x in json.loads(server.succeed("lldap-cli user list all"))]
        print("USERS=", users)
        if "user_a" not in users:
            raise Exception("Should have found user_a.")

        groups = server.succeed("lldap-cli user group list user_a").splitlines()
        if "groupA" not in groups:
            raise Exception("Should have found groupA.")

    with subtest("auth with user_a"):
        token = json.loads(client.succeed(
            "curl -f -s -X POST "
            + """ -H "Content-type: application/json" """
            + """ -H "Host: ldap.example.com" """
            + " http://server/auth/simple/login "
            + """ -d '{"username": "user_a", "password": "userpasswordA"}' """
        ))['token']

        data = json.loads(client.succeed(
            "curl -f -s -X POST "
            + """ -H "Content-type: application/json" """
            + """ -H "Host: ldap.example.com" """
            + f""" -H "Authorization: Bearer {token}" """
            + " http://server/api/graphql "
            + """ -d '{"variables": {"id": "user_a"}, "query":"query($id:String!){user(userId:$id){displayName groups{displayName}}}"}' """
        ))['data']

        if data['user']['displayName'] != "UserA":
            raise Exception("DisplayName is not UserA, got:", data['user']['displayName'])

    with subtest("With other group"):
        server.succeed(
            "${withOtherGroup}/bin/switch-to-configuration test >&2"
        )

        groups = [x["displayName"] for x in json.loads(server.succeed("lldap-cli group list"))]
        print("GROUPS=", groups)
        if "groupA" in groups:
            raise Exception("Should not have found groupA.")
        if "groupB" not in groups:
            raise Exception("Should have found groupB.")
        if "groupC" not in groups:
            raise Exception("Should have found groupC.")

        groups = server.succeed("lldap-cli user group list user_a").splitlines()
        if "groupA" in groups:
            raise Exception("Should not have found groupA.")
        if "groupB" not in groups:
            raise Exception("Should have found groupB.")
        if "groupC" not in groups:
            raise Exception("Should have found groupC.")

    with subtest("Remove from group"):
        server.succeed(
            "${removeFromGroup}/bin/switch-to-configuration test >&2"
        )

        groups = [x["displayName"] for x in json.loads(server.succeed("lldap-cli group list"))]
        print("GROUPS=", groups)
        if "groupA" in groups:
            raise Exception("Should not have found groupA.")
        if "groupB" not in groups:
            raise Exception("Should have found groupB.")
        if "groupC" not in groups:
            raise Exception("Should have found groupC.")

        groups = server.succeed("lldap-cli user group list user_a").splitlines()
        if "groupA" in groups:
            raise Exception("Should not have found groupA.")
        if "groupB" not in groups:
            raise Exception("Should have found groupB.")
        if "groupC" in groups:
            raise Exception("Should not have found groupC.")

    with subtest("change attributes"):
        server.succeed(
            "${changeAttributes}/bin/switch-to-configuration test >&2"
        )

        token = json.loads(client.succeed(
            "curl -f -s -X POST "
            + """ -H "Content-type: application/json" """
            + """ -H "Host: ldap.example.com" """
            + " http://server/auth/simple/login "
            + """ -d '{"username": "user_a", "password": "userpasswordA_2"}' """
        ))['token']

        data = json.loads(client.succeed(
            "curl -f -s -X POST "
            + """ -H "Content-type: application/json" """
            + """ -H "Host: ldap.example.com" """
            + f""" -H "Authorization: Bearer {token}" """
            + " http://server/api/graphql "
            + """ -d '{"variables": {"id": "user_a"}, "query":"query($id:String!){user(userId:$id){email displayName firstName lastName}}"}' """
        ))['data']

        if data['user']['email'] != "userA_2@test.com":
            raise Exception("email is not userA_2@test.com_2, got:", data['user']['email'])

        if data['user']['displayName'] != "UserA_2":
            raise Exception("displayName is not UserA_2, got:", data['user']['displayName'])

        if data['user']['firstName'] != "User_2":
            raise Exception("firstName is not User_2_2, got:", data['user']['firstName'])

        if data['user']['lastName'] != "A_2":
            raise Exception("lastName is not A_2, got:", data['user']['lastName'])

    with subtest("do not change attributes"):
        server.succeed(
            "${noChangeAttributes}/bin/switch-to-configuration test >&2"
        )

        token = json.loads(client.succeed(
            "curl -f -s -X POST "
            + """ -H "Content-type: application/json" """
            + """ -H "Host: ldap.example.com" """
            + " http://server/auth/simple/login "
            + """ -d '{"username": "user_a", "password": "userpasswordA_2"}' """
        ))['token']

        data = json.loads(client.succeed(
            "curl -f -s -X POST "
            + """ -H "Content-type: application/json" """
            + """ -H "Host: ldap.example.com" """
            + f""" -H "Authorization: Bearer {token}" """
            + " http://server/api/graphql "
            + """ -d '{"variables": {"id": "user_a"}, "query":"query($id:String!){user(userId:$id){email displayName firstName lastName}}"}' """
        ))['data']

        if data['user']['email'] != "userA_2@test.com":
            raise Exception("email is not userA_2@test.com_2, got:", data['user']['email'])

        if data['user']['displayName'] != "UserA_2":
            raise Exception("displayName is not UserA_2, got:", data['user']['displayName'])

        if data['user']['firstName'] != "User_2":
            raise Exception("firstName is not User_2_2, got:", data['user']['firstName'])

        if data['user']['lastName'] != "A_2":
            raise Exception("lastName is not A_2, got:", data['user']['lastName'])

    with subtest("Delete user"):
        server.succeed(
            "${withGroupA}/bin/switch-to-configuration test >&2"
        )

        users = [x["id"] for x in json.loads(server.succeed("lldap-cli user list all"))]
        print("USERS=", users)
        if "user_a" in users:
            raise Exception("Should not have found user_a.")

    with subtest("Add again user_a"):
        server.succeed(
            "${withUserA}/bin/switch-to-configuration test >&2"
        )

        users = [x["id"] for x in json.loads(server.succeed("lldap-cli user list all"))]
        print("USERS=", users)
        if "user_a" not in users:
            raise Exception("Should have found user_a.")

        server.succeed(
            "${leaveUnmanagedUser}/bin/switch-to-configuration test >&2"
        )

        users = [x["id"] for x in json.loads(server.succeed("lldap-cli user list all"))]
        print("USERS=", users)
        if "user_a" not in users:
            raise Exception("Should have found user_a.")
    '';
  };
}
