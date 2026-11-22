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
  request = { ... }: {
    dataset = mkOption {
      description = ''
        Dataset to backup, including the pool name.
      '';
      type = str;
      example = "root/home";
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
          <snapshot 1> <metadata>
          <snapshot 2> <metadata>
          ```

          And restore the database with:

          ```bash
          $ ${restoreScript} restore <snapshot 1>
          ```

          It is not garanteed to be able to restore back to a snapshot in the future.
          With the above example, it may not be possible to restore `<snapshot 2>`
          after having restored `<snapshot 1>`.
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
