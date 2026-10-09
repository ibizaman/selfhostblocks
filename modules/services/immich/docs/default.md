# Immich Service {#services-immich}

Defined in [`/modules/services/immich.nix`](@REPO@/modules/services/immich.nix).

This NixOS module is a service that sets up an [Immich](https://immich.app/) instance.

## Features {#services-immich-features}

Compared to the stock module from nixpkgs,
this one adds:

- Declarative creation of the [initial admin user](#services-immich-options-shb.immich.initialAdmin).
- Declarative creation of [API keys](#services-immich-options-shb.immich.declarativeApiKeys) with custom permissions.
- Access through [subdomain](#services-immich-options-shb.immich.subdomain)
  and [HTTPS](#services-immich-options-shb.immich.ssl) using reverse proxy. [Manual](#services-immich-usage).
- [Backup](#services-immich-options-shb.immich.backup) through the [backup block](./blocks-backup.html). [Manual](#services-immich-usage-backup).
- [SSO](#services-immich-options-shb.immich.sso) integration.
- Integration with the [dashboard contract](contracts-dashboard.html) for displaying user facing application in a dashboard. [Manual](#services-immich-usage-applicationdashboard)

## Usage {#services-immich-usage}

### Initial Configuration {#services-immich-usage-configuration}

The following snippet assumes a few blocks have been setup already:

- the [secrets block](usage.html#usage-secrets) with SOPS,
- the [`shb.ssl` block](blocks-ssl.html#usage),
- the [`shb.lldap` block](blocks-lldap.html#blocks-lldap-global-setup).
- the [`shb.authelia` block](blocks-authelia.html#blocks-sso-global-setup).

```nix
shb.immich = {
  enable = true;
  subdomain = "immich";
  domain = "example.com";

  initialAdmin = {
    email = "admin@example.com";
    name = "Admin";
    password.result = config.shb.sops.secret."immich/adminPassword".result;
  };
};

shb.sops.secret."immich/adminPassword".request = config.shb.immich.admin.password.request;
```

Secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.

### Certificates {#services-immich-certs}

For Let's Encrypt certificates with the [`shb.ssl` block](blocks-ssl.html#usage), add:

```nix
{
  shb.certs.certs.letsencrypt."example.com" = {
    domain = "example.com";

    group = "nginx";
    reloadServices = [ "nginx.service" ];

    adminEmail = "shb@example.com";
  };

  shb.certs.certs.letsencrypt."example.com".extraDomains = [
    "${config.shb.immich.subdomain}.${config.shb.immich.domain}"
  ];

  shb.immich.ssl = config.shb.certs.certs.letsencrypt."example.com";
}
```

### Declarative API Keys {#services-immich-usage-apikeys}

The SHB Immich module allows you to manage api keys declaratively.
The only required option is to set the list of `permissions` the key should have.

The list of supported permissions is found in the [Immich documentation](https://api.immich.app/models/Permission).

```nix
{
  shb.immich.declarativeApiKeys.backupKey.permissions = [
    "asset.read"
    "asset.view"
  ];
}
```

### Backup {#services-immich-usage-backup}

Backing up Immich using the [Restic block](blocks-restic.html) is done like so:

```nix
{
  shb.restic.instances."immich" = {
    request = config.shb.immich.backup.request;
    settings = {
      enable = true;
    };
  };

  shb.immich.backupApiKey.contract.result.path = config.shb.immich.declarativeApiKeys.backupKey.path;
  shb.immich.declarativeApiKeys.backupKey.permissions = config.shb.immich.backupApiKey.permissions;
}
```

In the snippet, we create the `backupApiKey` using the `declarativeApiKeys`.
And no need to bother wondering what permissions to give the key as those are
given by the `backupApiKey.permissions` option.

The name `"immich"` in the `instances` can be anything.
The `config.shb.immich.backup` option provides what directories to backup.
You can define any number of Restic instances to backup Immich multiple times.

You will then need to configure more options like the `repository`,
as explained in the [restic](blocks-restic.html) documentation.

### Impermanence {#services-immich-impermanence}

To save the data folder in an impermanence setup, add:

```nix
{
  shb.zfs.datasets."root/safe/immich" = {
    path = config.shb.immich.mediaLocation;
    owner = "immich";
    group = "immich";
  };
}
```

Automated ZFS snapshots can be then configured thanks to the [sanoid](blocks-sanoid.html) block.

```nix
{
  shb.sanoid.backup."root/safe/immich" = {
    request = config.shb.zfs.pools.root.datasets."safe/immich".datasetBackup.request;
    settings.useTemplate = [ "main" ];
  };
}
```

And those snapshots can be synced to another `zpool` with:

```nix
{
  services.syncoid.commands."root/safe/pictures" = {
    recursive = true;
    target = "backup/syncoid/safe/pictures";
    extraArgs = [
      "--create-bookmark"
      "--no-sync-snap"
    ];
  };
}
```

### Application Dashboard {#services-immich-usage-applicationdashboard}

Integration with the [dashboard contract](contracts-dashboard.html) is provided
by the [dashboard option](#services-immich-options-shb.immich.dashboard).

For example using the [Homepage](services-homepage.html) service:

```nix
{
  shb.homepage.servicesGroups.Media.services.Immich = {
    sortOrder = 1;
    dashboard.request = config.shb.immich.dashboard.request;
  };
}
```

An API key with `server.statistics` permissions can be set to show extra info:

```nix
{
  shb.homepage.servicesGroups.Media.services.Immich = {
    apiKey.result = config.shb.sops.secret."immich/homepageApiKey".result;
  };

  shb.sops.secret."immich/homepageApiKey".request =
    config.shb.homepage.servicesGroups.Media.services.Immich.apiKey.request;
}
```

## Debug {#services-immich-debug}

In case of an issue, check the logs for systemd service `immich-server.service`.

Enable verbose logging by setting the [`shb.immich.debug`](#services-immich-options-shb.immich.debug) boolean to `true`.

## Options Reference {#services-immich-options}

```{=include=} options
id-prefix: services-immich-options-
list-id: selfhostblocks-service-immich-options
source: @OPTIONS_JSON@
```
