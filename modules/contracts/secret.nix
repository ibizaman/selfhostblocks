{ lib, ... }:
{
  mkOption =
    { description,
      mode ? "0400",
      owner ? "root",
      ownerText ? null,
      group ? "root",
      restartUnits ? [],
      restartUnitsText ? null,
    }: lib.mkOption {
      inherit description;

      type = lib.types.submodule {
        options = {
          request = lib.mkOption {
            default = {
              inherit mode owner group restartUnits;
            };

            defaultText = lib.optionalString (ownerText != null || restartUnitsText != null) (lib.literalMD ''
            {
              mode = ${mode};
              owner = ${if ownerText != null then ownerText else owner};
              group = ${group};
              restartUnits = ${if restartUnitsText != null then restartUnitsText else "[ " + lib.concatStringsSep " " restartUnits + " ]"};
            }
            '');

            readOnly = true;

            description = ''
              Options set by the requester module
              enforcing some properties the secret should have.

              Use the `contracts.secret.mkOption` function to
              create a secret option for a requester module.
              See the [requester usage section](contracts-secret.html#secret-contract-usage-requester) for an example.

              Some providers will need more options to be defined and this is allowed.
              These extra options will be set by the user.
              For example, the `sops` implementation requires to be given
              the sops key in which the secret is encrypted.

              `request` options are set read-only
              because they must be set through option defaults,
              they shouldn't be changed in the `config` section.
              This would otherwise lead to infinite recursion
              during evaluation.
              This is handled automatically when using the `contracts.secret.mkOption` function.
            '';
            type = lib.types.submodule {
              freeformType = lib.types.anything;

              options = {
                mode = lib.mkOption {
                  description = ''
                    Mode of the secret file.
                  '';
                  type = lib.types.str;
                  default = mode;
                };

                owner = lib.mkOption {
                  description = ''
                    Linux user owning the secret file.
                  '';
                  type = lib.types.str;
                  default = owner;
                  defaultText = if ownerText != null then lib.literalMD ownerText else null;
                };

                group = lib.mkOption {
                  description = ''
                    Linux group owning the secret file.
                  '';
                  type = lib.types.str;
                  default = group;
                };

                restartUnits = lib.mkOption {
                  description = ''
                    Systemd units to restart after the secret is updated.
                  '';
                  type = lib.types.listOf lib.types.str;
                  default = restartUnits;
                  defaultText = if restartUnitsText != null then lib.literalMD restartUnitsText else null;
                };
              };
            };
          };

          result = lib.mkOption {
            description = ''
              Options set by the provider module that indicates where the secret can be found.
            '';
            type = lib.types.submodule {
              options = {
                path = lib.mkOption {
                  type = lib.types.path;
                  description = ''
                    Path to the file containing the secret generated out of band.

                    This path will exist after deploying to a target host,
                    it is not available through the nix store.
                  '';
                };
              };
            };
          };
        };
      };
    };
}
