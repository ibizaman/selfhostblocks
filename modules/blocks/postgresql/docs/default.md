# PostgreSQL Block {#blocks-postgresql}

Defined in [`/modules/blocks/postgresql.nix`](@REPO@/modules/blocks/postgresql.nix).

This block sets up a [PostgreSQL][] database.

[postgresql]: https://www.postgresql.org/

Compared to the upstream nixpkgs module, this module also sets up:

- Enabling TCP/IP login and also accepting password authentication from localhost with [`shb.postgresql.enableTCPIP`](#blocks-postgresql-options-shb.postgresql.enableTCPIP).
- Enhance the `ensure*` upstream option by setting up a database's password from a password file with [`shb.postgresql.ensures`](#blocks-postgresql-options-shb.postgresql.ensures).
- Debug logging with `auto_explain` and `pg_stat_statements` with [`shb.postgresql.debug`](#blocks-postgresql-options-shb.postgresql.debug).
- Explicit PostgreSQL major-version selection with [`shb.postgresql.version`](#blocks-postgresql-options-shb.postgresql.version).

## Usage {#blocks-postgresql-usage}

### Select a PostgreSQL Version {#blocks-postgresql-version}

SelfHostBlocks requires an explicit PostgreSQL major version:

```nix
shb.postgresql.version = 18;
```

Supported versions are 15, 16, 17, and 18. The server, data directory, backup
tools, and restore tools all follow this selection.

When first updating an existing deployment, inspect the running server or its
`PG_VERSION` file and set this option to that same major before rebuilding.
Leaving the option at its `null` default while PostgreSQL is enabled produces
an evaluation error. Setting the option does not upgrade the database. If SHB
finds a cluster for a different PostgreSQL major, it refuses to initialize a
new cluster and reports the required migration steps.

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

### Upgrade PostgreSQL {#blocks-postgresql-upgrade}

[PostgreSQL supports upgrading directly to a newer major version without
installing intervening versions](https://www.postgresql.org/docs/current/upgrading.html).
For example, to upgrade directly from version 15 to 18:

1. Set `shb.postgresql.version = 15;` and deploy so the source version is
   explicit.
2. Stop services that use PostgreSQL so they cannot write to the source cluster.
3. Take and verify a database backup.
4. Stop `postgresql.service`.
5. Run `sudo upgrade-pg-cluster-15-18`.
6. Set `shb.postgresql.version = 18;` and deploy. This starts PostgreSQL and may
   also start or restart database consumers affected by the deployment. To
   validate the target cluster before consumers start, temporarily disable them
   in the configuration used for this deployment and re-enable them afterwards.
7. Validate all database consumers and take a fresh backup before manually
   deleting `/var/lib/postgresql/15`.

The helper performs a one-step upgrade and does not support `--check`.
`pg_upgrade` checks cluster compatibility before upgrading. The helper refuses
to run while PostgreSQL is active or if the target path already exists. It does
not delete or modify the source cluster, and it preserves `pg_upgrade`'s
standard follow-up output.

SHB provides a helper from the configured version to every newer supported
version. For example, version 15 provides `upgrade-pg-cluster-15-16`,
`upgrade-pg-cluster-15-17`, and `upgrade-pg-cluster-15-18`. Read the migration
notes for every intervening PostgreSQL release and verify application and
extension compatibility before upgrading.

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
