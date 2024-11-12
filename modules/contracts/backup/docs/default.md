# Backup Contract {#contract-backup}

This NixOS contract represents a backup job
that will backup one or more files or directories
on a regular schedule.

It is a contract between a service that has files to be backed up
and a service that backs up files.

## Contract Reference {#contract-backup-options}

These are all the options that are expected to exist for this contract to be respected.

```{=include=} options
id-prefix: contracts-backup-options-
list-id: selfhostblocks-options
source: @OPTIONS_JSON@
```

## Usage {#contract-backup-usage}

A service that can be backed up will provide a `backup` option.
Such a service is a `requester` providing a `request` for a module `provider` of this contract. 

What this option defines is, from the user perspective - that is _you_ - an implementation detail
but it will at least define what directories to backup,
the user to backup with
and possibly hooks to run before or after the backup job runs.

Here is an example module defining such a `backup` option:

```nix
{
  options = {
    myservice.backup = mkOption {
      type = contracts.backup.request;
      default = {
        user = "myservice";
        sourceDirectories = [
          "/var/lib/myservice"
        ];
      };
    };
  };
};
```

Now, on the other side we have a service that uses this `backup` option and actually backs up files.
This service is a `provider` of this contract and will provide a `result` option.

Let's assume such a module is available under the `backupservice` option
and that one can create multiple backup instances under `backupservice.instances`.
Then, to actually backup the `myservice` service, one would write:

```nix
backupservice.instances.myservice = {
  request = myservice.backup;
  
  settings = {
    enable = true;

    repository = {
      path = "/srv/backup/myservice";
    };

    # ... Other options specific to backupservice like scheduling.
  };
};
```

It is advised to backup files to different location, to improve redundancy.
Thanks to using contracts, this can be made easily either with the same `backupservice`:

```nix
backupservice.instances.myservice_2 = {
  request = myservice.backup;
  
  settings = {
    enable = true;
  
    repository = {
      path = "<remote path>";
    };
  };
};
```

Or with another module `backupservice_2`!

## Providers of the Backup Contract {#contract-backup-providers}

- [Restic block](blocks-restic.html).
- [Borgbackup block](blocks-borgbackup.html) [WIP].

## Requester Blocks and Services {#contract-backup-requesters}

- <!-- [ -->Audiobookshelf<!-- ](services-audiobookshelf.html). --> (no manual yet)
- <!-- [ -->Deluge<!--](services-deluge.html). --> (no manual yet)
- <!-- [ -->Grocy<!--](services-grocy.html). --> (no manual yet)
- <!-- [ -->Hledger<!--](services-hledger.html). --> (no manual yet)
- <!-- [ -->Home Assistant<!--](services-home-assistant.html). --> (no manual yet)
- <!-- [ -->Jellyfin<!--](services-jellyfin.html). --> (no manual yet)
- <!-- [ -->LLDAP<!--](blocks-ldap.html). --> (no manual yet)
- [Nextcloud](services-nextcloud.html#services-nextcloud-server-usage-backup).
- [Vaultwarden](services-vaultwarden.html#services-vaultwarden-backup).
- <!-- [ -->*arr<!--](services-arr.html). --> (no manual yet)
