# Restic Block {#blocks-restic}

Defined in [`/modules/blocks/restic.nix`](@REPO@/modules/blocks/restic.nix).

This block sets up a backup job using [Restic][restic].

[restic]: https://restic.net/

## Contract {#blocks-restic-features}

This block implements the [backup](contracts-backup.html) contract.

Integration tests are defined in [`/test/blocks/restic.nix`](@REPO@/test/blocks/restic.nix).

## Usage {#blocks-backup-usage}

### One folder backed up to mounted hard drives {#blocks-backup-usage-one}

The following snippet shows how to configure
the backup of 1 folder to 1 repository.
We assume that the folder is used by the `myservice` service and is owned by a user of the same name.

```nix
shb.restic.instances.myservice = {
  enable = true;

  user = "myservice";

  passphraseFile = "<path/to/passphrase>";

  repositories = [{
    path = "/srv/backups/myservice";
    timerConfig = {
      OnCalendar = "00:00:00";
      RandomizedDelaySec = "3h";
    };
  }];

  sourceDirectories = [
    "/var/lib/myfolder"
  ];

  retention = {
    keep_within = "1d";
    keep_hourly = 24;
    keep_daily = 7;
    keep_weekly = 4;
    keep_monthly = 6;
  };
};
```

### One folder backed up to S3 {#blocks-restic-usage-remote}

Here we will only highlight the differences with the previous configuration.

This assumes you have access to such a remote S3 store, for example by using [Backblaze](https://www.backblaze.com/).

```diff
  shb.backup.instances.myservice = {

    repositories = [{
-     path = "/srv/pool1/backups/myfolder";
+     path = "s3:s3.us-west-000.backblazeb2.com/backups/myfolder";
      timerConfig = {
        OnCalendar = "00:00:00";
        RandomizedDelaySec = "3h";
      };

+     extraSecrets = {
+       AWS_ACCESS_KEY_ID.source="<path/to/access_key_id>";
+       AWS_SECRET_ACCESS_KEY.source="<path/to/secret_access_key>";
+     };
    }];
  }
```

### Secrets {#blocks-restic-secrets}

To be secure, the secrets should deployed out of band, otherwise they will be world-readable in the nix store.

To achieve that, I recommend [sops](usage.html#usage-secrets) although other methods work great too.
The code to backup to Backblaze with secrets stored in Sops would look like so:

```nix
shb.restic.instances.myfolder.passphraseFile = config.sops.secrets."myservice/backup/passphrase".path;
shb.restic.instances.myfolder.repositories = [
  {
    path = "s3:s3.us-west-000.backblazeb2.com/<mybucket>";
    secrets = {
      AWS_ACCESS_KEY_ID.source = config.sops.secrets."backup/b2/access_key_id".path;
      AWS_SECRET_ACCESS_KEY.source = config.sops.secrets."backup/b2/secret_access_key".path;
    };
  }
];

sops.secrets."myservice/backup/passphrase" = {
  sopsFile = ./secrets.yaml;
  mode = "0400";
  owner = "myservice";
  group = "myservice";
};
sops.secrets."backup/b2/access_key_id" = {
  sopsFile = ./secrets.yaml;
  mode = "0400";
  owner = "myservice";
  group = "myservice";
};
sops.secrets."backup/b2/secret_access_key" = {
  sopsFile = ./secrets.yaml;
  mode = "0400";
  owner = "myservice";
  group = "myservice";
};
```

Pay attention that the owner must be the `myservice` user, the one owning the files to be backed up.
A `secrets` contract is in progress that will allow one to not care about such details.

### Multiple directories to multiple destinations {#blocks-restic-usage-multiple}

The following snippet shows how to configure backup of any number of folders to 3 repositories,
each happening at different times to avoid I/O contention.

We will also make sure to be able to re-use as much as the configuration as possible.

A few assumptions:
- 2 hard drive pools used for backup are mounted respectively on `/srv/pool1` and `/srv/pool2`.
- You have a backblaze account.

First, let's define a variable to hold all the repositories we want to back up to:

```nix
repos = [
  {
    path = "/srv/pool1/backups";
    timerConfig = {
      OnCalendar = "00:00:00";
      RandomizedDelaySec = "3h";
    };
  }
  {
    path = "/srv/pool2/backups";
    timerConfig = {
      OnCalendar = "08:00:00";
      RandomizedDelaySec = "3h";
    };
  }
  {
    path = "s3:s3.us-west-000.backblazeb2.com/backups";
    timerConfig = {
      OnCalendar = "16:00:00";
      RandomizedDelaySec = "3h";
    };
  }
];
```

Compared to the previous examples, we do not include the name of what we will back up in the
repository paths.

Now, let's define a function to create a backup configuration. It will take a list of repositories,
a name identifying the backup and a list of folders to back up.

```nix
backupcfg = repositories: name: sourceDirectories {
  enable = true;

  backend = "restic";

  keySopsFile = ../secrets/backup.yaml;

  repositories = builtins.map (r: {
    path = "${r.path}/${name}";
    inherit (r) timerConfig;
  }) repositories;

  inherit sourceDirectories;

  retention = {
    keep_within = "1d";
    keep_hourly = 24;
    keep_daily = 7;
    keep_weekly = 4;
    keep_monthly = 6;
  };

  environmentFile = true;
};
```

Now, we can define multiple backup jobs to backup different folders:

```nix
shb.backup.instances.myfolder1 = backupcfg repos ["/var/lib/myfolder1"];
shb.backup.instances.myfolder2 = backupcfg repos ["/var/lib/myfolder2"];
```

The difference between the above snippet and putting all the folders into one configuration (shown
below) is the former splits the backups into sub-folders on the repositories.

```nix
shb.backup.instances.all = backupcfg repos ["/var/lib/myfolder1" "/var/lib/myfolder2"];
```

## Demo {#blocks-restic-demo}

[WIP]

## Monitoring {#blocks-restic-monitoring}

[WIP]

## Maintenance {#blocks-restic-maintenance}

One command-line helper is provided per backup instance and repository pair to automatically supply the needed secrets.

In the [multiple directories example](#blocks-restic-usage-multiple) above, the following 6 helpers are provided in the `$PATH`:

```bash
restic-myfolder1_srv_pool1_backups
restic-myfolder1_srv_pool2_backups
restic-myfolder1_s3_s3.us-west-000.backblazeb2.com_backups
restic-myfolder2_srv_pool1_backups
restic-myfolder2_srv_pool2_backups
restic-myfolder2_s3_s3.us-west-000.backblazeb2.com_backups
```

Discovering those is easy thanks to tab-completion.

One can then restore a backup with:

```bash
restic-myfolder1_srv_pool1_backups restore latest -t /
```

## Options Reference {#blocks-restic-options}

```{=include=} options
id-prefix: blocks-backup-options-
list-id: selfhostblocks-block-backup-options
source: @OPTIONS_JSON@
```
