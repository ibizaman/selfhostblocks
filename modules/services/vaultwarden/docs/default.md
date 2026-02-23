# Vaultwarden Service {#services-vaultwarden}

Defined in [`/modules/services/vaultwarden.nix`](@REPO@/modules/services/vaultwarden.nix).

This NixOS module is a service that sets up a [Vaultwarden Server](https://github.com/dani-garcia/vaultwarden).

## Features {#services-vaultwarden-features}

- Access through subdomain using reverse proxy.
- Access through HTTPS using reverse proxy.
- Automatic setup of Redis database for caching.
- Backup of the data directory through the [backup contract](./contracts-backup.html).
- [Integration Tests](@REPO@/test/services/vaultwarden.nix)
  - Tests /admin can only be accessed when authenticated with SSO.
- Integration with the [dashboard contract](contracts-dashboard.html) for displaying user facing application in a dashboard.

## Usage {#services-vaultwarden-usage}

### Initial Configuration {#services-vaultwarden-usage-configuration}

The following snippet enables Vaultwarden and makes it available under the `vaultwarden.example.com` endpoint.

```nix
shb.vaultwarden = {
  enable = true;
  domain = "example.com";
  subdomain = "vaultwarden";

  port = 8222;

  databasePassword.result = config.shb.sops.secret."vaultwarden/db".result;

  smtp = {
    host = "smtp.eu.mailgun.org";
    port = 587;
    username = "postmaster@mg.${domain}";
    from_address = "authelia@${domain}";
    passwordFile = config.sops.secrets."vaultwarden/smtp".path;
  };
};

shb.sops.secret."vaultwarden/db".request = config.shb.vaultwarden.databasePassword.request;
shb.sops.secret."vaultwarden/smtp".request = config.shb.vaultwarden.smtp.password.request;
```

This assumes secrets are setup with SOPS
as mentioned in [the secrets setup section](usage.html#usage-secrets) of the manual.
Secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.

The SMTP configuration is needed to invite users to Vaultwarden.

### HTTPS {#services-vaultwarden-usage-https}

If the `shb.ssl` block is used (see [manual](blocks-ssl.html#usage) on how to set it up),
the instance will be reachable at `https://vaultwarden.example.com`.

Here is an example with Let's Encrypt certificates, validated using the HTTP method:

```nix
shb.certs.certs.letsencrypt."example.com" = {
  domain = "example.com";
  group = "nginx";
  reloadServices = [ "nginx.service" ];
  adminEmail = "myemail@mydomain.com";
};
```

Then you can tell Vaultwarden to use those certificates.

```nix
shb.certs.certs.letsencrypt."example.com".extraDomains = [ "vaultwarden.example.com" ];

shb.forgejo = {
  ssl = config.shb.certs.certs.letsencrypt."example.com";
};
```

### SSO {#services-vaultwarden-usage-sso}

To protect the `/admin` endpoint and avoid needing a secret passphrase for it, we can use SSO.

We will use the [SSO block][] provided by Self Host Blocks.
Assuming it [has been set already][SSO block setup], add the following configuration:

[SSO block]: blocks-sso.html
[SSO block setup]: blocks-sso.html#blocks-sso-global-setup

```nix
shb.vaultwarden.authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
```

Now, go to the LDAP server at `https://ldap.example.com`,
create the `vaultwarden_admin` group and add a user to that group.
When that's done, go back to the Vaultwarden server at
`https://vaultwarden.example.com/admin` and login with that user.

### ZFS {#services-vaultwarden-zfs}

Integration with the ZFS block allows to automatically create the relevant datasets.

```nix
shb.zfs.datasets."vaultwarden" = config.shb.vaultwarden.mount;
shb.zfs.datasets."postgresql".path = "/var/lib/postgresql";
```

### Backup {#services-vaultwarden-backup}

Backing up Vaultwarden using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."vaultwarden" = {
  request = config.shb.vaultwarden.backup;
  settings = {
    enable = true;
  };
};
```

The name `"vaultwarden"` in the `instances` can be anything.
The `config.shb.vaultwarden.backup` option provides what directories to backup.
You can define any number of Restic instances to backup Vaultwarden multiple times.

### Application Dashboard {#services-vaultwarden-usage-applicationdashboard}

Integration with the [dashboard contract](contracts-dashboard.html) is provided
by the [dashboard option](#services-vaultwarden-options-shb.vaultwarden.dashboard).

For example using the [Homepage](services-homepage.html) service:

```nix
{
  shb.homepage.servicesGroups.Documents.services.Vaultwarden = {
    sortOrder = 10;
    dashboard.request = config.shb.vaultwarden.dashboard.request;
  };
}
```

## Maintenance {#services-vaultwarden-maintenance}

No command-line tool is provided to administer Vaultwarden.

Instead, the admin section can be found at the `/admin` endpoint.

## Debug {#services-vaultwarden-debug}

In case of an issue, check the logs of the `vaultwarden.service` systemd service.

Enable verbose logging by setting the `shb.vaultwarden.debug` boolean to `true`.

Access the database with `sudo -u vaultwarden psql`.

## Options Reference {#services-vaultwarden-options}

```{=include=} options
id-prefix: services-vaultwarden-options-
list-id: selfhostblocks-vaultwarden-options
source: @OPTIONS_JSON@
```
