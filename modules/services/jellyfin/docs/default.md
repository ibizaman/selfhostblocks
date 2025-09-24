# Jellyfin Service {#services-jellyfin}

Defined in [`/modules/services/jellyfin.nix`](@REPO@/modules/services/jellyfin.nix).

This NixOS module is a service that sets up a [Jellyfin](https://jellyfin.org/) instance.

Compared to the stock module from nixpkgs,
this one sets up, in a fully declarative manner
the initial wizard with an admin user
and LDAP and SSO integration.

## Features {#services-jellyfin-features}

- Declarative creation of admin user.
- Declarative selection of listening port.
- Access through [subdomain](#services-jellyfin-options-shb.jellyfin.subdomain) using reverse proxy. [Manual](#services-jellyfin-usage-configuration).
- Access through [HTTPS](#services-jellyfin-options-shb.jellyfin.ssl) using reverse proxy. [Manual](#services-jellyfin-usage-https).
- Declarative [LDAP](#services-jellyfin-options-shb.jellyfin.ldap) configuration. [Manual](#services-jellyfin-usage-ldap).
- Declarative [SSO](#services-jellyfin-options-shb.jellyfin.sso) configuration. [Manual](#services-jellyfin-usage-sso).
- [Backup](#services-jellyfin-options-shb.jellyfin.backup) through the [backup block](./blocks-backup.html). [Manual](#services-jellyfin-usage-backup).

## Usage {#services-jellyfin-usage}

### Initial Configuration {#services-jellyfin-usage-configuration}

The following snippet enables Jellyfin and makes it available under the `jellyfin.example.com` endpoint.

```nix
shb.jellyfin = {
  enable = true;
  subdomain = "jellyfin";
  domain = "example.com";

  admin = {
    username = "admin";
    password.result = config.shb.sops.secret.jellyfinAdminPassword.result;
  };
};

shb.sops.secret.jellyfinAdminPassword.request = config.shb.jellyfin.admin.password.request;
```

This assumes secrets are setup with SOPS
as mentioned in [the secrets setup section](usage.html#usage-secrets) of the manual.

### Jellyfin through HTTPS {#services-jellyfin-usage-https}

:::: {.note}
We will build upon the [Initial Configuration](#services-jellyfin-usage-configuration) section,
so please follow that first.
::::

If the `shb.ssl` block is used (see [manual](blocks-ssl.html#usage) on how to set it up),
the instance will be reachable at `https://jellyfin.example.com`.

Here is an example with Let's Encrypt certificates, validated using the HTTP method.
First, set the global configuration for your domain:

```nix
shb.certs.certs.letsencrypt."example.com" = {
  domain = "example.com";
  group = "nginx";
  reloadServices = [ "nginx.service" ];
  adminEmail = "myemail@mydomain.com";
};
```

Then you can tell Jellyfin to use those certificates.

```nix
shb.certs.certs.letsencrypt."example.com".extraDomains = [ "jellyfin.example.com" ];

shb.jellyfin = {
  ssl = config.shb.certs.certs.letsencrypt."example.com";
};
```

### With LDAP Support {#services-jellyfin-usage-ldap}

:::: {.note}
We will build upon the [HTTPS](#services-jellyfin-usage-https) section,
so please follow that first.
::::

We will use the [LLDAP block][] provided by Self Host Blocks.
Assuming it [has been set already][LLDAP block setup], add the following configuration:

[LLDAP block]: blocks-lldap.html
[LLDAP block setup]: blocks-lldap.html#blocks-lldap-global-setup

```nix
shb.jellyfin.ldap
  enable = true;
  host = "127.0.0.1";
  port = config.shb.lldap.ldapPort;
  dcdomain = config.shb.lldap.dcdomain;
  adminPassword.result = config.shb.sops.secrets."jellyfin/ldap/adminPassword".result
};

shb.sops.secrets."jellyfin/ldap/adminPassword" = {
  request = config.shb.jellyfin.ldap.adminPassword.request;
  settings.key = "ldap/userPassword";
};
```

The `shb.jellyfin.ldap.adminPasswordFile` must be the same
as the `shb.lldap.ldapUserPasswordFile` which is achieved
with the `key` option.
The other secrets can be randomly generated with
`nix run nixpkgs#openssl -- rand -hex 64`.

And that's it.
Now, go to the LDAP server at `http://ldap.example.com`,
create the `jellyfin_user` and `jellyfin_admin` groups,
create a user and add it to one or both groups.
When that's done, go back to the Jellyfin server at
`http://jellyfin.example.com` and login with that user.

Work is in progress to make the creation of the LDAP user and group declarative too.

### With SSO Support {#services-jellyfin-usage-sso}

:::: {.note}
We will build upon the [LDAP](#services-jellyfin-usage-ldap) section,
so please follow that first.
::::

We will use the [SSO block][] provided by Self Host Blocks.
Assuming it [has been set already][SSO block setup], add the following configuration:

[SSO block]: blocks-sso.html
[SSO block setup]: blocks-sso.html#blocks-sso-global-setup

```nix
shb.jellyfin.sso = {
  enable = true;
  endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

  secretFile = <path/to/oidcJellyfinSharedSecret>;
  secretFileForAuthelia = <path/to/oidcJellyfinSharedSecret>;
};
```

Passing the `ssl` option will auto-configure nginx to force SSL connections with the given
certificate.

The `shb.jellyfin.sso.secretFile` and `shb.jellyfin.sso.secretFileForAuthelia` options
must have the same content. The former is a file that must be owned by the `jellyfin` user while
the latter must be owned by the `authelia` user. I want to avoid needing to define the same secret
twice with a future secrets SHB block.

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

## Debug {#services-jellyfin-debug}

In case of an issue, check the logs for systemd service `jellyfin.service`.

Enable verbose logging by setting the `shb.jellyfin.debug` boolean to `true`.

## Options Reference {#services-jellyfin-options}

```{=include=} options
id-prefix: services-jellyfin-options-
list-id: selfhostblocks-service-jellyfin-options
source: @OPTIONS_JSON@
```
