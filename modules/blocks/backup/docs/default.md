# Backup Block {#blocks-backup}

Defined in [`/modules/blocks/backup.nix`](@REPO@/modules/blocks/backup.nix).

This block sets up backup jobs for Self Host Blocks.

## Features {#blocks-backup-features}
Two implementations for this block are provided:
- [Restic](https://restic.net/)
- [Borgmatic](https://torsion.org/borgmatic/)

No integration tests are provided yet.

## Usage {#usage}

### One folder backed up to mounted hard drives {#blocks-backup-config-one}

The following snippet shows how to configure backup of 1 folder using the Restic implementation to 1
repository.

Assumptions:
- 1 hard drive pool is used for backup and is mounted on `/srv/pool1`.

```nix
shb.backup.instances.myfolder = {
  enable = true;

  backend = "restic";

  keySopsFile = ./secrets.yaml;

  repositories = [{
    path = "/srv/pool1/backups/myfolder";
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

  consistency = {
    repository = "2 weeks";
    archives = "1 month";
  };
};
```

The referenced Sops file must follow this structure:

```yaml
restic:
    passphrases:
        myfolder: <secret>
```

To generate a secret, use: `nix run nixpkgs#openssl -- rand -hex 64`.

With the borgmatic implementation, the structure should be:

```yaml
borgmatic:
    keys:
        myfolder: |
            BORG_KEY <key>
    passphrases:
        myfolder: <secret>
```

You can have both borgmatic and restic implementations working at the same time.

### One folder backed up to S3 {#blocks-backup-config-remote}

> This is only supported by the Restic implementation. 

Here we will only highlight the differences with the previous configuration.

This assumes you have access to such a remote S3 store, for example by using Backblaze.

```diff
  shb.backup.instances.myfolder = {

    repositories = [{
-     path = "/srv/pool1/backups/myfolder";
+     path = "s3:s3.us-west-000.backblazeb2.com/backups/myfolder";
      timerConfig = {
        OnCalendar = "00:00:00";
        RandomizedDelaySec = "3h";
      };
    }];


+   environmentFile = true; # Needed for s3
  }
```

The Sops file has a new required field:

```yaml

  restic:
      passphrases:
          myfolder: <secret>
+     environmentfiles:
+         myfolder: |-
+             AWS_ACCESS_KEY_ID=<aws_key_id>
+             AWS_SECRET_ACCESS_KEY=<aws_secret_key>
```

### Multiple folder to multiple destinations {#blocks-backup-config-multiple}

The following snippet shows how to configure backup of any number of folders using the Restic
implementation to 3 repositories, each happening at different times to avoid contending for I/O
time.

We will also make sure to be able to re-use as much as the configuration as possible.

A few assumptions:
- 2 hard drive pools used for backup are mounted respectively on `/srv/pool1` and `/srv/pool2`.
- You have a backblaze account.

First, let's define a variable to hold all our repositories you want to back up to:

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

  consistency = {
    repository = "2 weeks";
    archives = "1 month";
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

## Monitoring {#monitoring-backup-block}

[WIP]

## Maintenance {#monitoring-maintenance}

[WIP]

## Options Reference {#opt-backup-block}

```{=include=} options
id-prefix: opt-blocks-backup-
list-id: selfhostblocks-block-backup-options
source: @OPTIONS_JSON@
```
