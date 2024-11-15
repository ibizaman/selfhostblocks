{ lib, ... }:
let
  inherit (lib) mkIf mkOption literalExpression;
  inherit (lib.types) anything submodule str;
in
{
  request = submodule {
    options = {
      user = mkOption {
        description = ''
          Unix user doing the backups.

          This should be an admin user having access to all databases.
        '';
        type = str;
        example = "postgres";
      };

      backupName = mkOption {
        description = "Name of the backup in the repository.";
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


  result = {
    restoreScript,
    restoreScriptText ? null,
    backupService,
    backupServiceText ? null,
  }: submodule {
    options = {
      restoreScript = mkOption {
        description = ''
          Name of script that can restore the database.
          One can then list snapshots with:

          ```bash
          $ ${if restoreScriptText != null then restoreScriptText else restoreScript} snapshots
          ```

          And restore the database with:

          ```bash
          $ ${if restoreScriptText != null then restoreScriptText else restoreScript} restore latest
          ```
        '';
        type = str;
        default = restoreScript;
        defaultText = restoreScriptText;
      };

      backupService = mkOption {
        description = ''
          Name of service backing up the database.

          This script can be ran manually to backup the database:

          ```bash
          $ systemctl start ${if backupServiceText != null then backupServiceText else backupService}
          ```
        '';
        type = str;
        default = backupService;
        defaultText = backupServiceText;
      };
    };
  };
}
