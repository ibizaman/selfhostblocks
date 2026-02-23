# Jellyfin Service {#services-jellyfin}

Defined in [`/modules/services/jellyfin.nix`](@REPO@/modules/services/jellyfin.nix).

This NixOS module is a service that sets up a [Jellyfin](https://jellyfin.org/) instance.

Compared to the stock module from nixpkgs,
this one sets up, in a fully declarative manner:
- the initial wizard with an admin user thanks to a custom Jellyfin CLI
  and a custom restart logic to apply the changes from the CLI.
- LDAP and SSO integration thanks to a custom declarative installation of plugins.

## Features {#services-jellyfin-features}

- Declarative creation of admin user.
- Declarative selection of listening port.
- Access through [subdomain](#services-jellyfin-options-shb.jellyfin.subdomain)
  and [HTTPS](#services-jellyfin-options-shb.jellyfin.ssl) using reverse proxy. [Manual](#services-jellyfin-usage).
- Declarative plugin installation. [Manual](#services-jellyfin-options-shb.jellyfin.plugins).
- Declarative [LDAP](#services-jellyfin-options-shb.jellyfin.ldap) configuration.
- Declarative [SSO](#services-jellyfin-options-shb.jellyfin.sso) configuration.
- [Backup](#services-jellyfin-options-shb.jellyfin.backup) through the [backup block](./blocks-backup.html). [Manual](#services-jellyfin-usage-backup).
- Integration with the [dashboard contract](contracts-dashboard.html) for displaying user facing application in a dashboard. [Manual](#services-jellyfin-usage-applicationdashboard)

## Usage {#services-jellyfin-usage}

### Initial Configuration {#services-jellyfin-usage-configuration}

The following snippet assumes a few blocks have been setup already:

- the [secrets block](usage.html#usage-secrets) with SOPS,
- the [`shb.ssl` block](blocks-ssl.html#usage),
- the [`shb.lldap` block](blocks-lldap.html#blocks-lldap-global-setup).
- the [`shb.authelia` block](blocks-authelia.html#blocks-sso-global-setup).

```nix
shb.jellyfin = {
  enable = true;
  subdomain = "jellyfin";
  domain = "example.com";

  admin = {
    username = "admin";
    password.result = config.shb.sops.secret."jellyfin/adminPassword".result;
  };

  ldap = {
    enable = true;
    host = "127.0.0.1";
    port = config.shb.lldap.ldapPort;
    dcdomain = config.shb.lldap.dcdomain;
    adminPassword.result = config.shb.sops.secret."jellyfin/ldap/adminPassword".result
  };

  sso = {
    enable = true;
    endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
  
    secretFile = config.shb.sops.secret."jellyfin/sso_secret".result;
    secretFileForAuthelia = config.shb.sops.secret."jellyfin/authelia/sso_secret".result;
  };
};

shb.sops.secret."jellyfin/adminPassword".request = config.shb.jellyfin.admin.password.request;

shb.sops.secret."jellyfin/ldap/adminPassword".request = config.shb.jellyfin.ldap.adminPassword.request;

shb.sops.secret."jellyfin/sso_secret".request = config.shb.jellyfin.sso.sharedSecret.request;
shb.sops.secret."jellyfin/authelia/sso_secret" = {
  request = config.shb.jellyfin.sso.sharedSecretForAuthelia.request;
  settings.key = "jellyfin/sso_secret";
};
```

Secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.

The [user](#services-jellyfin-options-shb.jellyfin.ldap.userGroup)
and [admin](#services-jellyfin-options-shb.jellyfin.ldap.adminGroup)
LDAP groups are created automatically.

The `shb.jellyfin.sso.secretFile` and `shb.jellyfin.sso.secretFileForAuthelia` options
must have the same content. The former is a file that must be owned by the `jellyfin` user while
the latter must be owned by the `authelia` user. I want to avoid needing to define the same secret
twice with a future secrets SHB block.

### Certificates {#services-jellyfin-certs}

For Let's Encrypt certificates, add:

```nix
{
  shb.certs.certs.letsencrypt.${domain}.extraDomains = [
    "${config.shb.jellyfin.subdomain}.${config.shb.jellyfin.domain}"
  ];
}
```

### Backup {#services-jellyfin-usage-backup}

Backing up Jellyfin using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."jellyfin" = {
  request = config.shb.jellyfin.backup;
  settings = {
    enable = true;
  };
};
```

The name `"jellyfin"` in the `instances` can be anything.
The `config.shb.jellyfin.backup` option provides what directories to backup.
You can define any number of Restic instances to backup Jellyfin multiple times.

You will then need to configure more options like the `repository`,
as explained in the [restic](blocks-restic.html) documentation.

### Impermanence {#services-jellyfin-impermanence}

To save the data folder in an impermanence setup, add:

```nix
{
  shb.zfs.datasets."safe/jellyfin".path = config.shb.jellyfin.impermanence;
}
```

### Declarative LDAP {#services-jellyfin-declarative-ldap}

To add a user `USERNAME` to the user and admin groups for jellyfin, add:

```nix
shb.lldap.ensureUsers.USERNAME.groups = [
  config.shb.jellyfin.ldap.userGroup
  config.shb.jellyfin.ldap.adminGroup
];
```

### Application Dashboard {#services-jellyfin-usage-applicationdashboard}

Integration with the [dashboard contract](contracts-dashboard.html) is provided
by the [dashboard option](#services-jellyfin-options-shb.jellyfin.dashboard).

For example using the [Homepage](services-homepage.html) service:

```nix
{
  shb.homepage.servicesGroups.Media.services.Jellyfin = {
    sortOrder = 1;
    dashboard.request = config.shb.jellyfin.dashboard.request;
  };
}
```

An API key can be set to show extra info:

```nix
{
  shb.homepage.servicesGroups.Media.services.Jellyfin = {
    apiKey.result = config.shb.sops.secret."jellyfin/homepageApiKey".result;
  };

  shb.sops.secret."jellyfin/homepageApiKey".request =
    config.shb.homepage.servicesGroups.Media.services.Jellyfin.apiKey.request;
}
```

## Debug {#services-jellyfin-debug}

In case of an issue, check the logs for systemd service `jellyfin.service`.

Enable verbose logging by setting the `shb.jellyfin.debug` boolean to `true`.

## Options Reference {#services-jellyfin-options}

```{=include=} options
id-prefix: services-jellyfin-options-
list-id: selfhostblocks-service-jellyfin-options
source: @OPTIONS_JSON@
```
