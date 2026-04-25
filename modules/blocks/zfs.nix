{
  config,
  pkgs,
  lib,
  shb,
  utils,
  ...
}:

let
  cfg = config.shb.zfs;
in
{
  imports = [
    ../../lib/module.nix
  ];

  options.shb.zfs = {
    pools = lib.mkOption {
      description = ''
        Attrset of ZFS pools under which datasets will be created.

        The ZFS pools are not managed by this module, they should already exist.

        Each pool named here will be added to the [`boot.zfs.extraPools`](https://search.nixos.org/options?channel=unstable&include_modular_service_options=0&include_nixos_options=1&query=boot.zfs.extrapools&show=option:boot.zfs.extraPools) option.
      '';
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            datasets = lib.mkOption {
              description = ''
                ZFS Datasets.

                Each entry in the attrset will be created and mounted in the given path.
                The attrset name is the dataset name.

                This block implements the following contracts:
                  - mount
              '';
              default = { };
              example = lib.literalExpression ''
                shb.zfs."safe/postgresql".path = "/var/lib/postgresql";
              '';
              type = lib.types.attrsOf (
                lib.types.submodule (
                  { config, name, ... }:
                  {
                    options = {
                      enable = lib.mkEnableOption "shb.zfs.datasets";

                      path = lib.mkOption {
                        type = lib.types.str;
                        description = "Path this dataset should be mounted on. If the string 'none' is given, the dataset will not be mounted.";
                      };

                      mode = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        description = "If non null, unix mode to apply to the dataset root folder.";
                        default = null;
                        example = "ug=rwx,g+s";
                      };

                      owner = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        description = "If non null, unix user to apply to the dataset root folder.";
                        default = null;
                        example = "syncthing";
                      };

                      group = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        description = "If non null, unix group to apply to the dataset root folder.";
                        default = null;
                        example = "syncthing";
                      };

                      defaultACLs = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        description = ''
                          If non null, default ACL to set on the dataset root folder.

                          Executes "setfacl -d -m $acl $path"
                        '';
                        default = null;
                        example = "g:syncthing:rwX";
                      };

                      after = lib.mkOption {
                        type = lib.types.listOf lib.types.str;
                        description = ''
                          Order creating this dataset after the mentioned ones.
                          This only works with datasets managed by this module.

                          Use the name of the dataset without the pool name.
                        '';
                        default = [ ];
                        example = lib.literalExpression ''
                          [
                            "backup"
                          ]
                        '';
                      };

                      backup = lib.mkOption {
                        description = ''
                          Backup contract consumer configuration.

                          This contract will backup the files inside the dataset.
                        '';
                        type = lib.types.submodule {
                          options = shb.contracts.backup.mkRequester {
                            user = if config.owner == null then "root" else config.owner;
                            sourceDirectories = [
                              config.path
                            ];
                            sourceDirectoriesText = ''
                              [
                                shb.zfs.pools.<name>.datasets.<name>.path
                              ]
                            '';
                          };
                        };
                      };

                      datasetbackup = lib.mkOption {
                        description = ''
                          ZFS dataset backup contract configuration.

                          This contract will take snaphots of the dataset.
                        '';
                        type = lib.types.submodule {
                          options = shb.contracts.datasetbackup.mkRequester {
                            dataset = name;
                          };
                        };
                      };
                    };
                  }
                )
              );
            };
          };
        }

      );
    };
  };

  # The implementation is greatly inspired by https://discourse.nixos.org/t/configure-zfs-filesystems-after-install/48633/3
  config = {
    boot.zfs.extraPools = lib.uniqueStrings (builtins.attrNames cfg.pools);

    systemd.services =
      let
        mkPool =
          poolName: poolCfg: lib.listToAttrs (lib.mapAttrsToList (mkDataset poolName) poolCfg.datasets);

        mkDataset =
          poolName: name: cfg':
          let
            dataset = poolName + "/" + name;
          in
          lib.attrsets.nameValuePair "zfs-create-${utils.escapeSystemdPath dataset}" {
            # oneshot is used to make the systemd service wait on completion of the script.
            serviceConfig.Type = "oneshot";
            unitConfig.DefaultDependencies = false;
            requiredBy = [ "local-fs.target" ];
            before = [ "local-fs.target" ];
            after = [
              "zfs-import-${poolName}.service"
              "zfs-mount.service"
            ]
            ++ map (n: "zfs-create-${poolName}-${n}.service") cfg'.after;

            unitConfig.ConditionPathIsMountPoint = lib.mkIf (cfg'.path != "none") "!${cfg'.path}";

            script = ''
              ${pkgs.zfs}/bin/zfs list ${dataset} > /dev/null 2>&1 \
                || ${pkgs.zfs}/bin/zfs create \
                   -o mountpoint=none \
                   ${dataset} || :

              [ "$(${pkgs.zfs}/bin/zfs get -H mountpoint -o value ${dataset})" = ${cfg'.path} ] \
                || ${pkgs.zfs}/bin/zfs set \
                   mountpoint="${cfg'.path}" \
                   ${dataset}

            ''
            + lib.optionalString (cfg'.path != "none" && cfg'.mode != null) ''
              chmod "${cfg'.mode}" "${cfg'.path}"
            ''
            + lib.optionalString (cfg'.path != "none" && cfg'.owner != null) ''
              chown "${cfg'.owner}" "${cfg'.path}"
            ''
            + lib.optionalString (cfg'.path != "none" && cfg'.group != null) ''
              chown :"${cfg'.group}" "${cfg'.path}"
            ''
            + lib.optionalString (cfg'.path != "none" && cfg'.defaultACLs != null) ''
              ${pkgs.acl}/bin/setfacl -d -m "${cfg'.defaultACLs}" "${cfg'.path}"
            '';
          };
        mergeAttrs = lib.foldl lib.mergeAttrs { };
      in
      mergeAttrs (lib.mapAttrsToList mkPool cfg.pools);
  };
}
