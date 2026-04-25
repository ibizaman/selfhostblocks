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

- [backup contract](contracts-backup.html) under the [`shb.sanoid.backup`][backup] option.
  It is tested with the [generic contract tests][backup contract tests].

[backup]: #blocks-sanoid-options-shb.restic.backup
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

  shb.sanoid.backup."root/home" = { };
}
```

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
    template = "yearly";
  };
}
```

Note we use the upstream `services.sanoid.templates` option to define the templates.

### Custom Template {#blocks-sanoid-usage-custom-template}

Create a custom template and use it:

```nix
{
  shb.zfs.pools.root.datasets.home = {
    path = "/home";
  };

  shb.sanoid.backup."root/home";
}
```

## Options Reference {#blocks-sanoid-options}

```{=include=} options
id-prefix: blocks-sanoid-options-
list-id: selfhostblocks-blocks-sanoid-options
source: @OPTIONS_JSON@
```
