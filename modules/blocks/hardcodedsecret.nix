{ config, options, lib, pkgs, ... }:
let
  cfg = config.shb.hardcodedsecret;
  opt = options.shb.hardcodedsecret;

  inherit (lib) mapAttrs' mkOption nameValuePair;
  inherit (lib.types) attrsOf listOf path nullOr str submodule;
  inherit (pkgs) writeText;
in
{
  options.shb.hardcodedsecret = mkOption {
    default = {};
    description = ''
      Hardcoded secrets. These should only be used in tests.
    '';
    example = lib.literalExpression ''
    {
      mySecret = {
        user = "me";
        mode = "0400";
        restartUnits = [ "myservice.service" ];
        content = "My Secrets";
      };
    }
    '';
    type = attrsOf (submodule ({ name, ... }: {
      options = {
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
          default = [];
        };

        path = mkOption {
          type = path;
          description = ''
            Path to the file containing the secret generated out of band.

            This path will exist after deploying to a target host,
            it is not available through the nix store.
          '';
          default = "/run/hardcodedsecrets/hardcodedsecret_${name}";
        };

        content = mkOption {
          type = nullOr str;
          description = ''
            Content of the secret.

            This will be stored in the nix store and should only be used for testing or maybe in dev.
          '';
          default = null;
        };

        source = mkOption {
          type = nullOr str;
          description = ''
            Source of the content of the secret.
          '';
          default = null;
        };
      };
    }));
  };

  config = {
    system.activationScripts = mapAttrs' (n: cfg':
      let
        source = if cfg'.source != null
                 then cfg'.source
                 else writeText "hardcodedsecret_${n}_content" cfg'.content;
      in
        nameValuePair "hardcodedsecret_${n}" ''
          mkdir -p "$(dirname "${cfg'.path}")"
          touch "${cfg'.path}"
          chmod ${cfg'.mode} "${cfg'.path}"
          chown ${cfg'.owner}:${cfg'.group} "${cfg'.path}"
          cp ${source} "${cfg'.path}"
        ''
    ) cfg;
  };
}
