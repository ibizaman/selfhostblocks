# Pinchflat Service {#services-pinchflat}

Defined in [`/modules/services/pinchflat.nix`](@REPO@/modules/services/pinchflat.nix).

This NixOS module is a service that sets up a [Pinchflat](https://github.com/kieraneglin/pinchflat) instance.

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
