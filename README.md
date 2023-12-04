# Self Host Blocks

*Building blocks for self-hosting with battery included.*

SHB's (Self Host Blocks) goal is to provide a lower entry-bar for self-hosting. I intend to achieve
this by providing opinionated [building blocks](#building-blocks) fitting together to self-host any service
you'd want. Some [common services](#provided-services) are provided out of the box.

The building blocks allow you to easily setup:
- Access through a subdomain ([Nginx](https://www.nginx.com/)).
- HTTPS access ([Nginx](https://www.nginx.com/) + [Letsencrypt](https://letsencrypt.org/)).
- Backup ([Borgmatic](https://torsion.org/borgmatic/) and/or [Restic](https://restic.net/)).
- Single sign-on ([Authelia](https://www.authelia.com/)).
- LDAP user management ([LLDAP](https://github.com/lldap/lldap)).
- Metrics, logs and alerting ([Grafana](https://grafana.com/) + [Prometheus](https://prometheus.io/) + [Loki](https://grafana.com/oss/loki/) + [Promtail](https://grafana.com/docs/loki/latest/send-data/promtail/) + [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)).
- Database setup (Only [Postgresql](https://www.postgresql.org/) so far).
- VPN tunnels with optional proxys ([OpenVPN](https://openvpn.net/) with [Tinyproxy](http://tinyproxy.github.io/)).

The provided services will have all those integrated. Progress is detailed in the [Supported Features](#supported-features) section.

You should know that although I am using everything in this repo for my personal production server, this is
really just a one person effort for now and there are most certainly bugs that I didn't discover yet.

## TOC

<!--toc:start-->
- [Supported Features](#supported-features)
- [Building Blocks](#building-blocks)
- [Provided Services](#provided-services)
- [Demos](#demos)
- [Import selfhostblocks](#import-selfhostblocks)
- [Community](#community)
- [Tips](#tips)
- [TODOs](#todos)
- [Links that helped](#links-that-helped)
- [License](#license)
<!--toc:end-->

## Supported Features

Currently supported services and features are:

- [X] Authelia as SSO provider.
  - [X] Export metrics to Prometheus.
- [X] LDAP server through lldap, it provides a nice Web UI.
  - [X] Administrative UI only accessible from local network.
- [X] Backup with Restic or BorgBackup
  - [ ] UI for backups.
  - [ ] Export metrics to Prometheus.
  - [ ] Alert when backups fail or are not done on time.
- [X] Reverse Proxy with Nginx.
  - [x] Export metrics to Prometheus.
  - [x] Log slow requests.
  - [X] SSL support.
  - [X] Backup support.
- [X] Monitoring through Prometheus and Grafana.
  - [X] Export systemd services status.
  - [ ] Provide out of the box dashboards and alerts for common tasks.
  - [ ] LDAP auth.
  - [ ] SSO auth.
- [X] Vaultwarden
  - [X] UI only accessible for `vaultwarden_user` LDAP group.
  - [X] `/admin` only accessible for `vaultwarden_admin` LDAP group.
  - [WIP] True SSO support, see [dani-garcia/vaultwarden/issues/246](https://github.com/dani-garcia/vaultwarden/issues/246). For now, Authelia protects access to the UI but you need to login afterwards to Vaultwarden. So there are two login required.
- [X] Nextcloud
  - [X] LDAP auth, unfortunately we need to configure this manually.
    - [ ] Declarative setup.
  - [ ] SSO auth.
    - [ ] Declarative setup.
  - [X] Backup support.
  - [X] Optional tracing debug.
  - [ ] Export traces to Prometheus.
  - [ ] Export metrics to Prometheus.
- [X] Home Assistant.
  - [ ] Export metrics to Prometheus.
  - [X] LDAP auth through `homeassistant_user` LDAP group.
  - [ ] SSO auth.
  - [X] Backup support.
- [X] Jellyfin
  - [ ] Export metrics to Prometheus.
  - [X] LDAP auth through `jellyfin_user` and `jellyfin_admin` LDAP groups.
  - [X] SSO auth.
  - [X] Backup support.
- [X] Hledger
  - [ ] Export metrics to Prometheus.
  - [X] LDAP auth through `hledger_user` LDAP group.
  - [X] SSO auth.
  - [ ] Backup support.
- [X] Database Postgres
  - [ ] Slow log monitoring.
  - [ ] Export metrics to Prometheus.
- [X] VPN tunnel
- [X] Arr suite
  - [X] SSO auth (one account for all users).
  - [X] VPN support.
- [X] Mount webdav folders
- [ ] Gitea to deploy
- [ ] Scrutiny to monitor hard drives health
  - [ ] Export metrics to Prometheus.
- [x] QoL
  - [x] Unit tests for modules.
  - [x] Running in CI.
  - [ ] Integration tests with real nodes.
  - [ ] Self published documentation for options.
  - [ ] Examples for all building blocks.

## Building Blocks

The building blocks are the foundation selfhostblocks intend to provide to allow you to self host
easily and with best practices any service of your choosing. Some services are already provided out of
the box but you might not want to use those if for example you want to integrate with existing
services or slowly transition to NixOS.

Following somewhat the Unix principle, each block has one goal and does it correctly. They also are
independent of each other, you can use only one or combine them to your liking.

Although these blocks provide options that encourage best practices, these are just NixOS modules that
configure other modules provided by nixpkgs. Would you need to make tweaks, you can always
access those underlying modules directly, like for any NixOS module.

- [`authelia.nix`](./modules/blocks/authelia.nix) for Single Sign On.
- [`backup.nix`](./modules/blocks/backup.nix).
- [`ldap.nix`](./modules/blocks/ldap.nix) for user management.
- [`monitoring.nix`](./modules/blocks/monitoring.nix) for dashboards, logs and alerts.
- [`nginx.nix`](./modules/blocks/nginx.nix) for reverse proxy with SSL termination.
- [`postgresql.nix`](./modules/blocks/postgresql.nix) for database setup.
- [`ssl.nix`](./modules/blocks/ssl.nix) for maintaining SSL certificates provided by letsencrypt.
- [`tinyproxy.nix`](./modules/blocks/tinyproxy.nix) to forward traffic to a VPN tunnel.
- [`vpn.nix`](./modules/blocks/vpn.nix) to setup a VPN tunnel.

The best way for now to understand how to use those modules is to read the code linked above and see
how they are used in the [provided services](#provided-services) and in the [demos](#demos). Also, here are a
few examples taken from my personal usage of selfhostblocks.

### Add SSL configuration

This is pretty much a prerequisite for all services.

```nix
shb.ssl = {
  enable = true;
  domain = "example.com";
  adminEmail = "me@example.com";
  sopsFile = ./secrets/linode.yaml;
  dnsProvider = "linode";
};
```

The configuration above assumes you own the `example.com` domain and the DNS is managed by Linode.

The `sops` file must be in the following format:

```yaml
acme: |-
    LINODE_HTTP_TIMEOUT=10
    LINODE_POLLING_INTERVAL=10
    LINODE_PROPAGATION_TIMEOUT=240
    LINODE_TOKEN=XYZ...
```

For now, linode is the only supported DNS provider as it's the one I'm using. I intend to make this
module more generic so you can easily use another provider not supported by `selfhostblocks`. You
can skip setting the `shb.ssl` options and roll your own. Feel free to look at the
[`ssl.nix`](./modules/ssl.nix) for inspiration.

### Add LDAP and Authelia services

These too are prerequisites for other services. Not all services support LDAP and SSO just yet, but
I'm working on that.

```nix
shb.ldap = {
  enable = true;
  domain = "example.com";
  subdomain = "ldap";
  ldapPort = 3890;
  httpPort = 17170;
  dcdomain = "dc=example,dc=com";
  sopsFile = ./secrets/ldap.yaml;
  localNetworkIPRange = "192.168.1.0/24";
};

shb.authelia = {
  enable = true;
  domain = "example.com";
  subdomain = "authelia";

  ldapEndpoint = "ldap://127.0.0.1:${builtins.toString config.shb.ldap.ldapPort}";
  dcdomain = config.shb.ldap.dcdomain;

  smtpHost = "smtp.mailgun.org";
  smtpPort = 587;
  smtpUsername = "postmaster@mg.example.com";

  secrets = {
    jwtSecretFile = config.sops.secrets."authelia/jwt_secret".path;
    ldapAdminPasswordFile = config.sops.secrets."authelia/ldap_admin_password".path;
    sessionSecretFile = config.sops.secrets."authelia/session_secret".path;
    notifierSMTPPasswordFile = config.sops.secrets."authelia/smtp_password".path;
    storageEncryptionKeyFile = config.sops.secrets."authelia/storage_encryption_key".path;
    identityProvidersOIDCHMACSecretFile = config.sops.secrets."authelia/hmac_secret".path;
    identityProvidersOIDCIssuerPrivateKeyFile = config.sops.secrets."authelia/private_key".path;
  };
};
sops.secrets."authelia/jwt_secret" = {
  sopsFile = ./secrets/authelia.yaml;
  mode = "0400";
  owner = config.shb.authelia.autheliaUser;
  restartUnits = [ "authelia.service" ];
};
sops.secrets."authelia/ldap_admin_password" = {
  sopsFile = ./secrets/authelia.yaml;
  mode = "0400";
  owner = config.shb.authelia.autheliaUser;
  restartUnits = [ "authelia.service" ];
};
sops.secrets."authelia/session_secret" = {
  sopsFile = ./secrets/authelia.yaml;
  mode = "0400";
  owner = config.shb.authelia.autheliaUser;
  restartUnits = [ "authelia.service" ];
};
sops.secrets."authelia/smtp_password" = {
  sopsFile = ./secrets/authelia.yaml;
  mode = "0400";
  owner = config.shb.authelia.autheliaUser;
  restartUnits = [ "authelia.service" ];
};
sops.secrets."authelia/storage_encryption_key" = {
  sopsFile = ./secrets/authelia.yaml;
  mode = "0400";
  owner = config.shb.authelia.autheliaUser;
  restartUnits = [ "authelia.service" ];
};
sops.secrets."authelia/hmac_secret" = {
  sopsFile = ./secrets/authelia.yaml;
  mode = "0400";
  owner = config.shb.authelia.autheliaUser;
  restartUnits = [ "authelia.service" ];
};
sops.secrets."authelia/private_key" = {
  sopsFile = ./secrets/authelia.yaml;
  mode = "0400";
  owner = config.shb.authelia.autheliaUser;
  restartUnits = [ "authelia.service" ];
};
```

This sets up [lldap](https://github.com/lldap/lldap) under `https://ldap.example.com` and [authelia](https://www.authelia.com/) under `https://authelia.example.com`.

The `lldap` sops file must be in the following format:

```yaml
lldap:
    user_password: XXX...
    jwt_secret: YYY...
```

You can format the `Authelia` sops file as you wish since you can give the path to every secret independently. For completeness, here's the format expected by the snippet above:

```yaml
authelia:
    ldap_admin_password: AAA...
    smtp_password: BBB...
    jwt_secret: CCC...
    storage_encryption_key: DDD...
    session_secret: EEE...
    storage_encryption_key: FFF...
    hmac_secret: GGG...
    private_key: |
        -----BEGIN PRIVATE KEY-----
        MII...MDQ=
        -----END PRIVATE KEY-----
```

Add backup to LDAP:

```nix
shb.backup.instances.lldap = {
  # Can also use "borgmatic".
  backend = "restic";

  keySopsFile = ./secrets/backup.yaml;

  # Backs up to 2 repositories.
  repositories = [
    "/srv/backup/restic/nextcloud"
    "s3:s3.us-west-000.backblazeb2.com/myserver-backup/nextcloud"
  ];

  retention = {
    keep_within = "1d";
    keep_hourly = 24;
    keep_daily = 7;
    keep_weekly = 4;
    keep_monthly = 6;
  };

  consistency = {
    repository = "2 weeks";
    archives = "1 month";
  };

  environmentFile = true;  # Needed for the s3 repository
}
```

This will backup the ldap users and groups to two different repositories. It assumes you have a
backblaze account.

The backup `sops` file format is:

```yaml
restic:
    passphrases:
        lldap: XYZ...
    environmentfiles:
        lldap: |-
            AWS_ACCESS_KEY_ID=XXX...
            AWS_SECRET_ACCESS_KEY=YYY...
```

The AWS keys are those provided by Backblaze.

See the [`ldap.nix`](./modules/ldap.nix) and [`authelia.nix`](./modules/authelia.nix) modules for more info.

### Deploy the full Grafana, Prometheus and Loki suite

See [docs/blocks/monitoring.md](docs/blocks/monitoring.md).

### Set up network tunnel with VPN and Proxy

```nix
shb.vpn.nordvpnus = {
  enable = true;
  # Only "nordvpn" supported for now.
  provider = "nordvpn";
  dev = "tun1";
  # Must be unique per VPN instance.
  routingNumber = 10;
  # Change to the one you want to connect to
  remoteServerIP = "1.2.3.4";
  sopsFile = ./secrets/vpn.yaml;
  proxyPort = 12000;
};
```

This sets up a tunnel interface `tun1` that connects to the VPN provider, here NordVPN. Also, if the
`proxyPort` option is not null, this will spin up a `tinyproxy` instance that listens on the given
port and redirects all traffic through that VPN.

```bash
$ curl 'https://api.ipify.org?format=json'
{"ip":"107.21.107.115"}

$ curl --interface tun1 'https://api.ipify.org?format=json'
{"ip":"46.12.123.113"}

$ curl --proxy 127.0.0.1:12000 'https://api.ipify.org?format=json'
{"ip":"46.12.123.113"}
```

## Provided Services

- [`arr.nix`](./modules/services/arr.nix) for finding media https://wiki.servarr.com/.
- [`deluge.nix`](./modules/services/deluge.nix) for downloading linux isos https://deluge-torrent.org/.
- [`hledger.nix`](./modules/services/hledger.nix) for managing finances https://hledger.org/.
- [`home-assistant.nix`](./modules/services/home-assistant.nix) for private IoT https://www.home-assistant.io/.
- [`jellyfin.nix`](./modules/services/jellyfin.nix) for watching media https://jellyfin.org/.
- [`nextcloud-server.nix`](./modules/services/nextcloud-server.nix) for private documents, contacts, calendar, etc https://nextcloud.com.
- [`vaultwarden.nix`](./modules/services/vaultwarden.nix) for passwords https://github.com/dani-garcia/vaultwarden.

The services above are those I am using myself. I intend to add more.

The best way for now to understand how to use those modules is to read the code linked above and see
how they are used in the demos. Also, here are a
few examples taken from my personal usage of selfhostblocks.

### Common Options

Some common options are provided for all services.

- `enable` (bool). Set to true to deploy and run the service.
- `subdomain` (string). Subdomain under which to serve the service.
- `domain` (string). Domain under which to server the service.

Some other common options are the following. I am not satisfied with how those are expressed so those will most certainly change.
- LDAP and OIDC options for SSO, authentication and authorization.
- Secrets.
- Backups.

Note that for backups, every service exposes what directory should be backed up, you must merely choose when those backups will take place and where they will be stored.

### Deploy a Nextcloud Instance

```nix
shb.nextcloud = {
  enable = true;
  domain = "example.com";
  subdomain = "nextcloud";
  sopsFile = ./secrets/nextcloud.yaml;
  localNetworkIPRange = "192.168.1.0/24";
  debug = false;
};

# Only needed if you want to override some default settings.
services.nextcloud = {
  datadir = "/srv/nextcloud";
  poolSettings = {
    "pm" = "dynamic";
    "pm.max_children" = 120;
    "pm.start_servers" = 12;
    "pm.min_spare_servers" = 6;
    "pm.max_spare_servers" = 18;
  };
};

# Backup the Nextcloud data.
shb.backup.instances.nextcloud = # Same as for the Authelia one above;

# For onlyoffice
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
  "corefonts"
];
```

The snippet above sets up:
- The nginx reverse proxy to listen on requests for the `nextcloud.example.com` domain.
- An onlyoffice instance listening at `oo.example.com` that only listens on the local
  nextwork; you still need to setup manually the onlyoffice plugin in Nextcloud.
- All the required databases and secrets.

The sops file format is:

```yaml
nextcloud:
    adminpass: XXX...
    onlyoffice:
        jwt_secret: YYY...
```

See the [`nextcloud-server.nix`](./modules/nextcloud-server.nix) module for more info.

You can enable tracing with:

```nix
shb.nextcloud.debug = true;
```

See [my blog post](http://blog.tiserbox.com/posts/2023-08-12-what%27s-up-with-nextcloud-webdav-slowness.html) for how to look at the traces.

### Enable verbose Nginx logging

In case you need more verbose logging to investigate an issue:

```nix
shb.nginx.accessLog = true;
shb.nginx.debugLog = true;
```

See the [`nginx.nix`](./modules/nginx.nix) module to see the effect of those options.

### Deploy an hledger Instance with LDAP and SSO support

```nix
shb.hledger = {
  enable = true;
  subdomain = "hledger";
  domain = "example.com";
  authEndpoint = "https://authelia.example.com";
  localNetworkIPRange = "192.168.1.0/24";
};
shb.backup.instances.hledger = # Same as the examples above
```

This will setup:
- The nginx reverse proxy to listen on requests for the `hledger.example.com` domain.
- Backup of everything.
- Only allow users of the `hledger_user` group to be able to login.
- All the required databases and secrets.

See [`hledger.nix`](./modules/hledger.nix) module for more details.

### Deploy a Jellyfin instance with LDAP and SSO support

```nix
shb.jellyfin = {
  enable = true;
  domain = "example.com";
  subdomain = "jellyfin";

  sopsFile = ./secrets/jellyfin.yaml;
  ldapHost = "127.0.0.1";
  ldapPort = 3890;
  dcdomain = config.shb.ldap.dcdomain;
  authEndpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";
  oidcClientID = "jellyfin";
  oidcUserGroup = "jellyfin_user";
  oidcAdminUserGroup = "jellyfin_admin";
};
shb.backup.instances.jellyfin = # Same as the examples above
```

This sets up, as usual:
- The nginx reverse proxy to listen on requests for the `jellyfin.example.com` domain.
- Backup of everything.
- Only allow users of the `jellyfin_user` or `jellyfin_admin` ldap group to be able to login.
- All the required databases and secrets.

The sops file format is:

```yaml
jellyfin:
    ldap_password: XXX...
    sso_secret: YYY...
```

Although the configuration of the [LDAP](https://github.com/jellyfin/jellyfin-plugin-ldapauth) and
[SSO](https://github.com/9p4/jellyfin-plugin-sso) plugins is done declaratively in the Jellyfin
`preStart` step, they still need to be installed manually at the moment.

See [`jellyfin.nix`](./modules/jellyfin.nix) module for more details.

### Deploy a Home Assistant instance with LDAP support

SSO support is WIP.

```nix
shb.home-assistant = {
  enable = true;
  subdomain = "ha";
  inherit domain;
  ldapEndpoint = "http://127.0.0.1:${builtins.toString config.shb.ldap.httpPort}";
  backupCfg = # Same as the examples above
  sopsFile = ./secrets/homeassistant.yaml;
};
services.home-assistant = {
  extraComponents = [
    "backup"
    "esphome"
    "jellyfin"
    "kodi"
    "wyoming"
    "zha"
  ];
};
services.wyoming.piper.servers = {
  "fr" = {
    enable = true;
    voice = "fr-siwis-medium";
    uri = "tcp://0.0.0.0:10200";
    speaker = 0;
  };
};
services.wyoming.faster-whisper.servers = {
  "tiny-fr" = {
    enable = true;
    model = "medium-int8";
    language = "fr";
    uri = "tcp://0.0.0.0:10300";
    device = "cpu";
  };
};
```

This sets up everything needed to have a Home Assistant instance available under `ha.example.com`.
It also shows how to have a `piper` and `whisper` server for respectively text to speech and speech
to text. The integrations must still be setup in the web UI.

The `sops` file must be in the following format:

```yaml
home-assistant: |
    country: "US"
    latitude_home: "0.01234567890123"
    longitude_home: "-0.01234567890123"
```

## Demos

Demos that start and deploy a service on a Virtual Machine on your computer are located under the
[demo](./demo/) folder. These show the onboarding experience you would get if you deployed
one of the services on your own server.

## Import selfhostblocks

Ready to start using selfhostblocks? Thank you for trusting selfhostblocks. Please raise any
question you have or hurdle you encounter by creating an issue.

The top-level `flake.nix` just outputs a nixos module that gathers all other modules from
the [`modules/`](./modules/) directory. Use this repo as a flake input to your own repo.
The `inputs` field of your `flake.nix` file in your repo should look like so:

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  sops-nix.url = "github:Mic92/sops-nix";

  selfhostblocks.url = "github:ibizaman/selfhostblocks";
  selfhostblocks.inputs.nixpkgs.follows = "nixpkgs";
  selfhostblocks.inputs.sops-nix.follows = "sops-nix";
};
```

`sops-nix` is used to setup passwords and secrets. Currently `selfhostblocks` has a strong
dependency on it but I'm working on removing that so you could use any secret provider.

The snippet above makes `selfhostblocks`' inputs follow yours. This is not maintainable though
because options that `selfhostblocks` rely on can change or disappear and you have no control on
that. Later, I intend to make `selfhostblocks` provide its own `nixpkgs` input and update it myself
through CI.

How you actually deploy using selfhostblocks depends on what system you choose. If you use
[colmena](https://colmena.cli.rs), this is what your `outputs` field could look like:

```nix
outputs = inputs@{ self, nixpkgs, ... }: {
  colmena = {
    meta = {
      nixpkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
      };
      specialArgs = inputs;
    };

    myserver = import ./machines/myserver.nix;
  };
}
```

Now, what goes inside this `./machines/myserver.nix` file? First, import `selfhostblocks` and
`sops-nix`:

```nix
imports = [
  selfhostblocks.nixosModules.x86_64-linux.default
  sops-nix.nixosModules.default
]
```

For the rest, see the above [building blocks](#building-blocks), [provided services](#provided-services) and [demos](#demos) sections.

## Community

All issues and PRs are welcome. For PRs, if they are substantial changes, please open an issue to discuss the details first.

Come hang out in the [Matrix channel](https://matrix.to/#/%23selfhostblocks%3Amatrix.org). :)

Along the way, I made quite a few changes to the ubderlying nixpkgs module I'm using. I intend to upstream to nixpkgs as much of those as makes sense.

## Tips

### Run tests

Run all tests:

```bash
$ nix build .#checks.${system}.all
# or
$ nix flake check
# or
$ nix run github:Mic92/nix-fast-build -- --skip-cached --flake ".#checks.$(nix eval --raw --impure --expr builtins.currentSystem)"
```

Run one group of tests:

```bash
$ nix build .#checks.${system}.modules
$ nix build .#checks.${system}.vm_postgresql_peerAuth
```

### Speed up CI

Github actions do not have hardware acceleration and tests could timeout when running there. The
easiest way to speed up CI is to push the test results to cachix.

After running the `nix-fast-build` command from the previous section, run:

```bash
$ find . -type l -name "result-vm_*" | xargs readlink | nix run nixpkgs#cachix -- push selfhostblocks
```

### Deploy using colmena

```bash
$ nix run nixpkgs#colmena -- apply
```

### Use a local version of selfhostblocks

This works with any flake input you have. Either, change the `.url` field directly in you `flake.nix`:

```nix
selfhostblocks.url = "/home/me/projects/selfhostblocks";
```

Or override on the command line:

```bash
$ nix flake lock --override-input selfhostblocks ../selfhostblocks
```

I usually combine the override snippet above with deploying:

```bash
$ nix flake lock --override-input selfhostblocks ../selfhostblocks && nix run nixpkgs#colmena -- apply
```

### Diff changes

First, you must know what to compare. You need to know the path to the nix store of what is already deployed and to what you will deploy.

#### What is deployed

To know what is deployed, either just stash the changes you made and run `build`:

```bash
$ nix run nixpkgs#colmena -- build
...
Built "/nix/store/yyw9rgn8v5jrn4657vwpg01ydq0hazgx-nixos-system-baryum-23.11pre-git"
```

Or ask the target machine:

```bash
$ nix run nixpkgs#colmena -- exec -v readlink -f /run/current-system
baryum | /nix/store/77n1hwhgmr9z0x3gs8z2g6cfx8gkr4nm-nixos-system-baryum-23.11pre-git
```

#### What will get deployed

Assuming you made some changes, then instead of deploying with `apply`, just `build`:

```bash
$ nix run nixpkgs#colmena -- build
...
Built "/nix/store/16n1klx5cxkjpqhrdf0k12npx3vn5042-nixos-system-baryum-23.11pre-git"
```

#### Get the full diff

With `nix-diff`:

```
$ nix run nixpkgs#nix-diff -- \
  /nix/store/yyw9rgn8v5jrn4657vwpg01ydq0hazgx-nixos-system-baryum-23.11pre-git \
  /nix/store/16n1klx5cxkjpqhrdf0k12npx3vn5042-nixos-system-baryum-23.11pre-git \
  --color always | less
```

#### Get version bumps

A nice summary of version changes can be produced with:

```bash
$ nix run nixpkgs#nvd -- diff \
  /nix/store/yyw9rgn8v5jrn4657vwpg01ydq0hazgx-nixos-system-baryum-23.11pre-git \
  /nix/store/16n1klx5cxkjpqhrdf0k12npx3vn5042-nixos-system-baryum-23.11pre-git \
```

### Generate random secret

```bash
$ nix run nixpkgs#openssl -- rand -hex 64
```

## TODOs

- [ ] Add examples that sets up services in a VM.
- [ ] Do not depend on sops.
- [ ] Add more options to avoid hardcoding stuff.
- [ ] Make sure nginx gets reloaded when SSL certs gets updated.
- [ ] Better backup story by taking optional LVM or ZFS snapshot before backing up.
- [ ] Many more tests.
- [ ] Tests deploying to real nodes.
- [ ] DNS must be more configurable.
- [ ] Fix tests on nix-darwin.

## Links that helped

While creating NixOS tests:

- https://www.haskellforall.com/2020/11/how-to-use-nixos-for-lightweight.html
- https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests

While creating an XML config generator for Radarr:

- https://stackoverflow.com/questions/4906977/how-can-i-access-environment-variables-in-python
- https://stackoverflow.com/questions/7771011/how-can-i-parse-read-and-use-json-in-python
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/writers/scripts.nix
- https://stackoverflow.com/questions/43837691/how-to-package-a-single-python-script-with-nix
- https://ryantm.github.io/nixpkgs/languages-frameworks/python/#python
- https://ryantm.github.io/nixpkgs/hooks/python/#setup-hook-python
- https://ryantm.github.io/nixpkgs/builders/trivial-builders/
- https://discourse.nixos.org/t/basic-flake-run-existing-python-bash-script/19886
- https://docs.python.org/3/tutorial/inputoutput.html
- https://pypi.org/project/json2xml/
- https://www.geeksforgeeks.org/serialize-python-dictionary-to-xml/
- https://nixos.org/manual/nix/stable/language/builtins.html#builtins-toXML
- https://github.com/NixOS/nixpkgs/blob/master/pkgs/pkgs-lib/formats.nix

## License

I'm following the [Nextcloud](https://github.com/nextcloud/server) license which is AGPLv3. See
[this article](https://www.fsf.org/bulletin/2021/fall/the-fundamentals-of-the-agplv3) from the FSF that explains what this license adds to the GPL
one.
