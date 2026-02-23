{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    nullOr
    submodule
    str
    ;
in
{
  mkRequest =
    {
      serviceName ? "",
      externalUrl ? "",
      externalUrlText ? null,
      internalUrl ? null,
      internalUrlText ? null,
      apiKey ? null,
    }:
    mkOption {
      description = ''
        Request part of the dashboard contract.
      '';
      default = { };
      type = submodule {
        options = {
          externalUrl =
            mkOption {
              description = ''
                URL at which the service can be accessed.

                This URL should go through the reverse proxy.
              '';
              type = str;
              default = externalUrl;
              example = "https://jellyfin.example.com";
            }
            // (lib.optionalAttrs (externalUrlText != null) {
              defaultText = externalUrlText;
            });

          internalUrl =
            mkOption {
              description = ''
                URL at which the service can be accessed directly.

                This URL should bypass the reverse proxy.
                It can be used for example to ping the service
                and making sure it is up and running correctly.
              '';
              type = nullOr str;
              default = internalUrl;
              example = "http://127.0.0.1:8081";
            }
            // (lib.optionalAttrs (internalUrlText != null) {
              defaultText = internalUrlText;
            });
        };
      };
    };

  mkResult =
    {
    }:
    mkOption {
      description = ''
        Result part of the dashboard contract.

        No option is provided here.
      '';
      default = { };
      type = submodule {
        options = {
        };
      };
    };
}
