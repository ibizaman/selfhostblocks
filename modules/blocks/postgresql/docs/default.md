# PostgreSQL Block {#blocks-postgresql}

Defined in [`/modules/blocks/postgresql.nix`](@REPO@/modules/blocks/postgresql.nix).

This block sets up a [PostgreSQL][] database.

[postgresql]: https://www.postgresql.org/

## Tests {#blocks-postgresql-tests}

Specific integration tests are defined in [`/test/blocks/postgresql.nix`](@REPO@/test/blocks/postgresql.nix).

## Database Backup Requester Contracts {#blocks-postgresql-contract-databasebackup}

This block can be backed up using the [database backup](contracts-databasebackup.html) contract.

Contract integration tests are defined in [`/test/contracts/databasebackup.nix`](@REPO@/test/contracts/databasebackup.nix).

### Backing up All Databases {#blocks-postgresql-contract-databasebackup-all}

```nix
{
  my.backup.provider."postgresql" = {
    request = config.shb.postgresql.databasebackup;

    settings = {
      // Specific options for the backup provider.
    };
  };
}
```

## Options Reference {#blocks-postgresql-options}

```{=include=} options
id-prefix: blocks-postgresql-options-
list-id: selfhostblocks-block-postgresql-options
source: @OPTIONS_JSON@
```
