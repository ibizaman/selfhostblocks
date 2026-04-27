# Sanoid Block {#blocks-sanoid}

Defined in [`/modules/blocks/sanoid.nix`](@REPO@/modules/blocks/sanoid.nix):

```nix
{
  imports = [
    inputs.selfhostblocks.nixosModules.sanoid
  ];
}
```

## Provider Contracts {#blocks-sanoid-contract-provider}

This block provides the following contracts:

- [dataset backup contract](contracts-datasetbackup.html) under the [`shb.sanoid.backup`][backup] option.
  It is tested with the [generic contract tests][backup contract tests].

[backup]: #blocks-sanoid-options-shb.sanoid.backup
[backup contract tests]: @REPO@/test/contracts/backup.nix

## Usage {#blocks-sanoid-usage}

Sanoid uses templates to know when snapshots should be kept or pruned.

### Default Template {#blocks-sanoid-usage-default-template}

Backup a dataset using the default Sanoid template:

```nix
{
  shb.zfs.pools.root.datasets.home = {
    path = "/home";
  };

  shb.sanoid.backup."root/home" = {
    request = shb.zfs.pools.root.datasets.home.datasetBackup.request;
  };
}
```

This uses the dataset backup contract which is exposed through the ZFS module's [`shb.zfs.pools.<name>.datasets.<name>.datasetBackup`](blocks-zfs.html#blocks-zfs-options-shb.zfs.pools._name_.datasets._name_.datasetbackup) option.

### Custom Template {#blocks-sanoid-usage-custom-template}

Create a custom template and use it:

```nix
{
  shb.zfs.pools.root.datasets.home = {
    path = "/home";
  };

  services.sanoid.templates."yearly" = {
    hourly = 10;
    daily = 3;
    monthly = 3;
    yearly = 2;
  };

  shb.sanoid.backup."root/home" = {
    request = shb.zfs.pools.root.datasets.home.datasetBackup.request;
    template = "yearly";
  };
}
```

Note we use the upstream `services.sanoid.templates` option to define the templates.

### Without contract {#blocks-sanoid-usage-without-contract}

To backup a dataset that does not provide the dataset backup contract,
we can just set the request manually:

```nix
{
  shb.zfs.pools.root.datasets.home = {
    path = "/home";
  };

  shb.sanoid.backup."root/home" = {
    request.dataset = "root/home";
  };
}
```

Note the attr name under the `shb.sanoid.backup` option does not
set the dataset name.

## Options Reference {#blocks-sanoid-options}

```{=include=} options
id-prefix: blocks-sanoid-options-
list-id: selfhostblocks-blocks-sanoid-options
source: @OPTIONS_JSON@
```
