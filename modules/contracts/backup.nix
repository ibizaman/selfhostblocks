{ lib, ... }:
lib.types.submodule {
  freeformType = lib.types.anything;

  options = {
    user = lib.mkOption {
      description = "Unix user doing the backups.";
      type = lib.types.str;
      default = "backup";
    };

    group = lib.mkOption {
      description = "Unix group doing the backups.";
      type = lib.types.str;
      default = "backup";
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

    retention = lib.mkOption {
      description = "Backup files retention.";
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.int lib.types.nonEmptyStr ]);
      default = {
        keep_within = "1d";
        keep_hourly = 24;
        keep_daily = 7;
        keep_weekly = 4;
        keep_monthly = 6;
      };
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
