# Firefly-iii Service {#services-firefly-iii}

Defined in [`/modules/services/firefly-iii.nix`](@REPO@/modules/services/firefly-iii.nix).

This NixOS module is a service that sets up a [Firefly-iii](https://www.firefly-iii.org/) instance.

Compared to the stock module from nixpkgs,
this one sets up, in a fully declarative manner,
LDAP and SSO integration
and has a nicer option for secrets.
It also sets up the Firefly-iii data importer service
and nearly automatically links it to the Firefly-iii instance using a Personal Account Token.
Instructions on how to do so is given in the next section.

## Usage {#services-firefly-iii-usage}

The following snippet assumes a few blocks have been setup already:

- the [secrets block](usage.html#usage-secrets) with SOPS,
- the [`shb.ssl` block](blocks-ssl.html#usage),
- the [`shb.lldap` block](blocks-lldap.html#blocks-lldap-global-setup).
- the [`shb.authelia` block](blocks-authelia.html#blocks-sso-global-setup).

```nix
shb.firefly-iii = {
  enable = true;
  debug = false;

  appKey.result = config.shb.sops.secret."firefly-iii/appKey".result;
  dbPassword.result = config.shb.sops.secret."firefly-iii/dbPassword".result;

  domain = "example.com";
  subdomain = "firefly-iii";
  siteOwnerEmail = "mail@example.com";
  ssl = config.shb.certs.certs.letsencrypt.${domain};

  smtp = {
    host = "smtp.eu.mailgun.org";
    port = 587;
    username = "postmaster@mg.example.com";
    from_address = "firefly-iii@example.com";
    password.result = config.shb.sops.secrets."firefly-iii/smtpPassword".result;
  };

  sso = {
    enable = true;
    authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
  };

  importer = {
    # See note hereunder.
    # firefly-iii-accessToken.result = config.shb.sops.secret."firefly-iii/importerAccessToken".result;
  };
};
shb.sops.secret."firefly-iii/appKey".request = config.shb.firefly-iii.appKey.request;
shb.sops.secret."firefly-iii/dbPassword".request = config.shb.firefly-iii.dbPassword.request;
shb.sops.secret."firefly-iii/smtpPassword".request = config.shb.firefly-iii.smtp.password.request;
# See not hereunder.
# shb.sops.secret."firefly-iii/importerAccessToken".request = config.shb.firefly-iii.importer.firefly-iii-accessToken.request;
```

Secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.
Note that for `appKey`, the secret length must be exactly 32 characters.

The [user](#services-firefly-iii-options-shb.firefly-iii.ldap.userGroup)
and [admin](#services-firefly-iii-options-shb.firefly-iii.ldap.adminGroup)
LDAP groups are created automatically.
Only admin users have access to the Firefly-iii data importer.
On the Firefly-iii web UI, the first user to login will be the admin.
We cannot yet create multiple admins in the Firefly-iii web UI.

On first start, leave the `shb.firefly-iii.importer.firefly-iii-accessToken` option empty.
To fill it out and connect the data importer to the Firefly-iii instance,
you must first create a personal access token then fill that option and redeploy.

## Backup {#services-firefly-iii-usage-backup}

Backing up Firefly-iii using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."firefly-iii" = {
  request = config.shb.firefly-iii.backup;
  settings = {
    enable = true;
  };
};
```

The name `"firefly-iii"` in the `instances` can be anything.
The `config.shb.firefly-iii.backup` option provides what directories to backup.
You can define any number of Restic instances to backup Firefly-iii multiple times.

Linking the Firefly-iii data importer to the Firefly-iii instance must still be done manually
by following the instructions appearing on the web UI.

## Certificates {#services-firefly-iii-certs}

For Let's Encrypt certificates, add:

```nix
{
  shb.certs.certs.letsencrypt.${domain}.extraDomains = [
    "${config.shb.firefly-iii.subdomain}.${config.shb.firefly-iii.domain}"
    "${config.shb.firefly-iii.importer.subdomain}.${config.shb.firefly-iii.domain}"
  ];
}
```

## Impermanence {#services-firefly-iii-impermanence}

To save the data folder in an impermanence setup, add:

```nix
{
  shb.zfs.datasets."safe/firefly-iii".path = config.shb.firefly-iii.impermanence;
}
```

## Declarative LDAP {#services-firefly-iii-declarative-ldap}

To add a user `USERNAME` to the user and admin groups for Firefly-iii, add:

```nix
shb.lldap.ensureUsers.USERNAME.groups = [
  config.shb.firefly-iii.ldap.userGroup
  config.shb.firefly-iii.ldap.adminGroup
];
```

## Database Inspection {#services-firefly-iii-database-inspection}

Access the database with:

```nix
sudo -u firefly-iii psql
```

Dump the database with:

```nix
sudo -u firefly-iii pg_dump --data-only --inserts firefly-iii > dump
```

## Mobile Apps {#services-firefly-iii-mobile}

This module was tested with the [Abacus iOS](https://github.com/victorbalssa/abacus) mobile app
using a Personal Account Token.

## Options Reference {#services-firefly-iii-options}

```{=include=} options
id-prefix: services-firefly-iii-options-
list-id: selfhostblocks-service-firefly-iii-options
source: @OPTIONS_JSON@
```
