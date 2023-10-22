{ config, pkgs, lib, ... }:

let
  cfg = config.shb.davfs;

  template = file: newPath: replacements:
    let
      templatePath = newPath + ".template";

      sedPatterns = lib.strings.concatStringsSep " " (lib.attrsets.mapAttrsToList (from: to: "\"s|${from}|${to}|\"") replacements);
    in
      ''
      ln -fs ${file} ${templatePath}
      rm ${newPath} || :
      sed ${sedPatterns} ${templatePath} > ${newPath}
      '';
in
{
  options.shb.davfs = {
    mounts = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          remoteUrl = lib.mkOption {
            type = lib.types.str;
            description = "Webdav endpoint to connect to.";
            example = "https://my.domain.com/dav";
          };

          mountPoint = lib.mkOption {
            type = lib.types.str;
            description = "Mount point to mount the webdav endpoint on.";
            example = "/mnt";
          };

          username = lib.mkOption {
            type = lib.types.str;
            description = "Username to connect to the webdav endpoint.";
          };

          passwordFile = lib.mkOption {
            type = lib.types.str;
            description = "Password to connect to the webdav endpoint.";
          };

          uid = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            description = "User owner of the mount point.";
            example = 1000;
            default = null;
          };

          gid = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            description = "Group owner of the mount point.";
            example = 1000;
            default = null;
          };

          fileMode = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "File creation mode";
            example = "0664";
            default = null;
          };

          directoryMode = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Directory creation mode";
            example = "2775";
            default = null;
          };

          automount = lib.mkOption {
            type = lib.types.bool;
            description = "Create a systemd automount unit";
            default = true;
          };
        };
      });
    };
  };

  config = {
    services.davfs2.enable = builtins.length cfg.mounts > 0;

    systemd.mounts =
      let
        mkMountCfg = c: {
          enable = true;
          description = "Webdav mount point";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];

          what = c.remoteUrl;
          where = c.mountPoint;
          options = lib.concatStringsSep "," (
            (lib.optional (!(isNull c.uid)) "uid=${toString c.uid}")
            ++ (lib.optional (!(isNull c.gid)) "gid=${toString c.uid}")
            ++ (lib.optional (!(isNull c.fileMode)) "file_mode=${toString c.fileMode}")
            ++ (lib.optional (!(isNull c.directoryMode)) "dir_mode=${toString c.directoryMode}")
          );
          type = "davfs";
          mountConfig.TimeoutSet = 15;
        };
      in
        map mkMountCfg cfg.mounts;
  };
}
