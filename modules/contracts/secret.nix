{ pkgs, lib, ... }:
let
  inherit (lib) concatStringsSep literalMD mkOption optionalAttrs optionalString;
  inherit (lib.types) anything listOf submodule str;

  contractsLib = import ./default.nix { inherit pkgs lib; };

  mkRequest =
    { mode ? "0400",
      owner ? "root",
      ownerText ? null,
      group ? "root",
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

      defaultText = optionalString (ownerText != null || restartUnitsText != null) (literalMD ''
      {
        mode = ${mode};
        owner = ${if ownerText != null then ownerText else owner};
        group = ${group};
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
in
contractsLib.mkContractFunctions {
  inherit mkRequest mkResult;
}
