{ lib, ... }:
lib.types.submodule {
  freeformType = lib.types.anything;

  options = {
    user = lib.mkOption {
      description = "Unix user doing the backups.";
      type = lib.types.str;
    };

    sourceDirectories = lib.mkOption {
      description = "Directories to backup.";
      type = lib.types.nonEmptyListOf lib.types.str;
    };

    excludePatterns = lib.mkOption {
      description = "Patterns to exclude.";
      type = lib.types.listOf lib.types.str;
      default = [];
    };

    hooks = lib.mkOption {
      description = "Hooks to run around the backup.";
      default = {};
      type = lib.types.submodule {
        options = {
          before_backup = lib.mkOption {
            description = "Hooks to run before backup";
            type = lib.types.listOf lib.types.str;
            default = [];
          };

          after_backup = lib.mkOption {
            description = "Hooks to run after backup";
            type = lib.types.listOf lib.types.str;
            default = [];
          };
        };
      };
    };
  };
}
