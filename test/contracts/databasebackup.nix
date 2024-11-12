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
      passphraseFile = toString (pkgs.writeText "passphrase" "PassPhrase");
      repository = {
        path = repository;
        timerConfig = {
          OnCalendar = "00:00:00";
        };
      };
    };
    providerExtraConfig = { username, database, ... }: {
      shb.postgresql.ensures = [
        {
          inherit username database;
        }
      ];
    };
  };
}
