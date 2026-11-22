{
  lib,
  config,
  pkgs,
  shb,
  ...
}:
let
  mkContract =
    contractDef:
    # pass through extra attributes to the contract object
    (contractDef.passthru or { })
    // {

      link =
        requestsList:
        lib.mkMerge (
          lib.map (value: {
            "${lib.strings.sanitizeDerivationName value.requesterPath}" = value;
          }) requestsList
        );
      register =
        providersList:
        lib.groupBy (p: p.requesterPath) (lib.filter (p: p.requesterPath != null) providersList);
      mkProvider =
        providerDef:
        lib.types.submodule (
          { options, ... }: {
            imports = [
              providerDef
            ];
            options = {
              providerPath = lib.mkOption {
                internal = true;
                description = "Path of the provider, used for error messages";
                type = lib.types.str;
                readOnly = true;
                default = lib.showOption (lib.init options.providerPath.loc);
              };
              requesterPath = lib.mkOption {
                internal = true;
                description = "Path of the requester, used to locate the result";
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              request = lib.mkOption {
                description = "The request data, filled by the requester";
                type = lib.types.submodule (
                  {
                    lib,
                    name,
                    options,
                    ...
                  }:
                  {
                    options = contractDef.request { inherit lib name options; };
                  }
                );
              };
              result = lib.mkOption {
                description = "The result data";
                type = lib.types.submodule (
                  {
                    lib,
                    name,
                    options,
                    ...
                  }:
                  {
                    options = contractDef.result { inherit lib name options; };
                  }
                );
                apply = _: options.result.type.merge options.result.loc [ ]; # to prevent the provider's result being assigned here
              };
            };
          }
        );

      mkRequester =
        defaults:
        (lib.types.submodule (
          args@{ ... }:
          {
            options = {
              requesterPath = lib.mkOption {
                internal = true;
                description = "Path of the requester, used to locate the result";
                type = lib.types.str;
                readOnly = true;
                default =
                  let
                    loc = lib.init args.options.request.loc;
                  in
                  if loc == [ ] then
                    throw ''
                      A contract requester was accessed but has no default.
                      Add `default = { };` to the option declaring it (the one using `mkRequester` as its type).
                    ''
                  else
                    lib.showOption loc;
              };
              request = lib.mkOption {
                description = "The request data, filled by the requester";
                default = { };
                type = lib.types.submodule (
                  let
                    # To allow the request to specify defaults, that will automatically
                    # end up in the doc (or else show the contract defaults)
                    withDefaults =
                      options: defaults:
                      lib.mapAttrs (
                        n: o:
                        if !(defaults ? ${n}) then
                          o
                        else if lib.isOption o then
                          o // { default = defaults.${n}; }
                        else
                          withDefaults o defaults.${n}
                      ) options;
                  in
                  {
                    lib,
                    name,
                    options,
                    ...
                  }:
                  {
                    options = withDefaults (contractDef.request { inherit lib name options; }) defaults;
                  }
                );
              };

              result = lib.mkOption {
                internal = true;
                description = "The result data";
                type = lib.types.uniq (
                  lib.types.submodule (
                    {
                      lib,
                      name,
                      options,
                      ...
                    }:
                    {
                      options = contractDef.result { inherit lib name options; };
                    }
                  )
                );
              };
            };
            config.result =
              let
                linked = config.shb.contractResults.${args.config.requesterPath} or [ ];
              in
              if lib.length linked > 1 then
                throw "The option `${args.config.requesterPath}' is linked to multiple providers: ${
                  lib.concatMapStringsSep ", " (p: p.providerPath) linked
                }"
              else if lib.length linked == 0 then
                throw "The option `${args.config.requesterPath}' is not linked to any provider"
              else
                (lib.head linked).result;
          }
        ));

    };
in

{
  options.shb.contractResults = lib.mkOption {
    internal = true;
    type = lib.types.lazyAttrsOf (lib.types.listOf lib.types.raw);
    default = { };
  };

  config._module.args.shbContracts =
    lib.mapAttrs (_: file: mkContract (import file { inherit lib shb pkgs; }))
      {
        secret = ./secret.nix;
        ssl = ./ssl.nix;
        backup = ./backup.nix;
        databasebackup = ./databasebackup.nix;
        datasetbackup = ./datasetbackup.nix;
      };

}
