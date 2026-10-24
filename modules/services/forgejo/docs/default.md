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
Follow the steps below for a new runner, or the
[migration instructions](#services-forgejo-usage-runner-migration) for an existing one.
Set `shb.forgejo.localActionRunner` explicitly: `true` to enable the runner with
its UUID and token, or `false` to run Forgejo without a local runner. Omitting
this choice or the credentials required for an enabled runner fails evaluation.

The runner uses `services.forgejo-runner.instances.local` and executes jobs with
the `native` label on the host. Add tools through `shb.forgejo.hostPackages`.
Only allow trusted workflows: host jobs share a service account and are not
isolated from one another by containers or virtual machines.

#### Registering a new runner {#services-forgejo-usage-runner-registration}

1. **Start Forgejo without the runner.** Add these settings to your NixOS
   configuration, alongside the [initial Forgejo configuration](#services-forgejo-usage-configuration):

   ```nix
   shb.forgejo.localActionRunner = false;
   environment.systemPackages = [ config.services.forgejo.package ];
   ```

   Activate with `sudo nixos-rebuild switch`, including your usual configuration
   selection arguments such as `--flake`.

2. **Generate the token and register the runner.** Run the following on the
   Forgejo server. These commands assume the default `forgejo` user and
   `/var/lib/forgejo` state directory; adjust them if you customized those settings.

   ```bash
   runner_token=$(forgejo forgejo-cli actions generate-secret)
   printf "%s" "$runner_token" | sudo --user=forgejo env \
     FORGEJO_WORK_DIR=/var/lib/forgejo \
     FORGEJO_CUSTOM=/var/lib/forgejo/custom \
     forgejo forgejo-cli actions register --name local --secret-stdin=true
   ```

   The last command prints the UUID for this token. Save that UUID for step 4;
   do not generate a separate random UUID. If registration fails, retry the
   `register` command with the same `$runner_token` instead of generating another token.

3. **Save the token in SOPS.** Print it in the same shell on the server:

   ```bash
   echo "$runner_token"
   ```

   Add `runner-token` under `forgejo` in your existing SOPS file:

   ```yaml
   forgejo:
     runner-token: "<paste the token here>"
   ```

   Save the encrypted file before closing the shell, then run `unset runner_token`.
   Keep the token out of Nix expressions and the Nix store. See the
   [SOPS setup instructions](usage.html#usage-secrets) if needed.

4. **Configure and enable the runner.** Replace the example UUID below with the
   UUID printed in step 2, and change `localActionRunner` from `false` to `true`:

   ```nix
   {
     shb.forgejo = {
       localActionRunner = true;
       runner.uuid = "c9e50be9-a7c3-4aee-ba35-624c4ff8c519";
       runner.token.result = config.shb.sops.secret."forgejo/runner-token".result;
     };
     shb.sops.secret."forgejo/runner-token".request = config.shb.forgejo.runner.token.request;
   }
   ```

   Activate again with `sudo nixos-rebuild switch` and your usual arguments.
   Confirm that `local` is online in Forgejo's
   **Site Administration → Actions → Runners** page.

See Forgejo's [offline registration guide](https://forgejo.org/docs/v15.0/admin/actions/registration/#offline-registration)
and [CLI reference](https://forgejo.org/docs/v15.0/admin/command-line/#forgejo-cli-actions-register).

#### Migrating from the Gitea runner {#services-forgejo-usage-runner-migration}

Reuse the UUID and operational token from `/var/lib/gitea-runner/local/.runner`
to preserve the existing runner's identity, following the
[nixpkgs migration instructions](https://github.com/NixOS/nixpkgs/blob/5e867b1db0f219e0e906574cca1175f421a87834/nixos/modules/services/continuous-integration/forgejo-runner.nix#L102-L123).
Print the UUID followed by the token:

```bash
sudo jq --raw-output '.uuid, .token' /var/lib/gitea-runner/local/.runner
```

Set `runner.uuid` to the displayed UUID and save the token in SOPS as
`forgejo/runner-token`, using the configuration shown above. Move overrides under
`services.gitea-actions-runner.instances.local` to `services.forgejo-runner.instances.local`;
labels now belong under `settings.runner.labels`.

For example, replace this override:

```nix
services.gitea-actions-runner.instances.local.labels = [ "native:host" "nix:host" ];
```

with:

```nix
services.forgejo-runner.instances.local.settings.runner.labels = [ "native:host" "nix:host" ];
```

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

**Optional cleanup:** once the new runner has completed a workflow, its credentials
are backed up, and you no longer need to roll back to the old runner, remove the
old local runner's identity file, workspace, and caches:

```bash
sudo rm -r /var/lib/gitea-runner/local
```

Remove only `local`; the parent directory may contain other runners. Keep the
runner's registration in Forgejo's UI, because the new service reuses it.

#### Credentials and backups {#services-forgejo-usage-runner-state}

Keep the UUID in your configuration backup and the token in your SOPS
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
