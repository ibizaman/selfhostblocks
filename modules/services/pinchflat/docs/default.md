# Pinchflat Service {#services-pinchflat}

Defined in [`/modules/services/pinchflat.nix`](@REPO@/modules/services/pinchflat.nix).

This NixOS module sets up a [Pinchflat NGX](https://github.com/TheBadFella/Pinchflat-NGX) instance. Read the [migration guide](#services-pinchflat-usage-migration) before upgrading an existing SHB Pinchflat installation.

Compared to the stock module from nixpkgs,
this one sets up, in a fully declarative manner,
LDAP and SSO integration
and has a nicer option for secrets.

## Features {#services-pinchflat-features}

- Integration with the [dashboard contract](contracts-dashboard.html) for displaying user facing application in a dashboard. [Manual](#services-pinchflat-usage-applicationdashboard)

## Usage {#services-pinchflat-usage}

### Initial Configuration {#services-pinchflat-usage-configuration}

The following snippet assumes a few blocks have been setup already:

- the [secrets block](usage.html#usage-secrets) with SOPS,
- the [`shb.ssl` block](blocks-ssl.html#usage),
- the [`shb.lldap` block](blocks-lldap.html#blocks-lldap-global-setup).
- the [`shb.authelia` block](blocks-authelia.html#blocks-sso-global-setup).

```nix
shb.pinchflat = {
  enable = true;

  secretKeyBase.result = config.shb.sops.secret."pinchflat/secretKeyBase".result;
  timeZone = "Europe/Brussels";
  mediaDir = "/srv/pinchflat";

  domain = "example.com";
  subdomain = "pinchflat";
  ssl = config.shb.certs.certs.letsencrypt.${domain};

  ldap = {
    enable = true;
  };
  sso = {
    enable = true;
    authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
  };
};
shb.sops.secret."pinchflat/secretKeyBase".request = config.shb.pinchflat.secretKeyBase.request;
```

Secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.

The [user](#services-pinchflat-options-shb.pinchflat.ldap.userGroup)
LDAP group is created automatically.

### Migrating from original Pinchflat {#services-pinchflat-usage-migration}

The module now defaults to Pinchflat NGX. When migrating from original Pinchflat, you can retain the existing media directory, `secretKeyBase`, domain, and SSO configuration. Existing `shb.pinchflat` options and the `pinchflat.service` service name are retained. SQLite remains the default; switching to PostgreSQL or native OIDC is a separate migration.

NGX upgrades the database before displaying its migration review. Take a consistent backup **before activating the new NixOS configuration**. A NixOS generation rollback alone does not undo database changes; restore the pre-migration application state before starting the old version. See the [upstream migration guide](https://github.com/TheBadFella/Pinchflat-NGX/wiki/Migrating-from-Pinchflat) and [rollback guidance](https://github.com/TheBadFella/Pinchflat-NGX/wiki/Upgrading-and-Rollback#roll-back).

On ZFS installations, [SHB's snapshots before activation](blocks-zfs.html#blocks-zfs-options-shb.zfs.snapshotBeforeActivation.enable) can provide an additional recovery point. Ensure the configured snapshots include the dataset containing `/var/lib/pinchflat` and any relevant child datasets. Snapshots are non-recursive by default.

1. Check that the existing installation is running original Pinchflat `2025.9.26` and has finished its database migrations. NGX [requires the original application's final schema](https://github.com/TheBadFella/Pinchflat-NGX/blob/b9e828a7402c38f3901ed34014cf8ec881c2f324/lib/pinchflat/legacy_migration.ex#L929-L942).
2. Build the new NixOS configuration without activating it. Retain the previous NixOS generation for rollback.
3. Stop Pinchflat and archive all its application state, including SQLite's WAL files if present. Store the backup privately because it can contain credentials. The current SHB backup contract covers only `mediaDir`; it does not include `/var/lib/pinchflat` unless that directory is separately covered.

   ```bash
   backup_dir="/var/backups/pinchflat/pre-ngx-$(date -u +%Y%m%dT%H%M%SZ)"
   sudo systemctl stop pinchflat.service && \
   sudo install --directory --mode=0700 "$backup_dir" && \
   readlink -f /run/current-system | sudo tee "$backup_dir/system-path" && \
   sudo tar --create --gzip --file="$backup_dir/state.tar.gz" --directory=/var/lib pinchflat && \
   sudo tar --list --gzip --file="$backup_dir/state.tar.gz"
   ```

4. Continue only after the archive succeeds and contains `pinchflat/db/pinchflat.db`. Keep the existing secret available and retain your media backups. Activate the new configuration using your normal deployment procedure, then inspect `journalctl --unit=pinchflat.service` for startup failures.
5. Open Pinchflat's existing URL. Wait for the migration review's disk scan, compare its source/profile/download totals with the old library, and resolve inaccessible files before selecting **Looks good, continue**. The scan checks readability and size, not media checksums. Confirmation releases the migration hold, allowing configured download and retention policies to resume; previously disabled sources stay disabled.

To roll back, stop NGX, restore the complete application-state backup, and activate the retained old generation. Preserve the failed migration's state for investigation instead of extracting over it. In the same shell, with `backup_dir` still pointing at the archive above:

```bash
sudo systemctl stop pinchflat.service && \
restore_dir="$(sudo mktemp --directory /var/lib/pinchflat-rollback.XXXXXX)" && \
sudo tar --extract --gzip --same-owner --file="$backup_dir/state.tar.gz" --directory="$restore_dir" && \
sudo test -f "$restore_dir/pinchflat/db/pinchflat.db" && \
previous_system="$(sudo cat "$backup_dir/system-path")" && \
test -x "$previous_system/bin/switch-to-configuration" && \
sudo mv /var/lib/pinchflat "$restore_dir/after-ngx" && \
sudo mv "$restore_dir/pinchflat" /var/lib/pinchflat && \
sudo "$previous_system/bin/switch-to-configuration" switch
```

Check `systemctl status pinchflat.service` and open the old application before resuming normal operation. Keep media paths consistent with the restored database; downloads or deletions performed after confirming the NGX review are not reversed by restoring application state.

### Backup {#services-pinchflat-usage-backup}

Backing up Pinchflat using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."pinchflat" = {
  request = config.shb.pinchflat.backup;
  settings = {
    enable = true;
  };
};
```

The name `"pinchflat"` in the `instances` can be anything.
The `config.shb.pinchflat.backup` option provides what directories to backup.
You can define any number of Restic instances to backup Pinchflat multiple times.

### Application Dashboard {#services-pinchflat-usage-applicationdashboard}

Integration with the [dashboard contract](contracts-dashboard.html) is provided
by the [dashboard option](#services-pinchflat-options-shb.pinchflat.dashboard).

For example using the [Homepage](services-homepage.html) service:

```nix
{
  shb.homepage.servicesGroups.Media.services.Pinchflat = {
    sortOrder = 2;
    dashboard.request = config.shb.pinchflat.dashboard.request;
  };
}
```

## Options Reference {#services-pinchflat-options}

```{=include=} options
id-prefix: services-pinchflat-options-
list-id: selfhostblocks-service-pinchflat-options
source: @OPTIONS_JSON@
```
