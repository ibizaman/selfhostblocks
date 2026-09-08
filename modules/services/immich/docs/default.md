# Immich Service {#services-immich}

Defined in [`/modules/services/immich.nix`](@REPO@/modules/services/immich.nix).

This NixOS module is a service that sets up an [Immich](https://immich.app/) instance.

Compared to the stock module from nixpkgs,
this one adds:
- Declarative [initial admin creation](#services-immich-options-shb.immich.initialAdmin).
- Onboarding flow [skip](#services-immich-options-shb.immich.skipOnboarding).

## Features {#services-immich-features}

- Declarative creation of initial admin user.
- Access through [subdomain](#services-immich-options-shb.immich.subdomain)
  and [HTTPS](#services-immich-options-shb.immich.ssl) using reverse proxy. [Manual](#services-immich-usage).
- [Backup](#services-immich-options-shb.immich.backup) through the [backup block](./blocks-backup.html). [Manual](#services-immich-usage-backup).
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

### Backup {#services-immich-usage-backup}

Backing up Immich using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."immich" = {
  request = config.shb.immich.backup;
  settings = {
    enable = true;
  };
};
```

The name `"immich"` in the `instances` can be anything.
The `config.shb.immich.backup` option provides what directories to backup.
You can define any number of Restic instances to backup Immich multiple times.

You will then need to configure more options like the `repository`,
as explained in the [restic](blocks-restic.html) documentation.

### Impermanence {#services-immich-impermanence}

To save the data folder in an impermanence setup, add:

```nix
{
  shb.zfs.datasets."safe/immich" = {
    path = config.shb.immich.mediaLocation;
    owner = "immich";
    group = "immich";
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
