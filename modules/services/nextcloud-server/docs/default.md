# Nextcloud Server Service {#services-nextcloud-server}

Defined in [`/modules/services/nextcloud-server.nix`](@REPO@/modules/services/nextcloud-server.nix).

This NixOS module is a service that sets up a [Nextcloud Server](https://nextcloud.com/).

## Features {#services-nextcloud-server-features}

- Declarative [Apps](#services-nextcloud-server-options-shb.nextcloud.apps) Configuration - no need
  to configure those with the UI.
  - [LDAP](#services-nextcloud-server-usage-ldap) app: enables app and sets up integration with an existing LDAP server.
  - [OIDC](#services-nextcloud-server-usage-oidc) app: enables app and sets up integration with an existing OIDC server.
  - [Preview Generator](#services-nextcloud-server-usage-previewgenerator) app: enables app and sets
    up required cron job.
  - [External Storage](#services-nextcloud-server-usage-externalstorage) app: enables app and
    optionally configures one local mount.
  - [Only Office](#services-nextcloud-server-usage-onlyoffice) app: enables app and sets up Only
    Office service.
  - Any other app through the
    [shb.nextcloud.extraApps](#services-nextcloud-server-options-shb.nextcloud.extraApps) option.
- [Demo](./demo-nextcloud-server.html)
  - Demo deploying a Nextcloud server with [Colmena](https://colmena.cli.rs/) and with proper
    secrets management with [sops-nix](https://github.com/Mic92/sops-nix).
- Access through subdomain using reverse proxy.
- Access through HTTPS using reverse proxy.
- Automatic setup of PostgreSQL database.
- Automatic setup of Redis database for caching.
- Backup of the [`shb.nextcloud.dataDir`][1] through the [backup block](./blocks-backup.html).
- Monitoring of reverse proxy, PHP-FPM, and database backups through the [monitoring
  block](./blocks-monitoring.html).
- [Integration Tests](@REPO@/test/services/nextcloud.nix)
  - Tests system cron job is setup correctly.
  - Tests initial admin user and password are setup correctly.
  - Tests admin user can create and retrieve a file through WebDAV.
- Access to advanced options not exposed here thanks to how NixOS modules work.

[1]: ./services-nextcloud.html#services-nextcloud-server-options-shb.nextcloud.dataDir

## Usage {#services-nextcloud-server-usage}

### Secrets {#services-nextcloud-server-secrets}

All the secrets should be readable by the nextcloud user.

Secrets should not be stored in the nix store. If you're using
[sops-nix](https://github.com/Mic92/sops-nix) and assuming your secrets file is located at
`./secrets.yaml`, you can define a secret with:

```nix
sops.secrets."nextcloud/adminpass" = {
  sopsFile = ./secrets.yaml;
  mode = "0400";
  owner = "nextcloud";
  group = "nextcloud";
  restartUnits = [ "phpfpm-nextcloud.service" ];
};
```

Then you can use that secret:

```nix
shb.nextcloud.adminPassFile = config.sops.secrets."nextcloud/adminpass".path;
```

### Nextcloud through HTTP {#services-nextcloud-server-usage-basic}

:::: {.note}
This section corresponds to the `basic` section of the [Nextcloud
demo](demo-nextcloud-server.html#demo-nextcloud-deploy-basic).
::::

This will set up a Nextcloud service that runs on the NixOS target machine, reachable at
`http://nextcloud.example.com`. If the `shb.ssl` block is [enabled](blocks-ssl.html#usage), the
instance will be reachable at `https://nextcloud.example.com`.

```nix
shb.nextcloud = {
  enable = true;
  domain = "example.com";
  subdomain = "nextcloud";
  dataDir = "/var/lib/nextcloud";
  adminPassFile = <path/to/secret>;
};
```

After deploying, the Nextcloud server will be reachable at `http://nextcloud.example.com`.

### Mount Point  {#services-nextcloud-server-mount-point}

If the `dataDir` exists in a mount point, it is highly recommended to make the various Nextcloud
services wait on the mount point before starting. Doing that is just a matter of setting the `mountPointServices` option.

Assuming a mount point on `/var`, the configuration would look like so:

```nix
fileSystems."/var".device = "...";
shb.nextcloud.mountPointServices = [ "var.mount" ];
```

### With LDAP Support {#services-nextcloud-server-usage-ldap}

:::: {.note}
This section corresponds to the `ldap` section of the [Nextcloud
demo](demo-nextcloud-server.html#demo-nextcloud-deploy-ldap).
::::

We will build upon the [Basic Configuration](#services-nextcloud-server-usage-basic) section, so
please read that first.

We will use the LDAP block provided by Self Host Blocks to setup a
[LLDAP](https://github.com/lldap/lldap) service.

```nix
shb.ldap = {
  enable = true;
  domain = "example.com";
  subdomain = "ldap";
  ldapPort = 3890;
  webUIListenPort = 17170;
  dcdomain = "dc=example,dc=com";
  ldapUserPasswordFile = <path/to/ldapUserPasswordSecret>;
  jwtSecretFile = <path/to/ldapJwtSecret>;
};
```

We also need to configure the `nextcloud` Self Host Blocks service to talk to the LDAP server we
just defined:

```nix
shb.nextcloud.apps.ldap
  enable = true;
  host = "127.0.0.1";
  port = config.shb.ldap.ldapPort;
  dcdomain = config.shb.ldap.dcdomain;
  adminName = "admin";
  adminPasswordFile = <path/to/ldapUserPasswordSecret>;
  userGroup = "nextcloud_user";
};
```

The `shb.nextcloud.apps.ldap.adminPasswordFile` must be the same as the
`shb.ldap.ldapUserPasswordFile`. The other secret can be randomly generated with `nix run
nixpkgs#openssl -- rand -hex 64`.

And that's it. Now, go to the LDAP server at `http://ldap.example.com`, create the `nextcloud_user`
group, create a user and add it to the group. When that's done, go back to the Nextcloud server at
`http://nextcloud.example.com` and login with that user.

Note that we cannot create an admin user from the LDAP server, so you need to create a normal user
like above, login with it once so it is known to Nextcloud, then logout, login with the admin
Nextcloud user and promote that new user to admin level.

### With OIDC Support {#services-nextcloud-server-usage-oidc}

:::: {.note}
This section corresponds to the `sso` section of the [Nextcloud
demo](demo-nextcloud-server.html#demo-nextcloud-deploy-sso).
::::

We will build upon the [Basic Configuration](#services-nextcloud-server-usage-basic) and [With LDAP
Support](#services-nextcloud-server-usage-ldap) sections, so please read those first and setup the
LDAP app as described above.

Here though, we must setup SSL certificates because the SSO provider only works with the https
protocol. This is actually quite easy thanks to the [SSL block](blocks-ssl.html). For example, with
self-signed certificates:

```nix
shb.certs = {
  cas.selfsigned.myca = {
    name = "My CA";
  };
  certs.selfsigned = {
    nextcloud = {
      ca = config.shb.certs.cas.selfsigned.myca;
      domain = "nextcloud.example.com";
    };
    auth = {
      ca = config.shb.certs.cas.selfsigned.myca;
      domain = "auth.example.com";
    };
    ldap = {
      ca = config.shb.certs.cas.selfsigned.myca;
      domain = "ldap.example.com";
    };
  };
};
```

We need to setup the SSO provider, here Authelia thanks to the corresponding SHB block:

```nix
shb.authelia = {
  enable = true;
  domain = "example.com";
  subdomain = "auth";
  ssl = config.shb.certs.certs.selfsigned.auth;

  ldapHostname = "127.0.0.1";
  ldapPort = config.shb.ldap.ldapPort;
  dcdomain = config.shb.ldap.dcdomain;

  secrets = {
    jwtSecretFile = <path/to/autheliaJwtSecret>;
    ldapAdminPasswordFile = <path/to/ldapUserPasswordSecret>;
    sessionSecretFile = <path/to/autheliaSessionSecret>;
    storageEncryptionKeyFile = <path/to/autheliaStorageEncryptionKeySecret>;
    identityProvidersOIDCHMACSecretFile = <path/to/providersOIDCHMACSecret>;
    identityProvidersOIDCIssuerPrivateKeyFile = <path/to/providersOIDCIssuerSecret>;
  };
};
```

The `shb.authelia.secrets.ldapAdminPasswordFile` must be the same as the
`shb.ldap.ldapUserPasswordFile` defined in the previous section. The secrets can be randomly
generated with `nix run nixpkgs#openssl -- rand -hex 64`.

Now, on the Nextcloud side, you need to add the following options:

```nix
shb.nextcloud.ssl = config.shb.certs.certs.selfsigned.nextcloud;

shb.nextcloud.apps.sso = {
  enable = true;
  endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
  clientID = "nextcloud";
  fallbackDefaultAuth = false;

  secretFile = <path/to/oidcNextcloudSharedSecret>;
  secretFileForAuthelia = <path/to/oidcNextcloudSharedSecret>;
};
```

Passing the `ssl` option will auto-configure nginx to force SSL connections with the given
certificate.

The `shb.nextcloud.apps.sso.secretFile` and `shb.nextcloud.apps.sso.secretFileForAuthelia` options
must have the same content. The former is a file that must be owned by the `nextcloud` user while
the latter must be owned by the `authelia` user. I want to avoid needing to define the same secret
twice with a future secrets SHB block.

### Tweak PHPFpm Config {#services-nextcloud-server-usage-phpfpm}

```nix
shb.nextcloud.phpFpmPoolSettings = {
  "pm" = "dynamic";
  "pm.max_children" = 800;
  "pm.start_servers" = 300;
  "pm.min_spare_servers" = 300;
  "pm.max_spare_servers" = 500;
  "pm.max_spawn_rate" = 50;
  "pm.max_requests" = 50;
  "pm.process_idle_timeout" = "20s";
};
```

### Tweak PostgreSQL Settings {#services-nextcloud-server-usage-postgres}

These settings will impact all databases.

```nix
shb.nextcloud.postgresSettings = {
  max_connections = "100";
  shared_buffers = "512MB";
  effective_cache_size = "1536MB";
  maintenance_work_mem = "128MB";
  checkpoint_completion_target = "0.9";
  wal_buffers = "16MB";
  default_statistics_target = "100";
  random_page_cost = "1.1";
  effective_io_concurrency = "200";
  work_mem = "2621kB";
  huge_pages = "off";
  min_wal_size = "1GB";
  max_wal_size = "4GB";
};
```

### Backup {#services-nextcloud-server-usage-backup}

Backing up Nextcloud using the [Restic block](blocks-restic.html) is done like so:

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

Optionally creates a local mount point with:

```nix
externalStorage = {
  userLocalMount.rootDirectory = "/srv/nextcloud/$user";
  userLocalMount.mountName = "home";
};
```

You can even make the external storage be at the root with:

```nix
externalStorage.userLocalMount.mountName = "/";
```

Recommended use of this app is to have the Nextcloud's `dataDir` on a SSD and the
`userLocalRooDirectory` on a HDD. Indeed, a SSD is much quicker than a spinning hard drive, which is
well suited for randomly accessing small files like thumbnails. On the other side, a spinning hard
drive can store more data which is well suited for storing user data.

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

Enable the [monitoring block](./blocks-monitoring.html). The metrics will automatically appear in
the corresponding dashboards.

### Enable Tracing {#services-nextcloud-server-server-usage-tracing}

You can enable tracing with:

```nix
shb.nextcloud.debug = true;
```

Traces will be located at `/var/log/xdebug`.

See [my blog
post](http://blog.tiserbox.com/posts/2023-08-12-what%27s-up-with-nextcloud-webdav-slowness.html) for
how to look at the traces.

### Appdata Location {#services-nextcloud-server-server-usage-appdata}

The appdata folder is a special folder located under the `shb.nextcloud.dataDir` directory. It is
named `appdata_<instanceid>` with the Nextcloud's instance ID as a suffix. You can find your current
instance ID with `nextcloud-occ config:system:get instanceid`. In there, you will find one subfolder
for every installed app that needs to store files.

For performance reasons, it is recommended to store this folder on a fast drive that is optimized
for randomized read and write access. The best would be either an SSD or an NVMe drive.

If you intentionally put Nextcloud's `shb.nextcloud.dataDir` folder on a HDD with spinning disks,
for example because they offer more disk space, then the appdata folder is also located on spinning
drives. You are thus faced with a conundrum. The only way to solve this is to bind mount a folder
from an SSD over the appdata folder. SHB does not provide (yet?) a declarative way to setup this but
this command should be enough:

```bash
mount /dev/sdd /srv/sdd
mkdir -p /srv/sdd/appdata_nextcloud
mount --bind /srv/sdd/appdata_nextcloud /var/lib/nextcloud/data/appdata_ocxvky2f5ix7
```

Note that you can re-generate a new appdata folder by issuing the command `occ config:system:delete
instanceid`.

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
