{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything listOf nonEmptyListOf submodule str;
in
{
  request = submodule {
    options = {
      user = mkOption {
        description = ''
          Unix user doing the backups.

          Most of the time, this should be the user owning the files.
        '';
        type = str;
      };

      sourceDirectories = mkOption {
        description = "Directories to backup.";
        type = nonEmptyListOf str;
      };

      excludePatterns = mkOption {
        description = "File patterns to exclude.";
        type = listOf str;
        default = [];
      };

      hooks = mkOption {
        description = "Hooks to run around the backup.";
        default = {};
        type = submodule {
          options = {
            before_backup = mkOption {
              description = "Hooks to run before backup.";
              type = listOf str;
              default = [];
            };

            after_backup = mkOption {
              description = "Hooks to run after backup.";
              type = listOf str;
              default = [];
            };
          };
        };
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
