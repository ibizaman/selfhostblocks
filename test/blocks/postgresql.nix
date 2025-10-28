{ pkgs, lib, ... }:
let
  pkgs' = pkgs;
in
{
  peerWithoutUser = lib.shb.runNixOSTest {
    name = "postgresql-peerWithoutUser";

    nodes.machine =
      { config, pkgs, ... }:
      {
        imports = [
          (pkgs'.path + "/nixos/modules/profiles/headless.nix")
          (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
          ../../modules/blocks/postgresql.nix
        ];

        shb.postgresql.ensures = [
          {
            username = "me";
            database = "me";
          }
        ];
      };

    testScript =
      { nodes, ... }:
      ''
        start_all()
        machine.wait_for_unit("postgresql.service")
        machine.wait_for_open_port(5432)

        def peer_cmd(user, database):
            return "sudo -u me psql -U {user} {db} --command \"\"".format(user=user, db=database)

        with subtest("cannot login because of missing user"):
            machine.fail(peer_cmd("me", "me"), timeout=10)

        with subtest("cannot login with unknown user"):
            machine.fail(peer_cmd("notme", "me"), timeout=10)

        with subtest("cannot login to unknown database"):
            machine.fail(peer_cmd("me", "notmine"), timeout=10)
      '';
  };

  peerAuth = lib.shb.runNixOSTest {
    name = "postgresql-peerAuth";

    nodes.machine =
      { config, pkgs, ... }:
      {
        imports = [
          (pkgs'.path + "/nixos/modules/profiles/headless.nix")
          (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
          ../../modules/blocks/postgresql.nix
        ];

        users.users.me = {
          isSystemUser = true;
          group = "me";
          extraGroups = [ "sudoers" ];
        };
        users.groups.me = { };

        shb.postgresql.ensures = [
          {
            username = "me";
            database = "me";
          }
        ];
      };

    testScript =
      { nodes, ... }:
      ''
        start_all()
        machine.wait_for_unit("postgresql.service")
        machine.wait_for_open_port(5432)

        def peer_cmd(user, database):
            return "sudo -u me psql -U {user} {db} --command \"\"".format(user=user, db=database)

        def tcpip_cmd(user, database, port):
            return "psql -h 127.0.0.1 -p {port} -U {user} {db} --command \"\"".format(user=user, db=database, port=port)

        with subtest("can login with provisioned user and database"):
            machine.succeed(peer_cmd("me", "me"), timeout=10)

        with subtest("cannot login with unknown user"):
            machine.fail(peer_cmd("notme", "me"), timeout=10)

        with subtest("cannot login to unknown database"):
            machine.fail(peer_cmd("me", "notmine"), timeout=10)

        with subtest("cannot login with tcpip"):
            machine.fail(tcpip_cmd("me", "me", "5432"), timeout=10)
      '';
  };

  tcpIPWithoutPasswordAuth = lib.shb.runNixOSTest {
    name = "postgresql-tcpIpWithoutPasswordAuth";

    nodes.machine =
      { config, pkgs, ... }:
      {
        imports = [
          (pkgs'.path + "/nixos/modules/profiles/headless.nix")
          (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
          ../../modules/blocks/postgresql.nix
        ];

        shb.postgresql.enableTCPIP = true;
        shb.postgresql.ensures = [
          {
            username = "me";
            database = "me";
          }
        ];
      };

    testScript =
      { nodes, ... }:
      ''
        start_all()
        machine.wait_for_unit("postgresql.service")
        machine.wait_for_open_port(5432)

        def peer_cmd(user, database):
            return "sudo -u me psql -U {user} {db} --command \"\"".format(user=user, db=database)

        def tcpip_cmd(user, database, port):
            return "psql -h 127.0.0.1 -p {port} -U {user} {db} --command \"\"".format(user=user, db=database, port=port)

        with subtest("cannot login without existing user"):
            machine.fail(peer_cmd("me", "me"), timeout=10)

        with subtest("cannot login with user without password"):
            machine.fail(tcpip_cmd("me", "me", "5432"), timeout=10)
      '';
  };

  tcpIPPasswordAuth = lib.shb.runNixOSTest {
    name = "postgresql-tcpIPPasswordAuth";

    nodes.machine =
      { config, pkgs, ... }:
      {
        imports = [
          (pkgs'.path + "/nixos/modules/profiles/headless.nix")
          (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
          ../../modules/blocks/postgresql.nix
        ];

        users.users.me = {
          isSystemUser = true;
          group = "me";
          extraGroups = [ "sudoers" ];
        };
        users.groups.me = { };

        system.activationScripts.secret = ''
          echo secretpw > /run/dbsecret
        '';
        shb.postgresql.enableTCPIP = true;
        shb.postgresql.ensures = [
          {
            username = "me";
            database = "me";
            passwordFile = "/run/dbsecret";
          }
        ];
      };

    testScript =
      { nodes, ... }:
      ''
        start_all()
        machine.wait_for_unit("postgresql.service")
        machine.wait_for_open_port(5432)

        def peer_cmd(user, database):
            return "sudo -u me psql -U {user} {db} --command \"\"".format(user=user, db=database)

        def tcpip_cmd(user, database, port, password):
            return "PGPASSWORD={password} psql -h 127.0.0.1 -p {port} -U {user} {db} --command \"\"".format(user=user, db=database, port=port, password=password)

        with subtest("can peer login with provisioned user and database"):
            machine.succeed(peer_cmd("me", "me"), timeout=10)

        with subtest("can tcpip login with provisioned user and database"):
            machine.succeed(tcpip_cmd("me", "me", "5432", "secretpw"), timeout=10)

        with subtest("cannot tcpip login with wrong password"):
            machine.fail(tcpip_cmd("me", "me", "5432", "oops"), timeout=10)
      '';
  };
}
