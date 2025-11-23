# Borgbackup Block {#blocks-borgbackup}

Defined in [`/modules/blocks/borgbackup.nix`](@REPO@/modules/blocks/borgbackup.nix).

This block sets up a backup job using [BorgBackup][].

[borgbackup]: https://www.borgbackup.org/

## Provider Contracts {#blocks-borgbackup-contract-provider}

This block provides the following contracts:

- [backup contract](contracts-backup.html) under the [`shb.borgbackup.instances`][instances] option.
  It is tested with [contract tests][backup contract tests].
- [database backup contract](contracts-databasebackup.html) under the [`shb.borgbackup.databases`][databases] option.
  It is tested with [contract tests][database backup contract tests].

[instances]: #blocks-borgbackup-options-shb.borgbackup.instances
[databases]: #blocks-borgbackup-options-shb.borgbackup.databases
[backup contract tests]: @REPO@/test/contracts/backup.nix
[database backup contract tests]: @REPO@/test/contracts/databasebackup.nix

As requested by those two contracts, when setting up a backup with BorgBackup,
a backup Systemd service and a [restore script](#blocks-borgbackup-maintenance) are provided.

## Usage {#blocks-borgbackup-usage}

The following examples assume usage of the [sops block][] to provide secrets
although any blocks providing the [secrets contract][] works too.

[sops block]: ./blocks-sops.html
[secrets contract]: ./contracts-secrets.html

### One folder backed up manually {#blocks-borgbackup-usage-provider-manual}

The following snippet shows how to configure
the backup of 1 folder to 1 repository.
We assume that the folder `/var/lib/myfolder` of the service `myservice` must be backed up.

```nix
shb.borgbackup.instances."myservice" = {
  request = {
    user = "myservice";

    sourceDirectories = [
      "/var/lib/myfolder"
    ];
  };

  settings = {
    enable = true;

    passphrase.result = shb.sops.secret."passphrase".result;

    repository = {
      path = "/srv/backups/myservice";
      timerConfig = {
        OnCalendar = "00:00:00";
        RandomizedDelaySec = "3h";
      };
    };

    retention = {
      within = "1d";
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 6;
    };
  };
};

shb.sops.secret."passphrase".request =
  shb.borgbackup.instances."myservice".settings.passphrase.request;
```

### One folder backed up with contract {#blocks-borgbackup-usage-provider-contract}

With the same example as before but assuming the `myservice` service
has a `myservice.backup` option that is a requester for the backup contract,
the snippet above becomes:

```nix
shb.borgbackup.instances."myservice" = {
  request = config.myservice.backup;

  settings = {
    enable = true;

    passphrase.result = shb.sops.secret."passphrase".result;

    repository = {
      path = "/srv/backups/myservice";
      timerConfig = {
        OnCalendar = "00:00:00";
        RandomizedDelaySec = "3h";
      };
    };

    retention = {
      within = "1d";
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 6;
    };
  };
};

shb.sops.secret."passphrase".request =
  shb.borgbackup.instances."myservice".settings.passphrase.request;
```

### One folder backed up to S3 {#blocks-borgbackup-usage-provider-remote}

Here we will only highlight the differences with the previous configuration.

This assumes you have access to such a remote S3 store, for example by using [Backblaze](https://www.backblaze.com/).

```diff
  shb.test.backup.instances.myservice = {

    repository = {
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
    };
  }
```

### Multiple directories to multiple destinations {#blocks-borgbackup-usage-multiple}

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

  backend = "borgbackup";

  keySopsFile = ../secrets/backup.yaml;

  repositories = builtins.map (r: {
    path = "${r.path}/${name}";
    inherit (r) timerConfig;
  }) repositories;

  inherit sourceDirectories;

  retention = {
    within = "1d";
    hourly = 24;
    daily = 7;
    weekly = 4;
    monthly = 6;
  };

  environmentFile = true;
};
```

Now, we can define multiple backup jobs to backup different folders:

```nix
shb.test.backup.instances.myfolder1 = backupcfg repos ["/var/lib/myfolder1"];
shb.test.backup.instances.myfolder2 = backupcfg repos ["/var/lib/myfolder2"];
```

The difference between the above snippet and putting all the folders into one configuration (shown
below) is the former splits the backups into sub-folders on the repositories.

```nix
shb.test.backup.instances.all = backupcfg repos ["/var/lib/myfolder1" "/var/lib/myfolder2"];
```

## Monitoring {#blocks-borgbackup-monitoring}

[WIP](https://github.com/ibizaman/selfhostblocks/issues/151)

## Maintenance {#blocks-borgbackup-maintenance}

One command-line helper is provided per backup instance and repository pair to automatically supply the needed secrets.

The restore script has all the secrets needed to access the repo,
it will run `sudo` automatically
and the user running it needs to have correct permissions for privilege escalation

In the [multiple directories example](#blocks-borgbackup-usage-multiple) above, the following 6 helpers are provided in the `$PATH`:

```bash
borgbackup-job-myfolder1_srv_pool1_backups
borgbackup-job-myfolder1_srv_pool2_backups
borgbackup-job-myfolder1_s3_s3.us-west-000.backblazeb2.com_backups
borgbackup-job-myfolder2_srv_pool1_backups
borgbackup-job-myfolder2_srv_pool2_backups
borgbackup-job-myfolder2_s3_s3.us-west-000.backblazeb2.com_backups
```

Discovering those is easy thanks to tab-completion.

One can then restore a backup from a given repository with:

```bash
borgbackup-job-myfolder1_srv_pool1_backups restore latest
```

### Troubleshooting {#blocks-borgbackup-maintenance-troubleshooting}

In case something bad happens with a backup, the [official documentation](https://borgbackup.readthedocs.io/en/stable/077_troubleshooting.html) has a lot of tips.

## Tests {#blocks-borgbackup-tests}

Specific integration tests are defined in [`/test/blocks/borgbackup.nix`](@REPO@/test/blocks/borgbackup.nix).

## Options Reference {#blocks-borgbackup-options}

```{=include=} options
id-prefix: blocks-borgbackup-options-
list-id: selfhostblocks-block-borgbackup-options
source: @OPTIONS_JSON@
```
