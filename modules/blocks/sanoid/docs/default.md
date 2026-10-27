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
[backup contract tests]: @REPO@/test/contracts/datasetbackup.nix

## Usage {#blocks-sanoid-usage}

Sanoid uses templates to know when snapshots should be kept or pruned.

Each job must explicitly set `request.dataset`, including the pool name, either directly or through a ZFS dataset's `datasetbackup.request`. The job's attribute name identifies its restore command; it does not select the dataset. Only one job may target a given dataset, so combine its retention settings in that job. All jobs share `sanoid.service`.

**Migration:** Configurations that previously selected a dataset solely with a key such as `shb.sanoid.backup."root/home"` must add `request.dataset = "root/home";` or connect the ZFS request as shown below. Existing job keys can stay unchanged, preserving restore command names. File-backup request fields such as `sourceDirectories` are not supported by this dataset provider.

### Default Template {#blocks-sanoid-usage-default-template}

Backup a dataset using the default Sanoid template:

```nix
{ config, ... }:
{
  shb.zfs.pools.root.datasets.home = {
    path = "/home";
  };

  shb.sanoid.backup.home = {
    request = config.shb.zfs.pools.root.datasets.home.datasetbackup.request;
  };
}
```

This uses the dataset backup contract which is exposed through the ZFS module's [`shb.zfs.pools.<name>.datasets.<name>.datasetbackup`](blocks-zfs.html#blocks-zfs-options-shb.zfs.pools._name_.datasets._name_.datasetbackup) option.

### Custom Template {#blocks-sanoid-usage-custom-template}

Create a custom template and use it:

```nix
{ config, ... }:
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

  shb.sanoid.backup.home = {
    request = config.shb.zfs.pools.root.datasets.home.datasetbackup.request;
    settings.useTemplate = [ "yearly" ];
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

## Best Practices {#blocks-sanoid-best-pactices}

Let's assume you have a few datasets you want to backup on one hard drive,
say `root/safe/home` and `data/nextcloud` and
and a destination dataset on a second hard drive where backups will be sent for replication, say `backup/syncoid`.

The following configuration creates a new snapshot every hour on the `root/safe/home` and `data/nextcloud` dataset and keeps:

- the last 5 hourly snapshots
- one snapshot per day for the last 10 days
- one snapshot per month for the last 15 months
- one snapshot per year for the last 20 years

The same configuration is set for the `backup/syncoid` dataset.

```nix
{ config, ... }:
{
  services.sanoid = {
    enable = true;
    templates.main = {
      autosnap = true;
      autoprune = true;
      hourly = 5;
      daily = 10;
      monthly = 15;
      yearly = 20;
    };
    templates.backup = {
      autosnap = false;
      autoprune = true;
      hourly = 5;
      daily = 10;
      monthly = 15;
      yearly = 20;
    };
  };

  shb.zfs.pools.data.datasets."nextcloud".path = "/var/lib/nextcloud";
  shb.sanoid.backup."data/nextcloud" = {
    request = config.shb.zfs.pools.data.datasets."nextcloud".datasetbackup.request;
    settings.useTemplate = [ "main" ];
  };

  shb.zfs.pools.root.datasets."safe/home".path = "/home";
  shb.sanoid.backup."root/safe/home" = {
    request = config.shb.zfs.pools.root.datasets."safe/home".datasetbackup.request;
    settings.useTemplate = [ "main" ];
  };

  services.syncoid = {
    enable = true;

    commands."root/safe/home" = {
      recursive = true;
      target = "backup/syncoid/root/safe/home";
      extraArgs = [
        "--create-bookmark"
        "--no-sync-snap"
      ];
    };

    commands."data/nextcloud" = {
      recursive = true;
      target = "backup/syncoid/data/nextcloud";
      extraArgs = [
        "--create-bookmark"
        "--no-sync-snap"
      ];
    };
  };

  shb.zfs.pools.backup.datasets."syncoid".path = "none";
  shb.sanoid.backup."backup/syncoid" = {
    request = config.shb.zfs.pools.backup.datasets."syncoid".datasetbackup.request;
    settings.useTemplate = [ "backup" ];
  };
}
```

## Options Reference {#blocks-sanoid-options}

```{=include=} options
id-prefix: blocks-sanoid-options-
list-id: selfhostblocks-blocks-sanoid-options
source: @OPTIONS_JSON@
```
