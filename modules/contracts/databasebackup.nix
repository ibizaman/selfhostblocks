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
  request = { ... }: {
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
      example = "postgresql.sql";
      default = "dump.sql";
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

  result =
    { options, ... }:
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
          Name of script that can restore the database.
          One can then list snapshots with:

          ```bash
          $ ${restoreScript} snapshots
          ```

          And restore the database with:

          ```bash
          $ ${restoreScript} restore latest
          ```
        '';
        type = str;
      };

      backupService = mkOption {
        description = ''
          Name of service backing up the database.

          This script can be ran manually to backup the database:

          ```bash
          $ systemctl start ${backupService}
          ```
        '';
        type = str;
      };
    };
}
