{ pkgs, ... }:
let
  contracts = pkgs.callPackage ../../modules/contracts {};
in
{
  restic_postgres = contracts.test.databasebackup {
    name = "restic_postgres";
    requesterRoot = [ "shb" "postgresql" ];
    providerRoot = [ "shb" "restic" "databases" "postgresql" ];
    modules = [
      ../../modules/blocks/postgresql.nix
      ../../modules/blocks/restic.nix
    ];
    settings = repository: {
      enable = true;
      passphrase.result.path = pkgs.writeText "passphrase" "PassPhrase";
      repository = {
        path = repository;
        timerConfig = {
          OnCalendar = "00:00:00";
        };
      };
    };
    extraConfig = { username, database, ... }: {
      shb.postgresql.ensures = [
        {
          inherit username database;
        }
      ];
    };
  };
}
