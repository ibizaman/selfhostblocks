# PostgreSQL Block {#blocks-postgresql}

This block sets up a [PostgreSQL][] database.

[postgresql]: https://www.postgresql.org/

Thanks to upstream nixpkgs, SHB supports several versions of PostgreSQL at a time. On top of upstream features, SHB also sets up:

- Enabling TCP/IP login and also accepting password authentication from localhost with [`shb.postgresql.enableTCPIP`](#blocks-postgresql-options-shb.postgresql.enableTCPIP).
- Enhance the `ensure*` upstream option by setting up a database's password from a password file with [`shb.postgresql.ensures`](#blocks-postgresql-options-shb.postgresql.ensures).
- Debug logging with `auto_explain` and `pg_stat_statements` with [`shb.postgresql.debug`](#blocks-postgresql-options-shb.postgresql.debug).
- Automatic backups using the [backup contracts](contracts-databasebackup.html) with [`shb.postgresql.databasebackup`](#blocks-postgresql-options-shb.postgresql.databasebackup).
- Explicit PostgreSQL major-version selection with [`shb.postgresql.version`](#blocks-postgresql-options-shb.postgresql.version).

## Usage {#blocks-postgresql-usage}

It is defined in [`/modules/blocks/postgresql.nix`](@REPO@/modules/blocks/postgresql.nix)
and to use it, add this import:

```nix
{ inputs, ... }:
{
  imports = [ inputs.selfhostblocks.nixosModules.default ];
}
```

### Select a PostgreSQL Version {#blocks-postgresql-version}

SelfHostBlocks requires an explicit PostgreSQL major version:

```nix
shb.postgresql.version = 18;
```

::: {.note}
On first usage of this module, an evaluation error will pop up if this option is not set.
Set it to the major version of PostgreSQL you have already deployed.
Inspect the running server or its `PG_VERSION` file.
:::

Setting the option does not upgrade the database.
See [below](#blocks-postgresql-upgrade) for the upgrade procedure.
If SHB finds a cluster for a different PostgreSQL major version on activation,
it refuses to initialize and reports the required migration steps.

Supported versions are 15, 16, 17, and 18.
The server, data directory, backup tools, and restore tools all follow this selection.

### Declarative User and Database {#blocks-postgresql-ensures}

Ensure a database and user exists:

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

SHB provides upgrade scripts from the configured version in `shb.postgresql.version` to every newer supported version.

For example, assuming version 15 is set in the option and SHB supports from versions 15 to 18 included,
SHB provides the binaries on the system path `upgrade-pg-cluster-15-16`, `upgrade-pg-cluster-15-17`, and `upgrade-pg-cluster-15-18`.
PostgreSQL supports [upgrading directly to a newer major version](https://www.postgresql.org/docs/18/upgrading.html)
so there is no issue in upgrading straight to latest.

::: {.warning}
Please make sure to backup the database before and after each operation.
Although a backup can only be taken when the database is running.
The safest and quickest is to take instead a filesystem snapshot if available.
It has the advantage that it can be done when the database is not running.
:::

1. If not done yet, set `shb.postgresql.version` to the major version you have and deploy.
   This way the upgrade helpers are installed.
2. Stop the systemd service `systemctl stop postgresql.service`.
   Of course, you can stop dependent services but this is technically enough.
3. Run the upgrade script to the target version: `upgrade-pg-cluster-<from>-<to>`.
   I would advise going directly to the latest version, because why not, but maybe some services are not yet compatible so you should check that first.
   The script will fail if the target directory already exists.
   You must first remove that directory before retrying but of course make sure nothing valuable is in there first.
   If unsure, just move it.
4. If the script failed, nothing needs to be reverted.
   You can either start the `postgresql.service` again or try to figure out the issue with the error.
   In the latter case, when running the script again, it will fail because the target folder folder exists already.
   Same advice as above: you must remove the target folder first but make sure nothing valuable is in there.
   If unsure, just move it.
5. If the script succeeded, do not start the `postgresql.service` yet as this will start the old database
   and you might end up with stale data in the new upgraded one.
6. Set `shb.postgresql.version` to the targeted version and deploy.
   This will automatically start the database with the new version.
7. Inspect dependent services and restart them if needed.
   Some recover from a database connection loss but some will require a little nudge.
8. Run the statistics commands emitted by your target version as the `postgres` operating-system user.

When you assessed everything worked,
you can remove the old database directory `/var/lib/postgresql/<old>`.

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
