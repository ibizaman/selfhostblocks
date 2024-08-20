# Backup Contract {#backup-contract}

This NixOS contract represents a backup job
that will backup one or more files or directories
at a regular schedule.

## Contract Reference {#backup-contract-options}

These are all the options that are expected to exist for this contract to be respected.

```{=include=} options
id-prefix: contracts-backup-options-
list-id: selfhostblocks-options
source: @OPTIONS_JSON@
```

## Usage {#backup-contract-usage}

A service that can be backed up will provide a `backup` option, like for the [Vaultwarden service][vaultwarden-service-backup].
What this option defines is an implementation detail of that service
but it will at least define what directories to backup
and possibly hooks to run before or after the backup job runs.

[vaultwarden-service-backup]: services-vaultwarden.html#services-vaultwarden-options-shb.vaultwarden.backup

```nix
shb.<service>.backup
```

Let's assume a module implementing this contract is available under the `shb.<backup_impl>` variable.
Then, to actually backup the service, one would write:

```nix
shb.<backup_impl>.instances."<service>" = shb.<service>.backup // {
  enable = true;

  # Options specific to backup_impl
};
```

Then, for extra caution, a second backup could be made using another module `shb.<backup_impl_2>`:

```nix
shb.<backup_impl_2>.instances."<service>" = shb.<service>.backup // {
  enable = true;

  # Options specific to backup_impl_2
};
```

## Provided Implementations {#backup-contract-impl}

One implementation is provided out of the box:
- [Restic block](blocks-restic.html).

A second one based on `borgbackup` is in progress.
