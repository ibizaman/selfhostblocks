# Nextcloud Server Service {#services-nextcloud-server}

Defined in [`/modules/services/nextcloud-server.nix`](@REPO@/modules/services/nextcloud-server.nix).

This NixOS module is a service that sets up a [Nextcloud Server](https://nextcloud.com/).
It is based on the nixpkgs Nextcloud server and provides opinionated defaults.

## Features {#services-nextcloud-server-features}

- Declarative [Apps](#services-nextcloud-server-options-shb.nextcloud.apps) Configuration - no need
  to configure those with the UI.
  - [LDAP](#services-nextcloud-server-usage-ldap) app:
    enables app and sets up integration with an existing LDAP server, in this case LLDAP.
  - [OIDC](#services-nextcloud-server-usage-oidc) app:
    enables app and sets up integration with an existing OIDC server, in this case Authelia.
  - [Preview Generator](#services-nextcloud-server-usage-previewgenerator) app:
    enables app and sets up required cron job.
  - [External Storage](#services-nextcloud-server-usage-externalstorage) app:
    enables app and optionally configures one local mount.
    This enables having data living on separate hard drives.
  - [Only Office](#services-nextcloud-server-usage-onlyoffice) app:
    enables app and sets up Only Office service.
  - Any other app through the
    [shb.nextcloud.extraApps](#services-nextcloud-server-options-shb.nextcloud.extraApps) option.
- Access through subdomain using reverse proxy.
- Forces Nginx as the reverse proxy. (This is hardcoded in the upstream nixpkgs module).
- Sets good defaults for trusted proxies settings, chunk size, opcache php options.
- Access through HTTPS using reverse proxy.
- Forces PostgreSQL as the database.
- Forces Redis as the cache and sets good defaults.
- Backup of the [`shb.nextcloud.dataDir`][dataDir] through the [backup block](./blocks-backup.html).
- Monitoring of reverse proxy, PHP-FPM, and database backups through the [monitoring
  block](./blocks-monitoring.html).
- [Integration Tests](@REPO@/test/services/nextcloud.nix)
  - Tests system cron job is setup correctly.
  - Tests initial admin user and password are setup correctly.
  - Tests admin user can create and retrieve a file through WebDAV.
- Enables easy setup of xdebug for PHP debugging if needed.
- Easily add other apps declaratively through [extraApps][]
- By default automatically disables maintenance mode on start.
- By default automatically launches repair mode with expensive migrations on start.
- Access to advanced options not exposed here thanks to how NixOS modules work.
- Has a [demo](#services-nextcloud-server-demo).

[dataDir]: ./services-nextcloud.html#services-nextcloud-server-options-shb.nextcloud.dataDir

## Usage {#services-nextcloud-server-usage}

### Nextcloud through HTTP {#services-nextcloud-server-usage-basic}

[HTTP]: #services-nextcloud-server-usage-basic

:::: {.note}
This section corresponds to the `basic` section of the [Nextcloud
demo](demo-nextcloud-server.html#demo-nextcloud-deploy-basic).
::::

Configuring Nextcloud to be accessible through Nginx reverse proxy
at the address `http://n.example.com`,
with PostgreSQL and Redis configured,
is done like so:

```nix
shb.nextcloud = {
  enable = true;
  domain = "example.com";
  subdomain = "n";
  defaultPhoneRegion = "US";
  adminPass.result.path = config.sops.secrets."nextcloud/adminpass".path;
};

sops.secrets."nextcloud/adminpass" = config.shb.nextcloud.adminPass.request;
```

This assumes secrets are setup with SOPS as mentioned in [the secrets setup section](usage.html#usage-secrets) of the manual.
Secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.

Note though that Nextcloud will not be very happy to be accessed through HTTP,
it much prefers - rightfully - to be accessed through HTTPS.
We will set that up in the next section.

You can now login as the admin user using the username `admin`
and the password defined in `sops.secrets."nextcloud/adminpass"`.

### Nextcloud through HTTPS {#services-nextcloud-server-usage-https}

[HTTPS]: #services-nextcloud-server-usage-https

To setup HTTPS, we will get our certificates from Let's Encrypt using the HTTP method.
This is the easiest way to get started and does not require you to programmatically 
configure a DNS provider.

Under the hood, we use the Self Host Block [SSL contract](./contracts-ssl.html).
It allows the end user to choose how to generate the certificates.
If you want other options to generate the certificate, follow the SSL contract link.

Building upon the [Basic Configuration](#services-nextcloud-server-usage-basic) above, we add:

```nix
shb.certs.certs.letsencrypt."example.com" = {
  domain = "example.com";
  group = "nginx";
  reloadServices = [ "nginx.service" ];
  adminEmail = "myemail@mydomain.com";
};

shb.certs.certs.letsencrypt."example.com".extraDomains = [ "n.example.com" ];

shb.nextcloud = {
  ssl = config.shb.certs.certs.letsencrypt."example.com";
};
```

### Choose Nextcloud Version {#services-nextcloud-server-usage-version}

Self Host Blocks is conservative in the version of Nextcloud it's using.
To choose the version and upgrade at the time of your liking,
just use the [version](#services-nextcloud-server-options-shb.nextcloud.version) option:

```nix
shb.nextcloud.version = 29;
```

### Mount Point {#services-nextcloud-server-usage-mount-point}

If the `dataDir` exists in a mount point,
it is highly recommended to make the various Nextcloud services wait on the mount point before starting.
Doing that is just a matter of setting the `mountPointServices` option.

Assuming a mount point on `/var`, the configuration would look like so:

```nix
fileSystems."/var".device = "...";
shb.nextcloud.mountPointServices = [ "var.mount" ];
```

### With LDAP Support {#services-nextcloud-server-usage-ldap}

[LDAP]: #services-nextcloud-server-usage-ldap

:::: {.note}
This section corresponds to the `ldap` section of the [Nextcloud
demo](demo-nextcloud-server.html#demo-nextcloud-deploy-ldap).
::::

We will build upon the [HTTP][] and [HTTPS][] sections,
so please read those first.
We will use the LDAP block provided by Self Host Blocks to setup a
[LLDAP](https://github.com/lldap/lldap) service.
If did already configure this for another service, you can skip this snippet.

```nix
shb.ldap = {
  enable = true;
  domain = "example.com";
  subdomain = "ldap";
  ldapPort = 3890;
  webUIListenPort = 17170;
  dcdomain = "dc=example,dc=com";
  ldapUserPassword.result.path = config.sops.secrets."ldap/userPassword".path;
  jwtSecret.result.path = config.sops.secrets."ldap/jwtSecret".path;
};

sops.secrets."ldap/userPassword" = config.shb.ldap.userPassword.request;
sops.secrets."ldap/jwtSecret" = config.shb.ldap.jwtSecret.request;
```

On the `nextcloud` module side, we need to configure it to talk to the LDAP server we
just defined:

```nix
shb.nextcloud.apps.ldap = {
  enable = true;
  host = "127.0.0.1";
  port = config.shb.ldap.ldapPort;
  dcdomain = config.shb.ldap.dcdomain;
  adminName = "admin";
  adminPassword.result.path = config.sops.secrets."nextcloud/ldapUserPassword".path
  userGroup = "nextcloud_user";
};

sops.secrets."nextcloud/ldapUserPassword" = config.shb.nextcloud.adminPasswordFile.request // {
  key = "ldap/userPassword";
};
```

The LDAP admin password must be shared between `shb.ldap` and `shb.nextcloud`,
to do that with SOPS we use the `key` option so that both
`sops.secrets."ldap/userPassword"`
and `sops.secrets."nextcloud/ldapUserPassword"`
secrets have the same content.

Creating LDAP users and groups is not declarative yet,
so go to the LDAP server at `http://ldap.example.com`,
create the `nextcloud_user` group,
create a user and add it to the group.
When that's done, go back to the Nextcloud server at
`https://nextcloud.example.com` and login with that user.

Note that we cannot create an admin user from the LDAP server,
so you need to create a normal user like above,
login with it once so it is known to Nextcloud, then logout,
login with the admin Nextcloud user and promote that new user to admin level.

### With OIDC Support {#services-nextcloud-server-usage-oidc}

:::: {.note}
This section corresponds to the `sso` section of the [Nextcloud
demo](demo-nextcloud-server.html#demo-nextcloud-deploy-sso).
::::

We will build upon the [HTTP][], [HTTPS][] and [LDAP][] sections,
so please read those first.
We need to setup the SSO provider, here Authelia, thanks to the corresponding SHB block
and we link it to the LDAP server:

```nix
shb.authelia = {
  enable = true;
  domain = "example.com";
  subdomain = "auth";
  ssl = config.shb.certs.certs.letsencrypt."example.com";

  ldapHostname = "127.0.0.1";
  ldapPort = config.shb.ldap.ldapPort;
  dcdomain = config.shb.ldap.dcdomain;

  smtp = {
    host = "smtp.eu.mailgun.org";
    port = 587;
    username = "postmaster@mg.example.com";
    from_address = "authelia@example.com";
    password.result.path = config.sops.secrets."authelia/smtp_password".path;
  };

  secrets = {
    jwtSecret.result.path = config.sops.secrets."authelia/jwt_secret".path;
    ldapAdminPassword.result.path = config.sops.secrets."authelia/ldap_admin_password".path;
    sessionSecret.result.path = config.sops.secrets."authelia/session_secret".path;
    storageEncryptionKey.result.path = config.sops.secrets."authelia/storage_encryption_key".path;
    identityProvidersOIDCHMACSecret.result.path = config.sops.secrets."authelia/hmac_secret".path;
    identityProvidersOIDCIssuerPrivateKey.result.path = config.sops.secrets."authelia/private_key".path;
  };
};

sops.secrets."authelia/jwt_secret" = config.shb.authelia.secrets.jwtSecret.request;
sops.secrets."authelia/ldap_admin_password" = config.shb.authelia.secrets.ldapAdminPassword.request;
sops.secrets."authelia/session_secret" = config.shb.authelia.secrets.sessionSecret.request;
sops.secrets."authelia/storage_encryption_key" = config.shb.authelia.secrets.storageEncryptionKey.request;
sops.secrets."authelia/hmac_secret" = config.shb.authelia.secrets.identityProvidersOIDCHMACSecret.request;
sops.secrets."authelia/private_key" = config.shb.authelia.secrets.identityProvidersOIDCIssuerPrivateKey.request;
sops.secrets."authelia/smtp_password" = config.shb.authelia.smtp.password.request;
```

The secrets can be randomly generated with `nix run nixpkgs#openssl -- rand -hex 64`.

Now, on the Nextcloud side, you need to add the following options:

```nix
shb.nextcloud.apps.sso = {
  enable = true;
  endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
  clientID = "nextcloud";
  fallbackDefaultAuth = false;

  secret.result.path = config.sops.secrets."nextcloud/sso/secret".path;
  secretForAuthelia.result.path = config.sops.secrets."nextcloud/sso/secretForAuthelia".path;
};

sops.secret."nextcloud/sso/secret" = config.shb.nextcloud.apps.sso.secret.request;
sops.secret."nextcloud/sso/secretForAuthelia" = config.shb.nextcloud.apps.sso.secretForAuthelia.request // {
  key = "nextcloud/sso/secret";
};
```

The SSO secret must be shared between `shb.authelia` and `shb.nextcloud`,
to do that with SOPS we use the `key` option so that both
`sops.secrets."nextcloud/sso/secret"`
and `sops.secrets."nextcloud/sso/secretForAuthelia"`
secrets have the same content.

Setting the `fallbackDefaultAuth` to `false` means the only way to login is through Authelia.
If this does not work for any reason, you can let users login through Nextcloud directly by setting this option to `true`.

### Tweak PHPFpm Config {#services-nextcloud-server-usage-phpfpm}

For instances with more users, or if you feel the pages are loading slowly,
you can tweak the `php-fpm` pool settings.

```nix
shb.nextcloud.phpFpmPoolSettings = {
  "pm" = "static"; # Can be dynamic
  "pm.max_children" = 150;
  # "pm.start_servers" = 300;
  # "pm.min_spare_servers" = 300;
  # "pm.max_spare_servers" = 500;
  # "pm.max_spawn_rate" = 50;
  # "pm.max_requests" = 50;
  # "pm.process_idle_timeout" = "20s";
};
```

I don't have a good heuristic for what are good values here but what I found
is that you don't want too high of a `max_children` value
to avoid I/O strain on the hard drives, especially if you use spinning drives.

### Tweak PostgreSQL Settings {#services-nextcloud-server-usage-postgres}

These settings will impact all databases since the NixOS Postgres module
configures only one Postgres instance.

To know what values to put here, use [https://pgtune.leopard.in.ua/](https://pgtune.leopard.in.ua/).
Remember the server hosting PostgreSQL is shared at least with the Nextcloud service and probably others.
So to avoid PostgreSQL hogging all the resources, reduce the values you give on that website
for CPU, available memory, etc.
For example, I put 12 GB of memory and 4 CPUs while I had more:

- `DB Version`: 14
- `OS Type`: linux
- `DB Type`: dw
- `Total Memory (RAM)`: 12 GB
- `CPUs num`: 4
- `Data Storage`: ssd

And got the following values:

```nix
shb.nextcloud.postgresSettings = {
  max_connections = "400";
  shared_buffers = "3GB";
  effective_cache_size = "9GB";
  maintenance_work_mem = "768MB";
  checkpoint_completion_target = "0.9";
  wal_buffers = "16MB";
  default_statistics_target = "100";
  random_page_cost = "1.1";
  effective_io_concurrency = "200";
  work_mem = "7864kB";
  huge_pages = "off";
  min_wal_size = "1GB";
  max_wal_size = "4GB";
  max_worker_processes = "4";
  max_parallel_workers_per_gather = "2";
  max_parallel_workers = "4";
  max_parallel_maintenance_workers = "2";
};
```

### Backup {#services-nextcloud-server-usage-backup}

Backing up Nextcloud data files using the [Restic block](blocks-restic.html) is done like so:

```nix
shb.restic.instances."nextcloud" = {
  request = config.shb.nextcloud.backup;
  settings = {
    enable = true;
  };
};
```

The name `"nextcloud"` in the `instances` can be anything.
The `config.shb.nextcloud.backup` option provides what directories to backup.
You can define any number of Restic instances to backup Nextcloud multiple times.

For backing up the Nextcloud database using the same Restic block, do like so:

```nix
shb.restic.instances."postgres" = {
  request = config.shb.postgresql.databasebackup;
  settings = {
    enable = true;
  };
};
```

Note that this will backup the whole PostgreSQL instance,
not just the Nextcloud database.
This limitation will be lifted in the future.

### Enable Preview Generator App {#services-nextcloud-server-usage-previewgenerator}

The following snippet installs and enables the [Preview
Generator](https://apps.nextcloud.com/apps/previewgenerator) application as well as creates the
required cron job that generates previews every 10 minutes.

```nix
shb.nextcloud.apps.previewgenerator.enable = true;
```

Note that you still need to generate the previews for any pre-existing files with:

```bash
nextcloud-occ -vvv preview:generate-all
```

The default settings generates all possible sizes which is a waste since most are not used. SHB will
change the generation settings to optimize disk space and CPU usage as outlined in [this
article](http://web.archive.org/web/20200513043150/https://ownyourbits.com/2019/06/29/understanding-and-improving-nextcloud-previews/).
You can opt-out with:

```nix
shb.nextcloud.apps.previewgenerator.recommendedSettings = false;
```

### Enable External Storage App {#services-nextcloud-server-usage-externalstorage}

The following snippet installs and enables the [External
Storage](https://docs.nextcloud.com/server/28/go.php?to=admin-external-storage) application.

```nix
shb.nextcloud.apps.externalStorage.enable = true;
```

Adding external storage can then be done through the UI.
For the special case of mounting a local folder as an external storage,
Self Host Blocks provides options.
The following snippet will mount the `/srv/nextcloud/$user` local file
in each user's `/home` Nextcloud directory.

```nix
shb.nextcloud.apps.externalStorage.userLocalMount = {
  rootDirectory = "/srv/nextcloud/$user";
  mountName = "home";
};
```

You can even make the external storage mount in the root `/` Nextcloud directory with:

```nix
shb.nextcloud.apps.externalStorage.userLocalMount = {
  mountName = "/";
};
```

Recommended use of this app is to have the Nextcloud's `dataDir` on a SSD
and the `userLocalMount` on a HDD.
Indeed, a SSD is much quicker than a spinning hard drive,
which is well suited for randomly accessing small files like thumbnails.
On the other side, a spinning hard drive can store more data
which is well suited for storing user data.

### Enable OnlyOffice App {#services-nextcloud-server-usage-onlyoffice}

The following snippet installs and enables the [Only
Office](https://apps.nextcloud.com/apps/onlyoffice) application as well as sets up an Only Office
instance listening at `onlyoffice.example.com` that only listens on the local network.

```nix
shb.nextcloud.apps.onlyoffice = {
  enable = true;
  subdomain = "onlyoffice";
  localNextworkIPRange = "192.168.1.1/24";
};
```

Also, you will need to explicitly allow the package `corefonts`:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
  "corefonts"
];
```

### Enable Monitoring {#services-nextcloud-server-server-usage-monitoring}

Enable the [monitoring block](./blocks-monitoring.html).
A [Grafana dashboard][] for overall server performance will be created
and the Nextcloud metrics will automatically appear there.

[Grafana dashboard]: ./blocks-monitoring.html#blocks-monitoring-performance-dashboard

### Enable Tracing {#services-nextcloud-server-server-usage-tracing}

You can enable tracing with:

```nix
shb.nextcloud.debug = true;
```

Traces will be located at `/var/log/xdebug`.
See [my blog post][] for how to look at the traces.
I want to make the traces available in Grafana directly
but that's not the case yet.

[my blog post]: http://blog.tiserbox.com/posts/2023-08-12-what%27s-up-with-nextcloud-webdav-slowness.html

### Appdata Location {#services-nextcloud-server-server-usage-appdata}

The appdata folder is a special folder located under the `shb.nextcloud.dataDir` directory.
It is named `appdata_<instanceid>` with the Nextcloud's instance ID as a suffix.
You can find your current instance ID with `nextcloud-occ config:system:get instanceid`.
In there, you will find one subfolder for every installed app that needs to store files.

For performance reasons, it is recommended to store this folder on a fast drive
that is optimized for randomized read and write access.
The best would be either an SSD or an NVMe drive.

The best way to solve this is to use the [External Storage app](#services-nextcloud-server-usage-externalstorage).

If you have an existing installation and put Nextcloud's `shb.nextcloud.dataDir` folder on a HDD with spinning disks,
then the appdata folder is also located on spinning drives.
One way to solve this is to bind mount a folder from an SSD over the appdata folder.
SHB does not provide a declarative way to setup this
as the external storage app is the preferred way
but this command should be enough:

```bash
mount /dev/sdd /srv/sdd
mkdir -p /srv/sdd/appdata_nextcloud
mount --bind /srv/sdd/appdata_nextcloud /var/lib/nextcloud/data/appdata_ocxvky2f5ix7
```

Note that you can re-generate a new appdata folder
by issuing the command `nextcloud-occ config:system:delete instanceid`.

## Demo {#services-nextcloud-server-demo}

Head over to the [Nextcloud demo](demo-nextcloud-server.html) for a demo that installs Nextcloud with or
without LDAP integration on a VM with minimal manual steps.

## Maintenance {#services-nextcloud-server-maintenance}

On the command line, the `occ` tool is called `nextcloud-occ`.

## Debug {#services-nextcloud-server-debug}

In case of an issue, check the logs for any systemd service mentioned in this section.

On startup, the oneshot systemd service `nextcloud-setup.service` starts. After it finishes, the
`phpfpm-nextcloud.service` starts to serve Nextcloud. The `nginx.service` is used as the reverse
proxy. `postgresql.service` run the database.

Nextcloud' configuration is found at `${shb.nextcloud.dataDir}/config/config.php`. Nginx'
configuration can be found with `systemctl cat nginx | grep -om 1 -e "[^ ]\+conf"`.

Enable verbose logging by setting the `shb.nextcloud.debug` boolean to `true`.

Access the database with `sudo -u nextcloud psql`.

Access Redis with `sudo -u nextcloud redis-cli -s /run/redis-nextcloud/redis.sock`.

## Options Reference {#services-nextcloud-server-options}

```{=include=} options
id-prefix: services-nextcloud-server-options-
list-id: selfhostblocks-service-nextcloud-options
source: @OPTIONS_JSON@
```
