{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mapAttrs mkOption;
  inherit (lib.types) attrsOf anything submodule;

  contracts = pkgs.callPackage ../contracts { };

  cfg = config.shb.sops;
in
{
  options.shb.sops = {
    secret = mkOption {
      description = "Secret following the [secret contract](./contracts-secret.html).";
      default = { };
      type = attrsOf (
        submodule (
          { name, options, ... }:
          {
            options = contracts.secret.mkProvider {
              settings = mkOption {
                description = ''
                  Settings specific to the Sops provider.

                  This is a passthrough option to set [sops-nix options](https://github.com/Mic92/sops-nix/blob/master/modules/sops/default.nix).

                  Note though that the `mode`, `owner`, `group`, and `restartUnits`
                  are managed by the [shb.sops.secret.<name>.request](#blocks-sops-options-shb.sops.secret._name_.request) option.
                '';

                type = attrsOf anything;
                default = { };
              };

              resultCfg = {
                path = "/run/secrets/${name}";
                pathText = "/run/secrets/<name>";
              };
            };
          }
        )
      );
    };
  };

  config = {
    sops.secrets =
      let
        mkSecret = n: secretCfg: secretCfg.request // secretCfg.settings;
      in
      mapAttrs mkSecret cfg.secret;
  };
}
