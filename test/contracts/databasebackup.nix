{
  shb,
  pkgs,
  lib,
  ...
}:
let
  testFile = pkgs.callPackage ../../modules/contracts/databasebackup/test.nix { inherit shb; };
in
rec {
  restic_postgres = testFile {
    name = "restic_postgres";
    requesterRoot = [
      "shb"
      "postgresql"
      "databasebackup"
    ];
    providerRoot = [
      "shb"
      "restic"
      "databases"
      "postgresql"
    ];
    modules = [
      ../../modules/blocks/postgresql.nix
      ../../modules/blocks/restic.nix
      ../../modules/blocks/hardcodedsecret.nix
    ];
    settings =
      { repository, config, ... }:
      {
        enable = true;
        repository = {
          path = repository;
          timerConfig = {
            OnCalendar = "00:00:00";
          };
        };
      };
    extraConfig =
      { config, database, ... }:
      {
        shb.postgresql.ensures = [
          {
            inherit database;
            username = database;
          }
        ];
        shb.hardcodedsecret.passphrase = config.shb.restic.databases.postgresql.settings.passphrase // {
          settings.content = "passphrase";
        };
      };
  };

  borgbackup_postgres = testFile {
    name = "borgbackup_postgres";
    requesterRoot = [
      "shb"
      "postgresql"
      "databasebackup"
    ];
    providerRoot = [
      "shb"
      "borgbackup"
      "databases"
      "postgresql"
    ];
    modules = [
      ../../modules/blocks/postgresql.nix
      ../../modules/blocks/borgbackup.nix
      ../../modules/blocks/hardcodedsecret.nix
    ];
    settings =
      { repository, config, ... }:
      {
        enable = true;
        stateDir = "/var/lib/borgbackup_postgres";
        repository = {
          path = repository;
          timerConfig = {
            OnCalendar = "00:00:00";
          };
        };
      };
    extraConfig =
      { config, database, ... }:
      {
        shb.postgresql.ensures = [
          {
            inherit database;
            username = database;
          }
        ];
        shb.hardcodedsecret.passphrase = config.shb.borgbackup.databases.postgresql.settings.passphrase // {
          settings.content = "passphrase";
        };
      };
  };

  borgbackup_failedDump = borgbackup_postgres.extend {
    modules = [
      ({ nodes, ... }: {
        name = lib.mkForce "borgbackup_failedDump";
        testScript =
          let
            requester = nodes.machine.shb.borgbackup.databases.postgresql.result;
          in
          lib.mkAfter ''
            with subtest("Failed database dump preserves existing snapshots"):
                before = machine.succeed("${requester.restoreScript} snapshots").splitlines()
                machine.succeed("systemctl stop postgresql.service")
                machine.fail("systemctl start --wait ${requester.backupService}")
                after = machine.succeed("${requester.restoreScript} snapshots").splitlines()
                assert after == before, f"Failed dump changed snapshots: {before} -> {after}"

            with subtest("Backup and restore recover after database restart"):
                machine.succeed("systemctl start postgresql.service")
                machine.succeed("systemctl start --wait ${requester.backupService}")
                snapshots = machine.succeed("${requester.restoreScript} snapshots").splitlines()
                assert len(snapshots) == len(before) + 1
                [snapshot] = set(snapshots) - set(before)
                machine.succeed(peer_cmd("DROP TABLE test"))
                machine.succeed(f"${requester.restoreScript} restore {snapshot}")
                assert query("SELECT * FROM test") == [{'name': 'car', 'count': '1'}]
          '';
      })
    ];
  };
}
