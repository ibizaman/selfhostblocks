{
  shb,
  pkgs,
  lib,
  ...
}:
{
  sanoid = shb.contracts.test.datasetbackup {
    name = "sanoid";
    providerRoot = [
      "shb"
      "sanoid"
      "backup"
      # The job label must differ from the requested dataset.
      "testjob"
    ];
    modules = [
      ../../modules/blocks/sanoid.nix
      # We use the zfs module to test the sanoid one
      ../../modules/blocks/zfs.nix
    ];
    settings =
      { ... }:
      {
        useTemplate = [ "test" ];
      };
    extraConfig =
      { config, filesRoot, ... }:
      {
        shb.sanoid.backup.testjob.request =
          lib.mkForce config.shb.zfs.pools.root.datasets.mytest.datasetbackup.request;
        # Inspiration from https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/zfs.nix
        networking.hostId = "deadbeef";
        boot.supportedFilesystems = [ "zfs" ];

        virtualisation = {
          emptyDiskImages = [
            512
          ];
        };

        # The test expects to keep one snapshot per hour.
        services.sanoid.templates."test" = {
          hourly = 1;
          daily = 0;
          monthly = 0;
          yearly = 0;
        };

        systemd.services."zfs-zpool-create" = {
          serviceConfig.Type = "oneshot";
          unitConfig.DefaultDependencies = false;
          after = [ "systemd-modules-load.service" ];
          requiredBy = [
            "zfs-import-root.service"
            "zfs-mount.service"
          ];
          before = [
            "zfs-import-root.service"
            "zfs-mount.service"
          ];
          script = ''
            ${pkgs.zfs}/bin/zpool create -m none -O acltype=posixacl -O mountpoint=none root /dev/vdb
          '';
        };

        shb.zfs.pools.root.datasets."mytest" = {
          path = filesRoot;
        };
      };
  };
}
