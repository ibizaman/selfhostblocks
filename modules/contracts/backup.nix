{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything listOf nonEmptyListOf nullOr submodule str;
in
submodule {
  freeformType = anything;

  options = {
    user = mkOption {
      description = "Unix user doing the backups.";
      type = str;
    };

    sourceDirectories = mkOption {
      description = "Directories to backup.";
      type = nonEmptyListOf str;
    };

    excludePatterns = mkOption {
      description = "Patterns to exclude.";
      type = listOf str;
      default = [];
    };

    hooks = mkOption {
      description = "Hooks to run around the backup.";
      default = {};
      type = submodule {
        options = {
          before_backup = mkOption {
            description = "Hooks to run before backup";
            type = listOf str;
            default = [];
          };

          after_backup = mkOption {
            description = "Hooks to run after backup";
            type = listOf str;
            default = [];
          };
        };
      };
    };
  };
}
