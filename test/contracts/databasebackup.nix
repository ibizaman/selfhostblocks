{ pkgs, ... }:
let
  contracts = pkgs.callPackage ../../modules/contracts { };
in
{
  restic_postgres = contracts.test.databasebackup {
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
        passphrase.result = config.shb.hardcodedsecret.passphrase.result;
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
        shb.hardcodedsecret.passphrase = {
          request = config.shb.restic.databases.postgresql.settings.passphrase.request;
          settings.content = "passphrase";
        };
      };
  };

  borgbackup_postgres = contracts.test.databasebackup {
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
        passphrase.result = config.shb.hardcodedsecret.passphrase.result;
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
        shb.hardcodedsecret.passphrase = {
          request = config.shb.borgbackup.databases.postgresql.settings.passphrase.request;
          settings.content = "passphrase";
        };
      };
  };
}
