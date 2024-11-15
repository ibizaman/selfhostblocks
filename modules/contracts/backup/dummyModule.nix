{ pkgs, lib, ... }:
let
  contracts = pkgs.callPackage ../. {};

  inherit (lib) mkOption;
  inherit (lib.types) anything submodule;
in
{
  options.shb.contracts.backup = mkOption {
    description = ''
      Contract for backing up files
      between a requester module and a provider module.

      The requester communicates to the provider
      what files to backup
      through the `request` options.

      The provider reads from the `request` options
      and backs up the requested files.
      It communicates to the requester what script is used
      to backup and restore the files
      through the `result` options.
    '';

    type = submodule {
      options = {
        request = mkOption {
          description = ''
          Options set by a requester module of the backup contract.
          '';
          type = contracts.backup.request;
        };

        result = mkOption {
          description = ''
          Options set by a provider module of the backup contract.
          '';
          type = contracts.backup.result {
            restoreScript = "my_restore_script";
            backupService = "my_backup_service.service";
          };
        };
      };
    };
  };
}
