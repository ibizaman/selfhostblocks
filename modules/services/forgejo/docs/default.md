# Forgejo Service {#services-forgejo}

Defined in [`/modules/services/forgejo.nix`](@REPO@/modules/services/forgejo.nix).

This NixOS module is a service that sets up a [Forgejo](https://forgejo.org/) instance.

Compared to the stock module from nixpkgs,
this one sets up, in a fully declarative manner,
LDAP and SSO integration as well as one local runner.

## Features {#services-forgejo-features}

- Declarative creation of users, admin or not.
- Also declarative [LDAP](#services-forgejo-options-shb.forgejo.ldap) Configuration. [Manual](#services-forgejo-usage-ldap).
- Declarative [SSO](#services-forgejo-options-shb.forgejo.sso) Configuration. [Manual](#services-forgejo-usage-sso).
- Declarative [local runner](#services-forgejo-options-shb.forgejo.localActionRunner) Configuration.
- Access through [subdomain](#services-forgejo-options-shb.forgejo.subdomain) using reverse proxy. [Manual](#services-forgejo-usage-configuration).
- Access through [HTTPS](#services-forgejo-options-shb.forgejo.ssl) using reverse proxy. [Manual](#services-forgejo-usage-configuration).
- [Backup](#services-forgejo-options-shb.forgejo.sso) through the [backup block](./blocks-backup.html). [Manual](#services-forgejo-usage-backup).

## Usage {#services-forgejo-usage}

### Initial Configuration {#services-forgejo-usage-configuration}

The following snippet enables Forgejo and makes it available under the `forgejo.example.com` endpoint.

```nix
shb.forgejo = {
  enable = true;
  subdomain = "forgejo";
  domain = "example.com";

  users = {
    "theadmin" = {
      isAdmin = true;
      email = "theadmin@example.com";
      password.result = config.shb.hardcodedsecret.forgejoAdminPassword.result;
    };
    "theuser" = {
      email = "theuser@example.com";
      password.result = config.shb.hardcodedsecret.forgejoUserPassword.result;
    };
  };
};

shb.hardcodedsecret."forgejo/admin/password" = {
  request = config.shb.forgejo.users."theadmin".password.request;
};

shb.hardcodedsecret."forgejo/user/password" = {
  request = config.shb.forgejo.users."theuser".password.request;
};
```

Two users are created, `theadmin` and `theuser`,
respectively with the passwords `forgejo/admin/password`
and `forgejo/user/password` from a SOPS file.

This assumes secrets are setup with SOPS
as mentioned in [the secrets setup section](usage.html#usage-secrets) of the manual.
Secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.

### Forgejo through HTTPS {#services-forgejo-usage-https}

:::: {.note}
We will build upon the [Initial Configuration](#services-forgejo-usage-configuration) section,
so please follow that first.
::::

If the `shb.ssl` block is used (see [manual](blocks-ssl.html#usage) on how to set it up),
the instance will be reachable at `https://forgejo.example.com`.

Here is an example with Let's Encrypt certificates, validated using the HTTP method:

```nix
shb.certs.certs.letsencrypt."example.com" = {
  domain = "example.com";
  group = "nginx";
  reloadServices = [ "nginx.service" ];
  adminEmail = "myemail@mydomain.com";
};
```

Then you can tell Forgejo to use those certificates.

```nix
shb.certs.certs.letsencrypt."example.com".extraDomains = [ "forgejo.example.com" ];

shb.forgejo = {
  ssl = config.shb.certs.certs.letsencrypt."example.com";
};
```

### With LDAP Support {#services-forgejo-usage-ldap}

:::: {.note}
We will build upon the [HTTPS](#services-forgejo-usage-https) section,
so please follow that first.
::::

We will use the LDAP block provided by Self Host Blocks
to setup a [LLDAP](https://github.com/lldap/lldap) service.

```nix
shb.lldap = {
  enable = true;
  domain = "example.com";
  subdomain = "ldap";
  ssl = config.shb.certs.certs.letsencrypt."example.com";
  ldapPort = 3890;
  webUIListenPort = 17170;
  dcdomain = "dc=example,dc=com";
  ldapUserPassword.result = config.shb.sops.secrets."ldap/userPassword".result;
  jwtSecret.result = config.shb.sops.secrets."ldap/jwtSecret".result;
};

shb.certs.certs.letsencrypt."example.com".extraDomains = [ "ldap.example.com" ];

shb.sops.secrets."ldap/userPassword".request = config.shb.lldap.userPassword.request;
shb.sops.secrets."ldap/jwtSecret".request = config.shb.lldap.jwtSecret.request;
```

We also need to configure the `forgejo` service
to talk to the LDAP server we just defined:

```nix
shb.forgejo.ldap
  enable = true;
  host = "127.0.0.1";
  port = config.shb.lldap.ldapPort;
  dcdomain = config.shb.lldap.dcdomain;
  adminPassword.result = config.shb.sops.secrets."forgejo/ldap/adminPassword".result
};

shb.sops.secrets."forgejo/ldap/adminPassword" = {
  request = config.shb.forgejo.ldap.adminPassword.request;
  settings.key = "ldap/userPassword";
};
```

The `shb.forgejo.ldap.adminPasswordFile` must be the same
as the `shb.lldap.ldapUserPasswordFile` which is achieved
with the `key` option.
The other secrets can be randomly generated with
`nix run nixpkgs#openssl -- rand -hex 64`.

And that's it.
Now, go to the LDAP server at `http://ldap.example.com`,
create the `forgejo_user` and `forgejo_admin` groups,
create a user and add it to one or both groups.
When that's done, go back to the Forgejo server at
`http://forgejo.example.com` and login with that user.

### With SSO Support {#services-forgejo-usage-sso}

:::: {.note}
We will build upon the [LDAP](#services-forgejo-usage-ldap) section,
so please follow that first.
::::

We then need to setup the SSO provider,
here Authelia thanks to the corresponding SHB block:

```nix
shb.authelia = {
  enable = true;
  domain = "example.com";
  subdomain = "auth";
  ssl = config.shb.certs.certs.letsencrypt."example.com";

  ldapHostname = "127.0.0.1";
  ldapPort = config.shb.lldap.ldapPort;
  dcdomain = config.shb.lldap.dcdomain;

  secrets = {
    jwtSecret.result = config.shb.sops.secrets."authelia/jwt_secret".result;
    ldapAdminPassword.result = config.shb.sops.secrets."authelia/ldap_admin_password".result;
    sessionSecret.result = config.shb.sops.secrets."authelia/session_secret".result;
    storageEncryptionKey.result = config.shb.sops.secrets."authelia/storage_encryption_key".result;
    identityProvidersOIDCHMACSecret.result = config.shb.sops.secrets."authelia/hmac_secret".result;
    identityProvidersOIDCIssuerPrivateKey.result = config.shb.sops.secrets."authelia/private_key".result;
  };
};

shb.certs.certs.letsencrypt."example.com".extraDomains = [ "auth.example.com" ];

shb.sops.secrets."authelia/jwt_secret".request = config.shb.authelia.secrets.jwtSecret.request;
shb.sops.secrets."authelia/ldap_admin_password".request = config.shb.authelia.secrets.ldapAdminPassword.request;
shb.sops.secrets."authelia/session_secret".request = config.shb.authelia.secrets.sessionSecret.request;
shb.sops.secrets."authelia/storage_encryption_key".request = config.shb.authelia.secrets.storageEncryptionKey.request;
shb.sops.secrets."authelia/hmac_secret".request = config.shb.authelia.secrets.identityProvidersOIDCHMACSecret.request;
shb.sops.secrets."authelia/private_key".request = config.shb.authelia.secrets.identityProvidersOIDCIssuerPrivateKey.request;
shb.sops.secrets."authelia/smtp_password".request = config.shb.authelia.smtp.password.request;
```

The `shb.authelia.secrets.ldapAdminPasswordFile` must be the same
as the `shb.lldap.ldapUserPasswordFile` defined in the previous section.
The other secrets can be randomly generated
with `nix run nixpkgs#openssl -- rand -hex 64`.

Now, on the forgejo side, you need to add the following options:

```nix
shb.forgejo.sso = {
  enable = true;
  endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

  secretFile = <path/to/oidcForgejoSharedSecret>;
  secretFileForAuthelia = <path/to/oidcForgejoSharedSecret>;
};
```

Passing the `ssl` option will auto-configure nginx to force SSL connections with the given
certificate.

The `shb.forgejo.sso.secretFile` and `shb.forgejo.sso.secretFileForAuthelia` options
must have the same content. The former is a file that must be owned by the `forgejo` user while
the latter must be owned by the `authelia` user. I want to avoid needing to define the same secret
twice with a future secrets SHB block.

### Backup {#services-forgejo-usage-backup}

Backing up Forgejo using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."forgejo" = {
  request = config.shb.forgejo.backup;
  settings = {
    enable = true;
  };
};
```

The name `"forgjo"` in the `instances` can be anything.
The `config.shb.forgejo.backup` option provides what directories to backup.
You can define any number of Restic instances to backup Forgejo multiple times.

### Extra Settings {#services-forgejo-usage-extra-settings}

Other Forgejo settings can be accessed through the nixpkgs [stock service][].

[stock service]: https://search.nixos.org/options?channel=24.05&from=0&size=50&sort=alpha_asc&type=packages&query=services.forgejo

## Debug {#services-forgejo-debug}

In case of an issue, check the logs for systemd service `forgejo.service`.

Enable verbose logging by setting the `shb.forgejo.debug` boolean to `true`.

Access the database with `sudo -u forgejo psql`.

## Options Reference {#services-forgejo-options}

```{=include=} options
id-prefix: services-forgejo-options-
list-id: selfhostblocks-service-forgejo-options
source: @OPTIONS_JSON@
```
