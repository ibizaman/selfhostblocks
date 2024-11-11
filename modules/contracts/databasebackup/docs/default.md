# Database Backup Contract {#contract-databasebackup}

This NixOS contract represents a backup job
that will backup everything in one database
on a regular schedule.

It is a contract between a service that has database dumps to be backed up
and a service that backs up databases dumps.

## Contract Reference {#contract-databasebackup-options}

These are all the options that are expected to exist for this contract to be respected.

```{=include=} options
id-prefix: contracts-databasebackup-options-
list-id: selfhostblocks-options
source: @OPTIONS_JSON@
```

## Usage {#contract-databasebackup-usage}

A database that can be backed up will provide a `databasebackup` option.
Such a service is a `requester` providing a `request` for a module `provider` of this contract. 

What this option defines is, from the user perspective - that is _you_ - an implementation detail
but it will at least define how to create a database dump,
the user to backup with
and how to restore from a database dump.

Here is an example module defining such a `databasebackup` option:

```nix
{
  options = {
    myservice.databasebackup = mkOption {
      type = contracts.databasebackup.request;
      default = {
        user = "myservice";
        backupCmd = ''
          ${pkgs.postgresql}/bin/pg_dumpall | ${pkgs.gzip}/bin/gzip --rsyncable
        '';
        restoreCmd = ''
          ${pkgs.gzip}/bin/gunzip | ${pkgs.postgresql}/bin/psql postgres
        '';
      };
    };
  };
};
```

Now, on the other side we have a service that uses this `backup` option and actually backs up files.
This service is a `provider` of this contract and will provide a `result` option.

Let's assume such a module is available under the `databasebackupservice` option
and that one can create multiple backup instances under `databasebackupservice.instances`.
Then, to actually backup the `myservice` service, one would write:

```nix
databasebackupservice.instances.myservice = {
  request = myservice.databasebackup;
  
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
Thanks to using contracts, this can be made easily either with the same `databasebackupservice`:

```nix
databasebackupservice.instances.myservice_2 = {
  request = myservice.backup;
  
  settings = {
    enable = true;
  
    repository = {
      path = "<remote path>";
    };
  };
};
```

Or with another module `databasebackupservice_2`!

## Providers of the Database Backup Contract {#contract-databasebackup-providers}

- [Restic block](blocks-restic.html).
- [Borgbackup block](blocks-borgbackup.html) [WIP].

## Requester Blocks and Services {#contract-databasebackup-requesters}

- [PostgreSQL](blocks-postgresql.html#blocks-postgresql-contract-databasebackup).
