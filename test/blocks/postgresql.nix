{ pkgs, lib, ... }:
let
  pkgs' = pkgs;
in
{
  peerWithoutUser = pkgs.testers.runNixOSTest {
    name = "postgresql-peerWithoutUser";

    nodes.machine = { config, pkgs, ... }: {
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

    testScript = { nodes, ... }: ''
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

  peerAuth = pkgs.testers.runNixOSTest {
    name = "postgresql-peerAuth";

    nodes.machine = { config, pkgs, ... }: {
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
      users.groups.me = {};

      shb.postgresql.ensures = [
        {
          username = "me";
          database = "me";
        }
      ];
    };

    testScript = { nodes, ... }: ''
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

  tcpIPWithoutPasswordAuth = pkgs.testers.runNixOSTest {
    name = "postgresql-tcpIpWithoutPasswordAuth";

    nodes.machine = { config, pkgs, ... }: {
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

    testScript = { nodes, ... }: ''
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

  tcpIPPasswordAuth = pkgs.testers.runNixOSTest {
    name = "postgresql-tcpIPPasswordAuth";

    nodes.machine = { config, pkgs, ... }: {
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
      users.groups.me = {};

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

    testScript = { nodes, ... }: ''
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

  backup = pkgs.testers.runNixOSTest {
    name = "postgresql-backup";

    nodes.machine = { config, pkgs, ... }: {
      imports = [
        (pkgs'.path + "/nixos/modules/profiles/headless.nix")
        (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
        ../../modules/blocks/postgresql.nix
        ../../modules/blocks/restic.nix
      ];

      users.users.me = {
        isSystemUser = true;
        group = "me";
        extraGroups = [ "sudoers" ];
      };
      users.groups.me = {};

      services.postgresql.enable = true;
      shb.postgresql.ensures = [
        {
          username = "me";
          database = "me";
        }
      ];
      shb.restic.databases."postgres".request = config.shb.postgresql.backup;
      shb.restic.databases."postgres".settings = {
        enable = true;

        passphraseFile = toString (pkgs.writeText "passphrase" "PassPhrase");
        repositories = [
          {
            path = "/opt/repos/postgres";
            timerConfig = {
              OnCalendar = "00:00:00";
            };
          }
        ];
      };
    };

    testScript = { nodes, ... }: ''
    import csv

    start_all()
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_open_port(5432)

    def peer_cmd(cmd, db="me"):
        return "sudo -u me psql -U me {db} --csv --command \"{cmd}\"".format(cmd=cmd, db=db)

    def query(query):
        res = machine.succeed(peer_cmd(query))
        return list(dict(l) for l in csv.DictReader(res.splitlines()))

    def cmp_tables(a, b):
        for i in range(max(len(a), len(b))):
            diff = set(a[i]) ^ set(b[i])
            if len(diff) > 0:
                raise Exception(i, diff)

    table = [{'name': 'car', 'count': '1'}, {'name': 'lollipop', 'count': '2'}]

    with subtest("create fixture"):
        machine.succeed(peer_cmd("CREATE TABLE test (name text, count int)"))
        machine.succeed(peer_cmd("INSERT INTO test VALUES ('car', 1), ('lollipop', 2)"))

        res = query("SELECT * FROM test")
        cmp_tables(res, table)

    with subtest("backup"):
        print(machine.succeed("systemctl cat restic-backups-postgres_opt_repos_postgres.service"))
        machine.succeed("systemctl start restic-backups-postgres_opt_repos_postgres.service")

    with subtest("drop database"):
        machine.succeed(peer_cmd("DROP DATABASE me", db="postgres"))

    with subtest("restore"):
        print(machine.succeed("readlink -f $(type restic-backups-postgres_opt_repos_postgres)"))
        machine.succeed("restic-backups-postgres_opt_repos_postgres restore latest ")

    with subtest("check restoration"):
        res = query("SELECT * FROM test")
        cmp_tables(res, table)
    '';
  };
}
