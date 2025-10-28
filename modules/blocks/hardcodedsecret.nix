{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.shb.hardcodedsecret;

  contracts = pkgs.callPackage ../contracts { };

  inherit (lib) mapAttrs' mkOption nameValuePair;
  inherit (lib.types)
    attrsOf
    nullOr
    str
    submodule
    ;
  inherit (pkgs) writeText;
in
{
  options.shb.hardcodedsecret = mkOption {
    default = { };
    description = ''
      Hardcoded secrets. These should only be used in tests.
    '';
    example = lib.literalExpression ''
      {
        mySecret = {
          request = {
            user = "me";
            mode = "0400";
            restartUnits = [ "myservice.service" ];
          };
          settings.content = "My Secret";
        };
      }
    '';
    type = attrsOf (
      submodule (
        { name, ... }:
        {
          options = contracts.secret.mkProvider {
            settings = mkOption {
              description = ''
                Settings specific to the hardcoded secret module.

                Give either `content` or `source`.
              '';

              type = submodule {
                options = {
                  content = mkOption {
                    type = nullOr str;
                    description = ''
                      Content of the secret as a string.

                      This will be stored in the nix store and should only be used for testing or maybe in dev.
                    '';
                    default = null;
                  };

                  source = mkOption {
                    type = nullOr str;
                    description = ''
                      Source of the content of the secret as a path in the nix store.
                    '';
                    default = null;
                  };
                };
              };
            };

            resultCfg = {
              path = "/run/hardcodedsecrets/hardcodedsecret_${name}";
            };
          };
        }
      )
    );
  };

  config = {
    system.activationScripts = mapAttrs' (
      n: cfg':
      let
        source =
          if cfg'.settings.source != null then
            cfg'.settings.source
          else
            writeText "hardcodedsecret_${n}_content" cfg'.settings.content;
      in
      nameValuePair "hardcodedsecret_${n}" ''
        mkdir -p "$(dirname "${cfg'.result.path}")"
        touch "${cfg'.result.path}"
        chmod ${cfg'.request.mode} "${cfg'.result.path}"
        chown ${cfg'.request.owner}:${cfg'.request.group} "${cfg'.result.path}"
        cp ${source} "${cfg'.result.path}"
      ''
    ) cfg;
  };
}
