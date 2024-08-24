# Backup Contract {#backup-contract}

This NixOS contract represents a backup job
that will backup one or more files or directories
at a regular schedule.

It is a contract between a service that has files to be backed up
and a service that backs up files.
All options in this contract should be set by the former.
The latter will then use the values of those options to know what to backup.

## Contract Reference {#backup-contract-options}

These are all the options that are expected to exist for this contract to be respected.

```{=include=} options
id-prefix: contracts-backup-options-
list-id: selfhostblocks-options
source: @OPTIONS_JSON@
```

## Usage {#backup-contract-usage}

A service that can be backed up will provide a `backup` option.
What this option defines is, from the user perspective - that is _you_ - an implementation detail
but it will at least define what directories to backup,
the user to backup with
and possibly hooks to run before or after the backup job runs.

Here is an example module defining such a `backup` option:

```nix
{
  options = {
    myservice.backup = lib.mkOption {
      type = contracts.backup;
      readOnly = true;
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

As you can see, NixOS modules are a bit abused to make contracts work.
Default values are set as well as the `readOnly` attribute to ensure those values stay as defined.

Now, on the other side we have a service that uses this `backup` option and actually backs up files.
Let's assume such a module is available under the `backupservice` option
and that one can create multiple backup instances under `backupservice.instances`.
Then, to actually backup the `myservice` service, one would write:

```nix
backupservice.instances.myservice = myservice.backup // {
  enable = true;

  repository = {
    path = "/srv/backup/myservice";
  };

  # ... Other options specific to backupservice like scheduling.
};
```

It is advised to backup files to different location, to improve redundancy.
Thanks to using contracts, this can be made easily either with the same `backupservice`:

```nix
backupservice.instances.myservice_2 = myservice.backup // {
  enable = true;

  repository = {
    path = "<remote path>";
  };
};
```

Or with another module `backupservice_2`!

## Provided Implementations {#backup-contract-impl}

An implementation here is a service that understands the `backup` contract
and will backup the files accordingly.

One implementation is provided out of the box:
- [Restic block](blocks-restic.html).

A second one based on `borgbackup` is in progress.

## Services Providing `backup` Option {#backup-contract-services}

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
