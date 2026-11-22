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
  request = { ... }: {
    user = mkOption {
      description = ''
        Unix user doing the backups.
      '';
      type = str;
      example = "vaultwarden";
    };

    sourceDirectories = mkOption {
      description = "Directories to backup.";
      type = nonEmptyListOf str;
      example = "/var/lib/vaultwarden";
    };

    excludePatterns = mkOption {
      description = "File patterns to exclude.";
      type = listOf str;
      default = [ ];
    };

    beforeBackup = mkOption {
      description = "Hooks to run before a backup.";
      type = listOf str;
      default = [ ];
    };

    afterBackup = mkOption {
      description = "Hooks to run after a backup.";
      type = listOf str;
      default = [ ];
    };

    beforeRestore = mkOption {
      description = "Hooks to run before a restore.";
      type = listOf str;
      default = [ ];
    };

    afterRestore = mkOption {
      description = "Hooks to run after a restore.";
      type = listOf str;
      default = [ ];
    };

  };
  result =
    { lib, options, ... }:
    let
      restoreScript =
        lib.options.renderOptionValue
          options.restoreScript.defaultText or options.restoreScript.default;
      backupService =
        lib.options.renderOptionValue
          options.backupService.defaultText or options.backupService.default;
    in
    {
      restoreScript = mkOption {
        description = ''
          Name of script that can restore the files.
          One can then list snapshots with:

          ```bash
          $ ${restoreScript} snapshots
          <snapshot 1> <metadata>
          <snapshot 2> <metadata>
          ```

          And restore the files with:

          ```bash
          $ ${restoreScript} restore <snapshot 1>
          ```
        '';
        type = str;
      };

      backupService = mkOption {
        description = ''
          Name of service backing up the files.

          This script can be ran manually to backup the files:

          ```bash
          $ systemctl start ${backupService}
          ```
        '';
        type = str;
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
