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

What this contract defines is, from the user perspective - that is _you_ - an implementation detail
but it will at least define how to create a database dump,
the user to backup with
and how to restore from a database dump.

A NixOS module that can be backed up using this contract will provide a `databasebackup` option.
Such a service is a `requester` which has a `request`.

Here is an example module defining such a `databasebackup` option:

```nix
{
  options = {
    databasebackupservices.instances = mkOption {
      description = ''
        Backup configuration.
      '';

      default = {};
      type = submodule {
        options = contracts.databasebackup.mkRequester {
          user = "postgres";

          backupName = "postgres.sql";

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
};
```

Now, on the other side we have a service that uses this `backup` option and actually backs up files.
This service is a `provider` of this contract and will provide a `result` option.

```nix
{
  options = {
    instances = mkOption {
      description = "Files to backup.";
      default = {};
      type = attrsOf (submodule ({ name, config, ... }: {
        options = contracts.backup.mkProvider {
          settings = mkOption {
            description = ''
              Settings specific to the this provider.
            '';

            type = submodule {
              options = {
                enable = mkEnableOption "this backup intance.";
                # ... Other options specific to this provider.
              };
            };
          };

          resultCfg = let 
            fullName = name: repository: "backups-${name}_${repository.path}";
          in {
            restoreScript = fullName name config.settings.repository;
            restoreScriptText = "${fullName "<name>" { path = "path/to/repository"; }}";

            backupService = "${fullName name config.settings.repository}.service";
            backupServiceText = "${fullName "<name>" { path = "path/to/repository"; }}.service";
          };
        };
      }));
    };
  };
}
```

Then, to actually backup the `myservice` service,
one would need to link the requester to the provider with:

```nix
databasebackupservice.instances.myservice = {
  request = config.myservice.databasebackup.request;
  
  settings = {
    enable = true;

    # ... Other options specific to this provider.
  };
};
```

It is advised to backup files to different location, to improve redundancy.
Thanks to using contracts, this can be done easily either with the same `databasebackupservice`:

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
