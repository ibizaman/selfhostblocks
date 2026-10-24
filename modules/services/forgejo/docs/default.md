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
- Integration with the [dashboard contract](contracts-dashboard.html) for displaying user facing application in a dashboard. [Manual](#services-forgejo-usage-applicationdashboard)

## Usage {#services-forgejo-usage}

### Initial Configuration {#services-forgejo-usage-configuration}

The following snippet enables Forgejo and makes it available under the `forgejo.example.com` endpoint.

```nix
shb.forgejo = {
  enable = true;
  subdomain = "forgejo";
  domain = "example.com";
  localActionRunner = false; # Enable after registering a runner as described below.

  users = {
    "theadmin" = {
      isAdmin = true;
      email = "theadmin@example.com";
      password.result = config.shb.sops.secret.forgejoAdminPassword.result;
    };
    "theuser" = {
      email = "theuser@example.com";
      password.result = config.shb.sops.secret.forgejoUserPassword.result;
    };
  };
};

shb.sops.secret."forgejo/admin/password" = {
  request = config.shb.forgejo.users."theadmin".password.request;
};

shb.sops.secret."forgejo/user/password" = {
  request = config.shb.forgejo.users."theuser".password.request;
};
```

Two users are created, `theadmin` and `theuser`,
respectively with the passwords `forgejo/admin/password`
and `forgejo/user/password` from a SOPS file.

This assumes secrets are setup with SOPS
as mentioned in [the secrets setup section](usage.html#usage-secrets) of the manual.
Secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.

### Local Actions runner {#services-forgejo-usage-runner}

Forgejo runners must be registered once to obtain a UUID and an authentication token.
Supply the UUID in Nix configuration and the token through SHB's secret contract.
The local runner is enabled by default; set `shb.forgejo.localActionRunner = false`
until these credentials are ready. Enabling it without the required configuration
fails evaluation.

For example, with SOPS:

```nix
{
  shb.forgejo = {
    localActionRunner = true;
    runner.uuid = "c9e50be9-a7c3-4aee-ba35-624c4ff8c519"; # Replace with your runner's UUID.
    runner.token.result = config.shb.sops.secret."forgejo/runner-token".result;
  };
  shb.sops.secret."forgejo/runner-token".request = config.shb.forgejo.runner.token.request;
}
```

The UUID is public; keep the token out of Nix expressions and the Nix store.
SOPS is optional: another secret provider can satisfy the same contract, or set
`shb.forgejo.runner.token.result.path` to a root-owned file with mode `0400`.
The file must contain the operational token, without a `TOKEN=` prefix.

The runner uses `services.forgejo-runner.instances.local` and executes jobs with
the `native` label on the host. Add tools through `shb.forgejo.hostPackages`.
Only allow trusted workflows: host jobs share a service account and are not
isolated from one another by containers or virtual machines.

#### Registering a new runner {#services-forgejo-usage-runner-registration}

First activate Forgejo with `shb.forgejo.localActionRunner = false`. As a Forgejo
administrator, open `/admin/actions/runners`, select **Create new runner**, and
create a runner named `local`. Save the displayed UUID in `runner.uuid` and import
the token into your secret provider. Then enable the local runner and activate
the configuration. See [Forgejo's registration guide](https://forgejo.org/docs/v15.0/admin/actions/registration/#interactive-registration).

#### Migrating from the Gitea runner {#services-forgejo-usage-runner-migration}

Reuse the UUID and operational token from `/var/lib/gitea-runner/local/.runner`
to preserve the existing runner's identity, following the
[nixpkgs migration instructions](https://github.com/NixOS/nixpkgs/blob/5e867b1db0f219e0e906574cca1175f421a87834/nixos/modules/services/continuous-integration/forgejo-runner.nix#L102-L123).
Read the UUID and export the token into a private temporary file:

```bash
sudo jq --raw-output .uuid /var/lib/gitea-runner/local/.runner
sudo install --directory --mode=0700 /run/forgejo-runner-migration
sudo sh -c 'umask 077; jq --join-output .token /var/lib/gitea-runner/local/.runner > /run/forgejo-runner-migration/token'
```

Set `runner.uuid` to the displayed value and import the private token file into
your secret provider before rebooting. Move overrides under
`services.gitea-actions-runner.instances.local` to `services.forgejo-runner.instances.local`;
labels now belong under `settings.runner.labels`.

Let running jobs finish, then stop the old runner and activate the configuration:

```bash
sudo systemctl stop gitea-runner-local.service
sudo nixos-rebuild switch
```

Use your usual configuration selection arguments, such as `--flake`. If activation
fails, restart the old runner with `sudo systemctl start gitea-runner-local.service`
while resolving the error. Keep the original `.runner` file and workspace for
rollback with `sudo nixos-rebuild switch --rollback`. The native runner uses
`/var/lib/forgejo-runner/local`, so its job caches start empty.

#### Credentials and backups {#services-forgejo-usage-runner-state}

Keep the UUID in your configuration backup and the token in your secret provider's
backup. Forgejo's database backup preserves the corresponding server registration;
the external token file is not included in Forgejo's dump. Restore matching
credentials and database registration when recovering. The runner workspace and
caches can remain ephemeral because the runner consumes the supplied credentials
on every start.

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

We will use the [LLDAP block][] provided by Self Host Blocks.
Assuming it [has been set already][LLDAP block setup], add the following configuration:

[LLDAP block]: blocks-lldap.html
[LLDAP block setup]: blocks-lldap.html#blocks-lldap-global-setup

```nix
shb.forgejo.ldap = {
  enable = true;
  host = "127.0.0.1";
  port = config.shb.lldap.ldapPort;
  dcdomain = config.shb.lldap.dcdomain;
  adminPassword.result = config.shb.sops.secret."forgejo/ldap/adminPassword".result
};

shb.sops.secret."forgejo/ldap/adminPassword" = {
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

We will use the [SSO block][] provided by Self Host Blocks.
Assuming it [has been set already][SSO block setup], add the following configuration:

[SSO block]: blocks-sso.html
[SSO block setup]: blocks-sso.html#blocks-sso-global-setup

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

### SMTP {#services-forgejo-usage-smtp}

To send e-mails, notifications, define the SMTP settings like so:

```nix
{
  services.forgejo = {
    smtp = {
      host = "smtp.mailgun.org";
      port = 587;
      username = "postmaster@mg.${domain}";
      from_address = "authelia@${domain}";
      password.result = config.shb.sops.secret."forgejo/smtpPassword".result;
    };
  };

  shb.sops.secret."forgejo/smtpPassword" = {
    request = config.shb.forgejo.smtp.password.request;
  };
}
```

### Backup {#services-forgejo-usage-backup}

Every hour, Forgejo takes a backup using the [built-in `dump` command](https://forgejo.org/docs/latest/admin/command-line/#dump).
This backup is ephemeral and should be moved in a permanent location.
This can be accomplished using the following config.

Backing up Forgejo using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."forgejo" = {
  request = config.shb.forgejo.backup;
  settings = {
    enable = true;
  };
};
```

The name `"forgejo"` in the `instances` can be anything.
The `config.shb.forgejo.backup` option provides what directories to backup.
You can define any number of Restic instances to backup Forgejo multiple times.

### Application Dashboard {#services-forgejo-usage-applicationdashboard}

Integration with the [dashboard contract](contracts-dashboard.html) is provided
by the [dashboard option](#services-forgejo-options-shb.forgejo.dashboard).

For example using the [Homepage](services-homepage.html) service:

```nix
{
  shb.homepage.servicesGroups.Admin.services.Forgejo = {
    sortOrder = 1;
    dashboard.request = config.shb.forgejo.dashboard.request;
  };
}
```

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
