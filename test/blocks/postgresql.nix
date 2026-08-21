{
  pkgs,
  lib,
  shb,
  ...
}:
let
  pkgs' = pkgs;
  testPostgresqlVersion = 18;
in
{
  peerWithoutUser = shb.test.runNixOSTest {
    name = "postgresql-peerWithoutUser";

    nodes.machine =
      { config, pkgs, ... }:
      {
        imports = [
          (pkgs'.path + "/nixos/modules/profiles/headless.nix")
          (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
          ../../modules/blocks/postgresql.nix
        ];

        shb.postgresql = {
          version = testPostgresqlVersion;
          ensures = [
            {
              username = "me-with-special-chars";
              database = "me-with-special-chars";
            }
          ];
        };
      };

    testScript =
      { nodes, ... }:
      ''
        start_all()
        machine.wait_for_unit("postgresql.target")
        machine.wait_for_open_port(5432)

        def peer_cmd(user, database):
            return "sudo -u me psql -U {user} {db} --command \"\"".format(user=user, db=database)

        with subtest("cannot login because of missing user"):
            machine.fail(peer_cmd("me-with-special-chars", "me-with-special-chars"), timeout=10)

        with subtest("cannot login with unknown user"):
            machine.fail(peer_cmd("notme", "me-with-other-chars"), timeout=10)

        with subtest("cannot login to unknown database"):
            machine.fail(peer_cmd("me-with-special-chars", "notmine"), timeout=10)
      '';
  };

  peerAuth = shb.test.runNixOSTest {
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

        shb.postgresql = {
          version = testPostgresqlVersion;
          ensures = [
            {
              username = "me";
              database = "me";
            }
          ];
        };
      };

    testScript =
      { nodes, ... }:
      ''
        start_all()
        machine.wait_for_unit("postgresql.target")
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

  tcpIPWithoutPasswordAuth = shb.test.runNixOSTest {
    name = "postgresql-tcpIpWithoutPasswordAuth";

    nodes.machine =
      { config, pkgs, ... }:
      {
        imports = [
          (pkgs'.path + "/nixos/modules/profiles/headless.nix")
          (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
          ../../modules/blocks/postgresql.nix
        ];

        shb.postgresql = {
          version = testPostgresqlVersion;
          enableTCPIP = true;
          ensures = [
            {
              username = "me";
              database = "me";
            }
          ];
        };
      };

    testScript =
      { nodes, ... }:
      ''
        start_all()
        machine.wait_for_unit("postgresql.target")
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

  tcpIPPasswordAuth =
    let
      username = "me-with-special-chars";
    in
    shb.test.runNixOSTest {
      name = "postgresql-tcpIPPasswordAuth";

      nodes.machine =
        { config, pkgs, ... }:
        {
          imports = [
            (pkgs'.path + "/nixos/modules/profiles/headless.nix")
            (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
            ../../modules/blocks/postgresql.nix
          ];

          users.users.${username} = {
            isSystemUser = true;
            group = username;
            extraGroups = [ "sudoers" ];
          };
          users.groups.${username} = { };

          system.activationScripts.secret = ''
            echo secretpw > /run/dbsecret
          '';
          shb.postgresql = {
            version = testPostgresqlVersion;
            enableTCPIP = true;
            ensures = [
              {
                username = username;
                database = username;
                passwordFile = "/run/dbsecret";
              }
            ];
          };
        };

      testScript =
        { nodes, ... }:
        ''
          start_all()
          machine.wait_for_unit("postgresql.target")
          machine.wait_for_open_port(5432)

          def peer_cmd(user, database):
              return "sudo -u ${username} psql -U {user} {db} --command \"\"".format(user=user, db=database)

          def tcpip_cmd(user, database, port, password):
              return "PGPASSWORD={password} psql -h 127.0.0.1 -p {port} -U {user} {db} --command \"\"".format(user=user, db=database, port=port, password=password)

          with subtest("can peer login with provisioned user and database"):
              machine.succeed(peer_cmd("${username}", "${username}"), timeout=10)

          with subtest("can tcpip login with provisioned user and database"):
              machine.succeed(tcpip_cmd("${username}", "${username}", "5432", "secretpw"), timeout=10)

          with subtest("cannot tcpip login with wrong password"):
              machine.fail(tcpip_cmd("${username}", "${username}", "5432", "oops"), timeout=10)
        '';
    };

  upgrade = shb.test.runNixOSTest {
    name = "postgresql-upgrade";

    nodes.machine =
      { config, pkgs, ... }:
      {
        imports = [
          (pkgs'.path + "/nixos/modules/profiles/headless.nix")
          (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
          ../../modules/blocks/postgresql.nix
        ];

        shb.postgresql = {
          version = 15;
          ensures = [
            {
              username = "upgrade-test";
              database = "upgrade-test";
            }
          ];
        };

        assertions = [
          {
            assertion =
              config.services.postgresql.finalPackage.psqlSchema == toString config.shb.postgresql.version;
            message = "The PostgreSQL package must match shb.postgresql.version.";
          }
          {
            assertion =
              config.services.postgresql.dataDir
              == "/var/lib/postgresql/${toString config.shb.postgresql.version}";
            message = "The PostgreSQL data directory must match shb.postgresql.version.";
          }
          {
            # hasInfix turns its needle into a regex, which cannot carry store-path context.
            assertion = lib.hasInfix (builtins.unsafeDiscardStringContext "${config.services.postgresql.finalPackage}/bin/pg_dumpall") config.shb.postgresql.databasebackup.request.backupCmd;
            message = "The backup command must use the configured PostgreSQL package.";
          }
          {
            # hasInfix turns its needle into a regex, which cannot carry store-path context.
            assertion = lib.hasInfix (builtins.unsafeDiscardStringContext "${config.services.postgresql.finalPackage}/bin/psql") config.shb.postgresql.databasebackup.request.restoreCmd;
            message = "The restore command must use the configured PostgreSQL package.";
          }
        ];

        specialisation = {
          postgresql16.configuration.shb.postgresql.version = lib.mkForce 16;
          postgresql17.configuration.shb.postgresql.version = lib.mkForce 17;
          postgresql18.configuration.shb.postgresql.version = lib.mkForce 18;
        };
      };

    testScript =
      { nodes, ... }:
      let
        baseSystem = nodes.machine.system.build.toplevel;
        specialisations = "${baseSystem}/specialisation";
        switch =
          version: "${specialisations}/postgresql${toString version}/bin/switch-to-configuration test";
      in
      ''
        start_all()
        machine.wait_for_unit("postgresql.service")
        machine.wait_for_open_port(5432)

        with subtest("create data on PostgreSQL 15"):
            machine.succeed(
                "sudo -u postgres psql --dbname=postgres "
                + "--command=\"CREATE TABLE shb_upgrade_marker (value text); "
                + "INSERT INTO shb_upgrade_marker VALUES ('survives upgrades');\""
            )

        with subtest("upgrade helper refuses to run while PostgreSQL is active"):
            machine.fail("upgrade-pg-cluster-15-16")
            machine.succeed("systemctl is-active --quiet postgresql.service")
            machine.fail("test -e /var/lib/postgresql/16/PG_VERSION")

        with subtest("changing the version does not initialize a replacement cluster"):
            machine.execute("${switch 16}")
            machine.wait_until_fails("systemctl is-active --quiet postgresql.service")
            machine.succeed(
                "journalctl --unit=postgresql.service "
                + "--grep='Found an existing PostgreSQL cluster' --no-pager"
            )
            machine.succeed(
                "journalctl --unit=postgresql.service "
                + "--grep='Remove the empty target directory' --no-pager"
            )
            machine.succeed("test -d /var/lib/postgresql/16")
            machine.fail("test -e /var/lib/postgresql/16/PG_VERSION")
            machine.succeed("test -e /var/lib/postgresql/15/PG_VERSION")

            target_error = machine.fail("${baseSystem}/sw/bin/upgrade-pg-cluster-15-16 2>&1")
            assert "already exists" in target_error

            machine.succeed("${baseSystem}/bin/switch-to-configuration test")
            machine.succeed("rmdir /var/lib/postgresql/16")
            machine.succeed("systemctl reset-failed postgresql.service")
            machine.succeed("systemctl start postgresql.target")
            machine.wait_for_unit("postgresql.service")
            machine.wait_for_open_port(5432)

        with subtest("only forward upgrade helpers from the configured version are installed"):
            machine.succeed("command -v upgrade-pg-cluster-15-16")
            machine.succeed("command -v upgrade-pg-cluster-15-17")
            machine.succeed("command -v upgrade-pg-cluster-15-18")
            machine.fail("command -v upgrade-pg-cluster-16-17")

        def migrate(old_version, new_version, switch_command):
            machine.succeed("systemctl stop postgresql.service")
            machine.wait_until_fails("systemctl is-active --quiet postgresql.service")

            upgrade_output = machine.succeed(
                f"upgrade-pg-cluster-{old_version}-{new_version}"
            )
            assert "Upgrade Complete" in upgrade_output
            assert "delete_old_cluster" in upgrade_output

            machine.succeed(switch_command)
            machine.wait_for_unit("postgresql.service")
            machine.wait_for_open_port(5432)

            server_version = machine.succeed(
                "sudo -u postgres psql --tuples-only --no-align "
                + "--dbname=postgres --command='SHOW server_version_num'"
            ).strip()
            assert server_version.startswith(str(new_version))

            marker = machine.succeed(
                "sudo -u postgres psql --tuples-only --no-align "
                + "--dbname=postgres --command='SELECT value FROM shb_upgrade_marker'"
            ).strip()
            assert marker == "survives upgrades"
            machine.succeed(f"test -e /var/lib/postgresql/{old_version}/PG_VERSION")

        with subtest("upgrade sequentially through every supported major"):
            migrate(15, 16, "${switch 16}")
            migrate(16, 17, "${switch 17}")
            migrate(17, 18, "${switch 18}")
      '';
  };

  nonAdjacentUpgrade = shb.test.runNixOSTest {
    name = "postgresql-non-adjacent-upgrade";

    nodes.machine =
      { pkgs, ... }:
      {
        imports = [
          (pkgs'.path + "/nixos/modules/profiles/headless.nix")
          (pkgs'.path + "/nixos/modules/profiles/qemu-guest.nix")
          ../../modules/blocks/postgresql.nix
        ];

        services.postgresql.enable = true;
        shb.postgresql.version = 15;

        specialisation.postgresql18.configuration.shb.postgresql.version = lib.mkForce 18;
      };

    testScript =
      { nodes, ... }:
      let
        baseSystem = nodes.machine.system.build.toplevel;
        switchToPostgresql18 = "${baseSystem}/specialisation/postgresql18/bin/switch-to-configuration test";
      in
      ''
        start_all()
        machine.wait_for_unit("postgresql.service")
        machine.wait_for_open_port(5432)

        with subtest("create data on PostgreSQL 15"):
            machine.succeed(
                "sudo -u postgres psql --dbname=postgres "
                + "--command=\"CREATE TABLE shb_upgrade_marker (value text); "
                + "INSERT INTO shb_upgrade_marker VALUES ('survives upgrade');\""
            )

        with subtest("upgrade directly from PostgreSQL 15 to 18"):
            machine.succeed("systemctl stop postgresql.service")
            machine.wait_until_fails("systemctl is-active --quiet postgresql.service")

            upgrade_output = machine.succeed("upgrade-pg-cluster-15-18")
            assert "Upgrade Complete" in upgrade_output
            assert "delete_old_cluster" in upgrade_output

            machine.succeed("${switchToPostgresql18}")
            machine.succeed("systemctl start postgresql.target")
            machine.wait_for_unit("postgresql.service")
            machine.wait_for_open_port(5432)

            server_version = machine.succeed(
                "sudo -u postgres psql --tuples-only --no-align "
                + "--dbname=postgres --command='SHOW server_version_num'"
            ).strip()
            assert server_version.startswith("18")

            marker = machine.succeed(
                "sudo -u postgres psql --tuples-only --no-align "
                + "--dbname=postgres --command='SELECT value FROM shb_upgrade_marker'"
            ).strip()
            assert marker == "survives upgrade"
            machine.succeed("test -e /var/lib/postgresql/15/PG_VERSION")
      '';
  };
}
