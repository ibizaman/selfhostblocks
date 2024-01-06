# Nextcloud Server Service {#services-nextcloud-server}

Defined in [`/modules/services/nextcloud-server.nix`](@REPO@/modules/services/nextcloud-server.nix).

This NixOS module is a service that sets up a [Nextcloud Server](https://nextcloud.com/).

## Features {#services-nextcloud-server-features}

- Declarative [Apps](#services-nextcloud-server-options-shb.nextcloud.apps) Configuration - no need
  to configure those with the UI.
  - [LDAP](#services-nextcloud-server-usage-ldap) app: enables app and sets up integration with an existing LDAP server.
  - [Preview Generator](#services-nextcloud-server-usage-previewgenerator) app: enables app and sets
    up required cron job.
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
- [Integration Tests](@REPO@/test/vm/nextcloud.nix)
  - Tests system cron job is setup correctly.
  - Tests initial admin user and password are setup correctly.
  - Tests admin user can create and retrieve a file through WebDAV.
- Access to advanced options not exposed here thanks to how NixOS modules work.

[1]: ./services-nextcloud.html#services-nextcloud-server-options-shb.nextcloud.dataDir

## Usage {#services-nextcloud-server-usage}

### Basic Configuration {#services-nextcloud-server-usage-basic}

This section corresponds to the `basic` target host defined in the [flake.nix](./flake.nix) file.

This will set up a Nextcloud service that runs on the NixOS target machine, reachable at
`http://nextcloud.example.com`. If the `shb.ssl` block is [enabled](block-ssl.html#usage), the
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

The secret should not be stored in the nix store. If you're using
[sops-nix](https://github.com/Mic92/sops-nix) and assuming your secrets file is located at
`./secrets.yaml`, you can set the `adminPassFile` option with:

```nix
shb.nextcloud.adminPassFile = config.sops.secrets."nextcloud/adminpass".path;

sops.secrets."nextcloud/adminpass" = {
  sopsFile = ./secrets.yaml;
  mode = "0400";
  owner = "nextcloud";
  group = "nextcloud";
  restartUnits = [ "phpfpm-nextcloud.service" ];
};
```

### With LDAP Support {#services-nextcloud-server-usage-ldap}

This section corresponds to the `ldap` target host defined in the [flake.nix](./flake.nix) file. The same information from the [basic](#services-nextcloud-server-usage-basic) section applies, so please read that first.

This target host uses the LDAP block provided by Self Host Blocks to setup a
[LLDAP](https://github.com/lldap/lldap) service.

```nix
shb.ldap = {
  enable = true;
  domain = "example.com";
  subdomain = "ldap";
  ldapPort = 3890;
  webUIListenPort = 17170;
  dcdomain = "dc=example,dc=com";
  ldapUserPasswordFile = config.sops.secrets."lldap/user_password".path;
  jwtSecretFile = config.sops.secrets."lldap/jwt_secret".path;
};

sops.secrets."lldap/user_password" = {
  sopsFile = ./secrets.yaml;
  mode = "0440";
  owner = "lldap";
  group = "lldap";
  restartUnits = [ "lldap.service" ];
};

sops.secrets."lldap/jwt_secret" = {
  sopsFile = ./secrets.yaml;
  mode = "0440";
  owner = "lldap";
  group = "lldap";
  restartUnits = [ "lldap.service" ];
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
  adminPasswordFile = config.sops.secrets."nextcloud/ldap_admin_password".path;
  userGroup = "nextcloud_user";
};
```

It's nice to be able to reference a options that were defined in the ldap block.

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

### Backup the Nextcloud data {#services-nextcloud-server-usage-backup}

TODO

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

## Demo {#services-nextcloud-server-demo}

Head over to the [Nextcloud demo](demo-nextcloud-server.html) for a demo that installs Nextcloud with or
without LDAP integration on a VM with minimal manual steps.

## Maintenance {#services-nextcloud-server-maintenance}

On the command line, the `occ` tool is called `nextcloud-occ`.

## Options Reference {#services-nextcloud-server-options}

```{=include=} options
id-prefix: services-nextcloud-server-options-
list-id: selfhostblocks-service-nextcloud-options
source: @OPTIONS_JSON@
```
