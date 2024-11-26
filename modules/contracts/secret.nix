{ pkgs, lib, ... }:
let
  inherit (lib) concatStringsSep literalMD mkOption optionalAttrs optionalString;
  inherit (lib.types) listOf submodule str;

  shblib = pkgs.callPackage ../../lib {};
  inherit (shblib) anyNotNull;
in
{
  mkRequest =
    { mode ? "0400",
      modeText ? null,
      owner ? "root",
      ownerText ? null,
      group ? "root",
      groupText ? null,
      restartUnits ? [],
      restartUnitsText ? null,
    }: mkOption {
      description = ''
        Request part of the secret contract.

        Options set by the requester module
        enforcing some properties the secret should have.
      '';

      default = {
        inherit mode owner group restartUnits;
      };

      defaultText = optionalString (anyNotNull [
        modeText
        ownerText
        groupText
        restartUnitsText
      ]) (literalMD ''
      {
        mode = ${if modeText != null then modeText else mode};
        owner = ${if ownerText != null then ownerText else owner};
        group = ${if groupText != null then groupText else group};
        restartUnits = ${if restartUnitsText != null then restartUnitsText else "[ " + concatStringsSep " " restartUnits + " ]"};
      }
      '');

      type = submodule {
        options = {
          mode = mkOption {
            description = ''
              Mode of the secret file.
            '';
            type = str;
            default = mode;
          } // optionalAttrs (modeText != null) {
            defaultText = literalMD modeText;
          };

          owner = mkOption ({
            description = ''
              Linux user owning the secret file.
            '';
            type = str;
            default = owner;
          } // optionalAttrs (ownerText != null) {
            defaultText = literalMD ownerText;
          });

          group = mkOption {
            description = ''
              Linux group owning the secret file.
            '';
            type = str;
            default = group;
          } // optionalAttrs (groupText != null) {
            defaultText = literalMD groupText;
          };

          restartUnits = mkOption ({
            description = ''
              Systemd units to restart after the secret is updated.
            '';
            type = listOf str;
            default = restartUnits;
          } // optionalAttrs (restartUnitsText != null) {
            defaultText = literalMD restartUnitsText;
          });
        };
      };
    };

  mkResult =
    {
      path ? "/run/secrets/secret",
      pathText ? null,
    }:
    mkOption ({
      description = ''
        Result part of the secret contract.

        Options set by the provider module that indicates where the secret can be found.
      '';
      default = {
        inherit path;
      };
      type = submodule {
        options = {
          path = mkOption {
            type = lib.types.path;
            description = ''
              Path to the file containing the secret generated out of band.

              This path will exist after deploying to a target host,
              it is not available through the nix store.
            '';
            default = path;
          } // optionalAttrs (pathText != null) {
            defaultText = pathText;
          };
        };
      };
    } // optionalAttrs (pathText != null) {
      defaultText = {
        path = pathText;
      };
    });
}
