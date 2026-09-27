{
  lib,
  shb,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    literalMD
    mkOption
    optionalAttrs
    optionalString
    ;
  inherit (lib.types)
    listOf
    nonEmptyListOf
    submodule
    str
    ;
  inherit (shb) anyNotNull;
in
{
  mkRequest =
    {
      user ? "",
      userText ? null,
      sourceDirectories ? [ "/var/lib/example" ],
      sourceDirectoriesText ? null,
      excludePatterns ? [ ],
      excludePatternsText ? null,
      beforeBackup ? [ ],
      beforeBackupText ? null,
      afterBackup ? [ ],
      afterBackupText ? null,
      beforeRestore ? [ ],
      beforeRestoreText ? null,
      afterRestore ? [ ],
      afterRestoreText ? null,
    }:
    mkOption {
      description = ''
        Request part of the backup contract.

        Options set by the requester module
        enforcing how to backup files.
      '';

      default = {
        inherit user sourceDirectories excludePatterns;
        inherit beforeBackup afterBackup;
        inherit beforeRestore afterRestore;
      };

      defaultText =
        optionalString
          (anyNotNull [
            userText
            sourceDirectoriesText
            excludePatternsText
            beforeBackupText
            afterBackupText
            beforeRestoreText
            afterRestoreText
          ])
          (literalMD ''
            {
              user = ${if userText != null then userText else user};
              sourceDirectories = ${
                if sourceDirectoriesText != null then
                  sourceDirectoriesText
                else
                  "[ " + concatStringsSep " " sourceDirectories + " ]"
              };
              excludePatterns = ${
                if excludePatternsText != null then
                  excludePatternsText
                else
                  "[ " + concatStringsSep " " excludePatterns + " ]"
              };
              hooks.beforeBackup = ${
                if beforeBackupText != null then
                  beforeBackupText
                else
                  "[ " + concatStringsSep " " beforeBackup + " ]"
              };
              hooks.afterBackup = ${
                if afterBackupText != null then afterBackupText else "[ " + concatStringsSep " " afterBackup + " ]"
              };
              hooks.beforeRestore = ${
                if beforeRestoreText != null then
                  beforeRestoreText
                else
                  "[ " + concatStringsSep " " beforeRestore + " ]"
              };
              hooks.afterRestore = ${
                if afterRestoreText != null then
                  afterRestoreText
                else
                  "[ " + concatStringsSep " " afterRestore + " ]"
              };
            };
          '');

      type = submodule {
        options = {
          user =
            mkOption {
              description = ''
                Unix user doing the backups.
              '';
              type = str;
              example = "vaultwarden";
              default = user;
            }
            // optionalAttrs (userText != null) {
              defaultText = literalMD userText;
            };

          sourceDirectories =
            mkOption {
              description = "Directories to backup.";
              type = nonEmptyListOf str;
              example = "/var/lib/vaultwarden";
              default = sourceDirectories;
            }
            // optionalAttrs (sourceDirectoriesText != null) {
              defaultText = literalMD sourceDirectoriesText;
            };

          excludePatterns =
            mkOption {
              description = "File patterns to exclude.";
              type = listOf str;
              default = excludePatterns;
            }
            // optionalAttrs (excludePatternsText != null) {
              defaultText = literalMD excludePatternsText;
            };

          beforeBackup =
            mkOption {
              description = "Hooks to run before a backup.";
              type = listOf str;
              default = beforeBackup;
            }
            // optionalAttrs (beforeBackupText != null) {
              defaultText = literalMD beforeBackupText;
            };

          afterBackup =
            mkOption {
              description = "Hooks to run after a backup.";
              type = listOf str;
              default = afterBackup;
            }
            // optionalAttrs (afterBackupText != null) {
              defaultText = literalMD afterBackupText;
            };

          beforeRestore =
            mkOption {
              description = "Hooks to run before a restore.";
              type = listOf str;
              default = beforeBackup;
            }
            // optionalAttrs (beforeBackupText != null) {
              defaultText = literalMD beforeBackupText;
            };

          afterRestore =
            mkOption {
              description = "Hooks to run after a restore.";
              type = listOf str;
              default = afterBackup;
            }
            // optionalAttrs (afterBackupText != null) {
              defaultText = literalMD afterBackupText;
            };
        };
      };
    };

  mkResult =
    {
      restoreScript ? "restore",
      restoreScriptText ? null,
      backupService ? "backup.service",
      backupServiceText ? null,
    }:
    mkOption {
      description = ''
        Result part of the backup contract.

        Options set by the provider module that indicates the name of the backup and restore scripts.
      '';
      default = {
        inherit restoreScript backupService;
      };

      defaultText =
        optionalString
          (anyNotNull [
            restoreScriptText
            backupServiceText
          ])
          (literalMD ''
            {
              restoreScript = ${if restoreScriptText != null then restoreScriptText else restoreScript};
              backupService = ${if backupServiceText != null then backupServiceText else backupService};
            }
          '');

      type = submodule {
        options = {
          restoreScript =
            mkOption {
              description = ''
                Name of script that can restore the database.
                One can then list snapshots with:

                ```bash
                $ ${if restoreScriptText != null then restoreScriptText else restoreScript} snapshots
                <snapshot 1> <metadata>
                <snapshot 2> <metadata>
                ```

                And restore the database with:

                ```bash
                $ ${if restoreScriptText != null then restoreScriptText else restoreScript} restore <snapshot 1>
                ```
              '';
              type = str;
              default = restoreScript;
            }
            // optionalAttrs (restoreScriptText != null) {
              defaultText = literalMD restoreScriptText;
            };

          backupService =
            mkOption {
              description = ''
                Name of service backing up the database.

                This script can be ran manually to backup the database:

                ```bash
                $ systemctl start ${if backupServiceText != null then backupServiceText else backupService}
                ```
              '';
              type = str;
              default = backupService;
            }
            // optionalAttrs (backupServiceText != null) {
              defaultText = literalMD backupServiceText;
            };
        };
      };
    };

  passthru.mkRestoreScript =
    {
      name,
      user,
      backupCmd,
      restoreCmd,
      listCmd,
      execCmd,
    }:
    pkgs.writeShellApplication {
      inherit name;

      text = ''
        usage() {
          echo "$0 snapshots"
          echo "$0 backup"
          echo "$0 restore <snapshot>"
          echo "$0 exec <arg> [<args>...]"
        }

        if [ -z "''${1:-}" ]; then
          usage
          exit 0
        fi

        case "$1" in
          restore)
            shift
            snapshot="$1"

            echo "Will restore snapshot '$snapshot'"

            ${restoreCmd}
            ;;
          backup)
            shift

            ${backupCmd}
            ;;
          snapshots) 
            shift

            ${listCmd}
            ;;
          exec)
            shift

            ${execCmd} "$@"
            ;;
          *)
            usage
            exit 1
            ;;
        esac
      '';
    };
}
