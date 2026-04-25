# Dataset Backup Contract {#contract-dataset-backup}

This NixOS contract represents a backup job
that will backup one ZFS dataset.

It is a contract between a service that manages ZFS datasets
and a service that backs up ZFS datasets.

## Contract Reference {#contract-datatsetbackup-options}

These are all the options that are expected to exist for this contract to be respected.

```{=include=} options
id-prefix: contracts-datasetbackup-options-
list-id: selfhostblocks-options
source: @OPTIONS_JSON@
```

## Usage {#contract-datasetbackup-usage}

A service that manages ZFS datasets that can be backed up will provide a `datasetbackup` option.

Here is an example module defining such a `backup` option,
which defines what directories to backup (`sourceDirectories`)
and the user to backup with (`user`).

```nix
{
  options = {
    myservice.datasetbackup = mkOption {
      type = lib.types.submodule {
        options = shb.contracts.datasetbackup.mkRequester {
          dataset = "root/test";
        };
      };
    };
  };
};
```

Now, on the other side we have a service that uses this `datasetbackup` option and actually backs up the dataset.
This service is a `provider` of this contract and will provide a `result` option.

Let's assume such a module is available under the `backupService` option
and that one can create multiple backup instances under `backupService.instances`.
Then, to actually backup the `myservice` service, one would write:

```nix
backupService.instances.myservice = {
  request = myservice.datasetbackup.request;
  
  settings = {
    enable = true;

    targetDataset = "backup/myservice";

    # ... Other options specific to backupService like scheduling.
  };
};
```

It is advised to backup files to different location, to improve redundancy.
Thanks to using contracts, this can be made easily either with the same `backupService`:

```nix
backupService.instances.myservice_2 = {
  request = myservice.datasetbackup.request;
  
  settings = {
    enable = true;
  
    targetDataset = "backup2/myservice";
  };
};
```

Or with another module `backupService_2`!

## Providers of the Backup Contract {#contract-datasetbackup-providers}

- [Sanoid block](blocks-sanoid.html).

## Requester Blocks and Services {#contract-datasetbackup-requesters}

- [ZFS](blocks-zfs.html#blocks-zfs-backup).
