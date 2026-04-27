# ZFS Block {#blocks-zfs}

Defined in [`/modules/blocks/zfs.nix`](@REPO@/modules/blocks/zfs.nix):

```nix
{
  inputs,
  ...
}:
{
  imports = [
    inputs.selfhostblocks.nixosModules.zfs
  ];
}
```

This block creates ZFS datasets, optionally mounts them and sets permissions on the mount point.

## Features {#blocks-zfs-features}

- Creates ZFS dataset which is [optionally mounted](#blocks-zfs-options-shb.zfs.pools._name_.datasets._name_.path).
- Sets permissions, [owner](#blocks-zfs-options-shb.zfs.pools._name_.datasets._name_.owner), [group](#blocks-zfs-options-shb.zfs.pools._name_.datasets._name_.group) and [ACL](#blocks-zfs-options-shb.zfs.pools._name_.datasets._name_.defaultACLs) on the mount point.
- Backup of the files in the dataset [`shb.zfs.<name>.backup`][backup] through the [backup contract](./contracts-backup.html).
- Backup of the dataset itself [`shb.zfs.<name>.datasetbackup`][datasetbackup] through the [dataset backup contract](./contracts-datasetbackup.html).

[backup]: #blocks-zfs-options-shb.zfs.pools._name_.datasets._name_.backup
[datasetbackup]: #blocks-zfs-options-shb.zfs.pools._name_.datasets._name_.datasetbackup

## Usage {#blocks-zfs-usage}

Create a dataset at `root/safe/users` mounted on `/var/lib/nixos`:

```nix
shb.zfs.pools.root.datasets."safe/users".path = "/var/lib/nixos";
```

Create a dataset at `backup/syncoid` but do not mount it:

```nix
shb.zfs.pools.backup.datasets."syncoid".path = "none";
```

Create a dataset at `root/syncthing` and set custom permissions and ACL.
Permission and ACL are only enforced for the mount point.

```nix
shb.zfs.pools.root.datasets."syncthing" = {
  path = "/srv/syncthing";

  mode = "ug=rwx,g+s,o=";
  owner = "syncthing";
  group = "syncthing";
  defaultACLs = "g:syncthing:rwX";
};
```

### Backup dataset {#blocks-zfs-usage-backup-dataset}

To backup the dataset directly, use the [dataset backup contract](contracts-datasetbackup.html).
For example, with the sanoid module as the dataset backup contract provider:

```nix
{
  shb.zfs.pools.root.datasets.home = {
    path = "/home";
  };

  shb.sanoid.backup."root/home" = {
    request = shb.zfs.pools.root.datasets.home.datasetBackup.request;
    template = "yearly";
  };
}
```

See the [Sanoid block](blocks-sanoid.html) for more examples.

### Backup files {#blocks-zfs-usage-backup-files}

To backup the files in the dataset, use the [file backup contract](contracts-backup.html).
For example, with the restic module as the file backup contract provider:

```nix
{
  shb.zfs.pools.root.datasets.home = {
    path = "/home";
  };

  shb.restic.instances."myservice" = {
    request = shb.zfs.pools.root.datasets.home.backup.request;
  };
}
```

See the [Restic block](blocks-restic.html) for more examples.

## Options Reference {#blocks-zfs-options}

```{=include=} options
id-prefix: blocks-zfs-options-
list-id: selfhostblocks-block-zfs-options
source: @OPTIONS_JSON@
```
