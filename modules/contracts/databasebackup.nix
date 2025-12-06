{ lib, shb, ... }:
let
  inherit (lib)
    mkOption
    literalExpression
    literalMD
    optionalAttrs
    optionalString
    ;
  inherit (lib.types) submodule str;
  inherit (shb) anyNotNull;
in
{
  mkRequest =
    {
      user ? "root",
      userText ? null,
      backupName ? "dump",
      backupNameText ? null,
      backupCmd ? "",
      backupCmdText ? null,
      restoreCmd ? "",
      restoreCmdText ? null,
    }:
    mkOption {
      description = ''
        Request part of the database backup contract.

        Options set by the requester module
        enforcing how to backup files.
      '';

      default = {
        inherit
          user
          backupName
          backupCmd
          restoreCmd
          ;
      };

      defaultText =
        optionalString
          (anyNotNull [
            userText
            backupNameText
            backupCmdText
            restoreCmdText
          ])
          (literalMD ''
            {
              user = ${if userText != null then userText else user};
              backupName = ${if backupNameText != null then backupNameText else backupName};
              backupCmd = ${if backupCmdText != null then backupCmdText else backupCmd};
              restoreCmd = ${if restoreCmdText != null then restoreCmdText else restoreCmd};
            }
          '');

      type = submodule {
        options = {
          user =
            mkOption {
              description = ''
                Unix user doing the backups.

                This should be an admin user having access to all databases.
              '';
              type = str;
              example = "postgres";
              default = user;
            }
            // optionalAttrs (userText != null) {
              defaultText = literalMD userText;
            };

          backupName =
            mkOption {
              description = "Name of the backup in the repository.";
              type = str;
              example = "postgresql.sql";
              default = backupName;
            }
            // optionalAttrs (backupNameText != null) {
              defaultText = literalMD backupNameText;
            };

          backupCmd =
            mkOption {
              description = "Command that produces the database dump on stdout.";
              type = str;
              example = literalExpression ''
                ''${pkgs.postgresql}/bin/pg_dumpall | ''${pkgs.gzip}/bin/gzip --rsyncable
              '';
              default = backupCmd;
            }
            // optionalAttrs (backupCmdText != null) {
              defaultText = literalMD backupCmdText;
            };

          restoreCmd =
            mkOption {
              description = "Command that reads the database dump on stdin and restores the database.";
              type = str;
              example = literalExpression ''
                ''${pkgs.gzip}/bin/gunzip | ''${pkgs.postgresql}/bin/psql postgres
              '';
              default = restoreCmd;
            }
            // optionalAttrs (restoreCmdText != null) {
              defaultText = literalMD restoreCmdText;
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
        Result part of the database backup contract.

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
                ```

                And restore the database with:

                ```bash
                $ ${if restoreScriptText != null then restoreScriptText else restoreScript} restore latest
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
}
