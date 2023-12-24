# Nextcloud Server Service {#services-nextcloud-server}

Defined in [`/modules/services/nextcloud-server.nix`](@REPO@/modules/services/nextcloud-server.nix).

This NixOS module is a service that sets up a [Nextcloud Server](https://nextcloud.com/).

## Features {#services-nextcloud-server-features}

- Integration Tests (TODO: need to add some)
- [Demo](./demo-nextcloud-server.html)
- Access through subdomain using reverse proxy.
- Access through HTTPS using reverse proxy.
- Automatic setup of PostgreSQL database.
- Backup of the [`shb.nextcloud.dataDir`][1] through the [backup block](./blocks-backup.html).
- Monitoring of reverse proxy, PHP-FPM, and database backups through the [monitoring
  block](./blocks-monitoring.html).
- Automatic setup of Only Office service if the `shb.nextcloud.onlyoffice` option is given. The
  integration still needs to be set up in the UI manually though.
- Access to advanced options not exposed here thanks to how NixOS modules work.

[1]: ./services-nextcloud.html#services-nextcloud-server-options-shb.nextcloud.dataDir

## Usage {#services-nextcloud-server-usage}

### Minimal {#services-nextcloud-server-usage-minimal}

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

### Enable OnlyOffice Server {#services-nextcloud-server-usage-onlyoffice}

The following snippets sets up an onlyoffice instance listening at `onlyoffice.example.com` that
only listens on the local nextwork.

```nix
shb.nextcloud.onlyoffice = {
  subdomain = "onlyoffice";
  localNextworkIPRange = "192.168.1.1/24";
};
```

You still need to install the OnlyOffice integration in Nextcloud UI. Setting up the integration
declaratively is WIP.

Also, you will need to explicitly allow the package `corefonts`:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
  "corefonts"
];
```

### Enable Monitoring {#services-nextcloud-server-server-usage-monitoring}

Enable the [monitoring block](./blocks-monitoring.html).

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

Head over to the [Nextcloud demo](demo-nextcloud.html) for a demo that installs Nextcloud on a VM
with minimal manual steps.

## Maintenance {#services-nextcloud-server-maintenance}

On the command line, the `occ` tool is called `nextcloud-occ`.

## Options Reference {#services-nextcloud-server-options}

```{=include=} options
id-prefix: services-nextcloud-server-options-
list-id: selfhostblocks-service-nextcloud-options
source: @OPTIONS_JSON@
```
