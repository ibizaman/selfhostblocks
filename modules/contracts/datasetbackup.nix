{ lib, ... }:
let
  inherit (lib)
    literalMD
    mkOption
    optionalAttrs
    ;
  inherit (lib.types)
    submodule
    str
    ;
in
{
  mkRequest =
    {
      dataset ? "",
      datasetText ? null,
    }:
    mkOption {
      description = ''
        Request part of the backup contract.

        Options set by the requester module
        enforcing how to backup files.
      '';

      default = { };

      type = submodule {
        options = {
          dataset =
            mkOption {
              description = ''
                Dataset to backup, including the pool name.
              '';
              type = str;
              example = "root/home";
              default = dataset;
            }
            // optionalAttrs (datasetText != null) {
              defaultText = literalMD datasetText;
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
      default = { };

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

                It is not garanteed to be able to restore back to a snapshot in the future.
                With the above example, it may not be possible to restore `<snapshot 2>`
                after having restored `<snapshot 1>`.
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
