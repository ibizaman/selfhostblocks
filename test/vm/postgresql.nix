{ pkgs, lib, ... }:
{
  peerWithoutUser = pkgs.nixosTest {
    name = "postgresql-peerWithoutUser";

    nodes.machine = { config, pkgs, ... }: {
      imports = [
        ../../modules/blocks/postgresql.nix
      ];

      shb.postgresql.ensures = [
        {
          username = "me";
          database = "mine";
        }
      ];
    };

    testScript = { nodes, ... }: ''
    start_all()
    machine.wait_for_unit("postgresql.service")

    def peer_cmd(user, database):
        return "sudo -u me psql -U {user} {db} --command \"\"".format(user=user, db=database)

    with subtest("cannot login because of missing user"):
        machine.fail(peer_cmd("me", "mine"), timeout=10)

    with subtest("cannot login with unknown user"):
        machine.fail(peer_cmd("notme", "mine"), timeout=10)

    with subtest("cannot login to unknown database"):
        machine.fail(peer_cmd("me", "notmine"), timeout=10)
    '';
  };

  peerAuth = pkgs.nixosTest {
    name = "postgresql-peerAuth";

    nodes.machine = { config, pkgs, ... }: {
      imports = [
        ../../modules/blocks/postgresql.nix
      ];

      users.users.me = {
        isSystemUser = true;
        group = "me";
        extraGroups = [ "sudoers" ];
      };
      users.groups.me = {};

      shb.postgresql.ensures = [
        {
          username = "me";
          database = "mine";
        }
      ];
    };

    testScript = { nodes, ... }: ''
    start_all()
    machine.wait_for_unit("postgresql.service")

    def peer_cmd(user, database):
        return "sudo -u me psql -U {user} {db} --command \"\"".format(user=user, db=database)

    def tcpip_cmd(user, database, port):
        return "psql -h 127.0.0.1 -p {port} -U {user} {db} --command \"\"".format(user=user, db=database, port=port)

    with subtest("can login with provisioned user and database"):
        machine.succeed(peer_cmd("me", "mine"), timeout=10)

    with subtest("cannot login with unknown user"):
        machine.fail(peer_cmd("notme", "mine"), timeout=10)

    with subtest("cannot login to unknown database"):
        machine.fail(peer_cmd("me", "notmine"), timeout=10)

    with subtest("cannot login with tcpip"):
        machine.fail(tcpip_cmd("me", "mine", "5432"), timeout=10)
    '';
  };

  tcpIPWithoutPasswordAuth = pkgs.nixosTest {
    name = "postgresql-tcpIpWithoutPasswordAuth";

    nodes.machine = { config, pkgs, ... }: {
      imports = [
        ../../modules/blocks/postgresql.nix
      ];

      shb.postgresql.enableTCPIP = true;
      shb.postgresql.ensures = [
        {
          username = "me";
          database = "mine";
        }
      ];
    };

    testScript = { nodes, ... }: ''
    start_all()
    machine.wait_for_unit("postgresql.service")

    def peer_cmd(user, database):
        return "sudo -u me psql -U {user} {db} --command \"\"".format(user=user, db=database)

    def tcpip_cmd(user, database, port):
        return "psql -h 127.0.0.1 -p {port} -U {user} {db} --command \"\"".format(user=user, db=database, port=port)

    with subtest("cannot login without existing user"):
        machine.fail(peer_cmd("me", "mine"), timeout=10)

    with subtest("cannot login with user without password"):
        machine.fail(tcpip_cmd("me", "mine", "5432"), timeout=10)
    '';
  };

  tcpIPPasswordAuth = pkgs.nixosTest {
    name = "postgresql-tcpIPPasswordAuth";

    nodes.machine = { config, pkgs, ... }: {
      imports = [
        ../../modules/blocks/postgresql.nix
      ];

      users.users.me = {
        isSystemUser = true;
        group = "me";
        extraGroups = [ "sudoers" ];
      };
      users.groups.me = {};

      system.activationScripts.secret = ''
      echo secretpw > /run/dbsecret
      '';
      shb.postgresql.enableTCPIP = true;
      shb.postgresql.ensures = [
        {
          username = "me";
          database = "mine";
          passwordFile = "/run/dbsecret";
        }
      ];
    };

    testScript = { nodes, ... }: ''
    start_all()
    machine.wait_for_unit("postgresql.service")

    def peer_cmd(user, database):
        return "sudo -u me psql -U {user} {db} --command \"\"".format(user=user, db=database)

    def tcpip_cmd(user, database, port, password):
        return "PGPASSWORD={password} psql -h 127.0.0.1 -p {port} -U {user} {db} --command \"\"".format(user=user, db=database, port=port, password=password)

    with subtest("can peer login with provisioned user and database"):
        machine.succeed(peer_cmd("me", "mine"), timeout=10)

    with subtest("can tcpip login with provisioned user and database"):
        machine.succeed(tcpip_cmd("me", "mine", "5432", "secretpw"), timeout=10)

    with subtest("cannot tcpip login with wrong password"):
        machine.fail(tcpip_cmd("me", "mine", "5432", "oops"), timeout=10)
    '';
  };
}
