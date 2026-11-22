{ lib, ... }:
let
  inherit (lib)
    concatStringsSep
    literalMD
    mkOption
    optionalAttrs
    optionalString
    ;
  inherit (lib.types) listOf submodule str;
in
{
  request = { ... }: {
    mode = mkOption {
      description = ''
        Mode of the secret file.
      '';
      type = str;
      default = "0400";
    };

    owner = mkOption {
      description = ''
        Linux user owning the secret file.
      '';
      type = str;
      default = "root";
    };

    group = mkOption {
      description = ''
        Linux group owning the secret file.
      '';
      type = str;
      default = "root";
    };

    restartUnits = mkOption {
      description = ''
        Systemd units to restart after the secret is updated.
      '';
      type = listOf str;
      default = [ ];
    };
  };

  result = { ... }: {
    path = mkOption {
      type = lib.types.path;
      description = ''
        Path to the file containing the secret generated out of band.

        This path will exist after deploying to a target host,
        it is not available through the nix store.
      '';
    };
  };
}
