{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything submodule str;
in
{
  request = submodule {
    freeformType = anything;

    options = {
      user = mkOption {
        description = "Unix user doing the backups.";
        type = str;
      };

      backupFile = mkOption {
        description = "Filename of the backup.";
        type = str;
      };

      backupCmd = mkOption {
        description = "Command that produces the database dump on stdout.";
        type = str;
      };

      restoreCmd = mkOption {
        description = "Command that reads the database dump on stdin and restores the database.";
        type = str;
      };
    };
  };

  result = submodule {
    options = {
      restoreScript = mkOption {
        description = "Name of script that can restore the database.";
        type = str;
      };

      backupService = mkOption {
        description = "Name of service backing up the database.";
        type = str;
      };
    };
  };
}
