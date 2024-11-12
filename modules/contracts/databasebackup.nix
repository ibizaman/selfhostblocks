{ lib, ... }:
let
  inherit (lib) mkIf mkOption literalExpression;
  inherit (lib.types) anything submodule str;
in
{
  requestType = submodule {
    options = {
      user = mkOption {
        description = "Unix user doing the backups.";
        type = str;
        example = "postgres";
      };

      backupFile = mkOption {
        description = "Filename of the backup.";
        type = str;
        default = "dump";
        example = "postgresql.sql";
      };

      backupCmd = mkOption {
        description = "Command that produces the database dump on stdout.";
        type = str;
        example = literalExpression ''
          ''${pkgs.postgresql}/bin/pg_dumpall | ''${pkgs.gzip}/bin/gzip --rsyncable
        '';
      };

      restoreCmd = mkOption {
        description = "Command that reads the database dump on stdin and restores the database.";
        type = str;
        example = literalExpression ''
          ''${pkgs.gzip}/bin/gunzip | ''${pkgs.postgresql}/bin/psql postgres
        '';
      };
    };
  };


  resultType = submodule {
    options = {
      restoreScript = mkOption {
        description = ''
          Name of script that can restore the database.
          One can then list snapshots with:

          ```bash
          $ my_restore_script snapshots
          ```

          And restore the database with:

          ```bash
          $ my_restore_script restore latest
          ```
        '';
        type = str;
        example = "my_restore_script";
      };

      backupService = mkOption {
        description = ''
          Name of service backing up the database.

          This script can be ran manually to backup the database:

          ```bash
          $ systemctl start my_backup_service
          ```
        '';
        type = str;
        example = "my_backup_service.service";
      };
    };
  };
}
