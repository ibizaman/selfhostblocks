{ config, options, lib, pkgs, ... }:
let
  cfg = config.shb.hardcodedsecret;
  opt = options.shb.hardcodedsecret;

  inherit (lib) mapAttrs' mkOption nameValuePair;
  inherit (lib.types) attrsOf listOf path str submodule;
  inherit (pkgs) writeText;
in
{
  options.shb.hardcodedsecret = mkOption {
    default = {};
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
          type = str;
          description = ''
            Content of the secret.

            This will be stored in the nix store and should only be used for testing or maybe in dev.
          '';
        };
      };
    }));
  };

  config = {
    system.activationScripts = mapAttrs' (n: cfg':
      let
        content' = writeText "hardcodedsecret_${n}_content" cfg'.content;
      in
        nameValuePair "hardcodedsecret_${n}" ''
          mkdir -p "$(dirname "${cfg'.path}")"
          touch "${cfg'.path}"
          chmod ${cfg'.mode} "${cfg'.path}"
          chown ${cfg'.owner}:${cfg'.group} "${cfg'.path}"
          cp ${content'} "${cfg'.path}"
        ''
    ) cfg;
  };
}
