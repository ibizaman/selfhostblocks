{ pkgs, lib, ... }:
let
  contracts = pkgs.callPackage ../. {};

  inherit (lib) mkOption;
  inherit (lib.types) anything submodule;
in
{
  options.shb.contracts.databasebackup = mkOption {
    description = ''
      Contract for database backup between a requester module
      and a provider module.

      The requester communicates to the provider
      how to backup the database
      through the `request` options.

      The provider reads from the `request` options
      and backs up the database as requested.
      It communicates to the requester what script is used
      to backup and restore the database
      through the `result` options.
    '';

    type = submodule {
      options = {
        request = mkOption {
          description = ''
          Options set by a requester module of the database backup contract.
          '';
          type = contracts.databasebackup.request;
        };

        result = mkOption {
          description = ''
          Options set by a provider module of the database backup contract.
          '';
          type = contracts.databasebackup.result {
            restoreScript = "my_restore_script";
            backupService = "my_backup_service.service";
          };
        };
      };
    };
  };
}
