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

Here is an example module defining such a `backup` option,
which defines what directories to backup (`sourceDirectories`)
and the user to backup with (`user`).

```nix
{
  options = {
    myservice.backup = mkOption {
      type = lib.types.submodule {
        options = shb.contracts.backup.mkRequester {
          user = "nextcloud";
          sourceDirectories = [
            "/var/lib/nextcloud"
          ];
        };
      };
    };
  };
};
```

Now, on the other side we have a service that uses this `backup` option and actually backs up files.
This service is a `provider` of this contract and will provide a `result` option.

Let's assume such a module is available under the `backupService` option
and that one can create multiple backup instances under `backupService.instances`.
Then, to actually backup the `myservice` service, one would write:

```nix
backupService.instances.myservice = {
  request = myservice.backup.request;
  
  settings = {
    enable = true;

    repository = {
      path = "/srv/backup/myservice";
    };

    # ... Other options specific to backupService like scheduling.
  };
};
```

It is advised to backup files to different location, to improve redundancy.
Thanks to using contracts, this can be made easily either with the same `backupService`:

```nix
backupService.instances.myservice_2 = {
  request = myservice.backup.request;
  
  settings = {
    enable = true;
  
    repository = {
      path = "<remote path>";
    };
  };
};
```

Or with another module `backupService_2`!

## Providers of the Backup Contract {#contract-backup-providers}

- [Restic block](blocks-restic.html).
- [Borgbackup block](blocks-borgbackup.html).

## Requester Blocks and Services {#contract-backup-requesters}

- <!-- [ -->Audiobookshelf<!-- ](services-audiobookshelf.html). --> (no manual yet)
- <!-- [ -->Deluge<!--](services-deluge.html). --> (no manual yet)
- <!-- [ -->Grocy<!--](services-grocy.html). --> (no manual yet)
- <!-- [ -->Hledger<!--](services-hledger.html). --> (no manual yet)
- <!-- [ -->Home Assistant<!--](services-home-assistant.html). --> (no manual yet)
- <!-- [ -->Jellyfin<!--](services-jellyfin.html). --> (no manual yet)
- <!-- [ -->LLDAP<!--](blocks-ldap.html). --> (no manual yet)
- [Nextcloud](services-nextcloud.html#services-nextcloudserver-usage-backup).
- [Vaultwarden](services-vaultwarden.html#services-vaultwarden-backup).
- <!-- [ -->*arr<!--](services-arr.html). --> (no manual yet)
