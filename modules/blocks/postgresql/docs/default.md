# PostgreSQL Block {#blocks-postgresql}

Defined in [`/modules/blocks/postgresql.nix`](@REPO@/modules/blocks/postgresql.nix).

This block sets up a [PostgreSQL][] database.

[postgresql]: https://www.postgresql.org/

Compared to the upstream nixpkgs module, this module also sets up:

- Enabling TCP/IP login and also accepting password authentication from localhost with [`shb.postgresql.enableTCPIP`](#blocks-postgresql-options-shb.postgresql.enableTCPIP).
- Enhance the `ensure*` upstream option by setting up a database's password from a password file with [`shb.postgresql.ensures`](#blocks-postgresql-options-shb.postgresql.ensures).
- Debug logging with `auto_explain` and `pg_stat_statements` with [`shb.postgresql.debug`](#blocks-postgresql-options-shb.postgresql.debug).

## Usage {#blocks-postgresql-usage}

### Ensure User and Database {#blocks-postgresql-ensures}

Ensure a database and user exists:

```nix
shb.postgresql.ensures = [
  {
    username = "firefly-iii";
    database = "firefly-iii";
  }
];
```

Also set up the database password from a file path:

```nix
shb.postgresql.ensures = [
  {
    username = "firefly-iii";
    database = "firefly-iii";
    passwordFile = "/run/secrets/firefly-iii_db_password";
  }
];
```

### Database Backup Requester Contracts {#blocks-postgresql-contract-databasebackup}

This block can be backed up using the [database backup](contracts-databasebackup.html) contract.

Contract integration tests are defined in [`/test/contracts/databasebackup.nix`](@REPO@/test/contracts/databasebackup.nix).

#### Backing up All Databases {#blocks-postgresql-contract-databasebackup-all}

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

## Tests {#blocks-postgresql-tests}

Specific integration tests are defined in [`/test/blocks/postgresql.nix`](@REPO@/test/blocks/postgresql.nix).

## Options Reference {#blocks-postgresql-options}

```{=include=} options
id-prefix: blocks-postgresql-options-
list-id: selfhostblocks-block-postgresql-options
source: @OPTIONS_JSON@
```
