{ config, pkgs, lib, ... }:

let
  cfg = config.shb.zfs;
in
{
  options.shb.zfs = {
    defaultPoolName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "ZFS pool name datasets should be created on if no pool name is given in the dataset.";
    };

    datasets = lib.mkOption {
      description = ''
        ZFS Datasets.

        Each entry in the attrset will be created and mounted in the given path.
        The attrset name is the dataset name.

        This block implements the following contracts:
          - mount
      '';
      default = {};
      example = lib.literalExpression ''
        shb.zfs."safe/postgresql".path = "/var/lib/postgresql";
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "shb.zfs.datasets";

          poolName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "ZFS pool name this dataset should be created on. Overrides the defaultPoolName.";
          };

          path = lib.mkOption {
            type = lib.types.str;
            description = "Path this dataset should be mounted on.";
          };
        };
      });
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.any (x: x.poolName == null) (lib.mapAttrsToList (n: v: v) cfg.datasets) -> cfg.defaultPoolName != null;
        message = "Cannot have both datasets.poolName and defaultPoolName set to null";
      }
    ];

    system.activationScripts = lib.mapAttrs' (name: cfg':
      let
        dataset = (if cfg'.poolName != null then cfg'.poolName else cfg.defaultPoolName) + "/" + name;
      in
      lib.attrsets.nameValuePair "zfsCreate-${name}" {
        text = ''
          ${pkgs.zfs}/bin/zfs list ${dataset} > /dev/null 2>&1 \
            || ${pkgs.zfs}/bin/zfs create \
               -o mountpoint=none \
               ${dataset} || :

          [ "$(${pkgs.zfs}/bin/zfs get -H mountpoint -o value ${dataset})" = ${cfg'.path} ] \
            || ${pkgs.zfs}/bin/zfs set \
               mountpoint=${cfg'.path} \
               ${dataset}
        '';
      }) cfg.datasets;
  };
}
