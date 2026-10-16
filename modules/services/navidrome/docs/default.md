# Navidrome Service {#services-navidrome}

Defined in [`/modules/services/navidrome.nix`](@REPO@/modules/services/navidrome.nix).

This NixOS module is a service that sets up a [Navidrome](https://www.navidrome.org/) instance.

This module augments the module from nixpkgs by integrating it with SHB blocks to 
declaratively set up SSL, backups, SSO and more.

## Features {#services-navidrome-features}

- Declarative provisioning of users
- Declarative [SSO](#services-navidrome-options-shb.navidrome.sso) Configuration. [Manual](#services-navidrome-usage-sso).
- Access through [subdomain](#services-navidrome-options-shb.navidrome.subdomain) using reverse proxy.
- Access through [HTTPS](#services-navidrome-options-shb.navidrome.ssl) using reverse proxy.
- [Backup](#services-navidrome-options-shb.navidrome.sso) through the [backup block](./blocks-backup.html). [Manual](#services-navidrome-usage-backup).
- Integration with the [dashboard contract](contracts-dashboard.html) for displaying user facing application in a dashboard.

## Usage {#services-navidrome-usage}

### Initial Configuration {#services-navidrome-usage-configuration}

The following snippet enables Navidrome and makes it available under the 
`music.example.com` endpoint.

The following snippet assumes that the [`shb.authelia` block](blocks-authelia.html#blocks-sso-global-setup) 
(and prerequisites) have been set up already.

```nix
shb.navidrome = {
    enable = true;
    domain = "example.com";
    subdomain = "music";

    ssl = config.shb.certs.certs.letsencrypt.${domain};

    sso = {
      enable = true;
      endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
    };

    settings = {
        EnableUserEditing = true;
    };
  };
};
```

The `settings` option is optional; it is included here merely to show how you can control additional 
[Navidrome Configuration Options](https://www.navidrome.org/docs/usage/configuration/options/).

Note that no secrets are needed here, because Navidrome uses header authentication.

## SSO {#services-navidrome-usage-sso}

SSO is supported, but Navidrome is limited to basic header auth. Essentially, Navidrome receives
a request header containing only the username of the signed in user from Authelia. Navidrome does auto-register
new users, but does not support roles (so there is no `adminGroup` option).
The first user to sign in becomes admin and must manage roles for following users. 

## Backup {#services-navidrome-usage-backup}

Backing up Navidrome music and data folders using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."navidrome" = {
  request = config.shb.navidrome.backup;
  settings = {
    enable = true;
  };
};
```

The name `"navidrome"` in the `instances` can be anything.
The `config.shb.navidrome.backup` option provides what directories to backup (`musicDir` and `dataDir`).
You can define any number of Restic instances to backup Navidrome multiple times.

## Options Reference {#services-navidrome-options}

```{=include=} options
id-prefix: services-navidrome-options-
list-id: selfhostblocks-services-navidrome-options
source: @OPTIONS_JSON@
```
