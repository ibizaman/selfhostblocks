# Self Host Blocks

*Building blocks for self-hosting with battery included.*

SHB's (Self Host Blocks) goal is to provide a lower entry-bar for self-hosting. SHB provides
opinionated [building blocks](#building-blocks) fitting together to self-host any service you'd
want. Some [common services](#provided-services) are provided out of the box.

To achieve this, SHB is using the full power of NixOS modules. Indeed, each building block and each
service is a NixOS module and uses the modules defined in
[Nixpkgs](https://github.com/NixOS/nixpkgs/).

Each building block defines a part of what a self-hosted app should provide. For example, HTTPS
access through a subdomain or Single Sign-On. The goal of SHB is to make sure those blocks all fit
together, whatever the actual implementation you choose. For example, the subdomain access could be
done using Caddy or Nginx. This is achieved by providing an explicit contract for each block and validating that contract using NixOS VM integration tests.

One important goal of SHB is to be the smallest amount of code above what is available in
[nixpkgs](https://github.com/NixOS/nixpkgs). It should be the minimum necessary to make packages
available there conform with the contracts. This way, there are less chance of breakage when nixpkgs
gets updated.

SHB provides some out of the box implementation of those blocks:
- Access through a subdomain ([Nginx](https://www.nginx.com/)).
- HTTPS access ([Nginx](https://www.nginx.com/) + [Letsencrypt](https://letsencrypt.org/)).
- Backup ([Borgmatic](https://torsion.org/borgmatic/) and/or [Restic](https://restic.net/)).
- Single sign-on ([Authelia](https://www.authelia.com/)).
- LDAP user management ([LLDAP](https://github.com/lldap/lldap)).
- Metrics, logs and alerting ([Grafana](https://grafana.com/) + [Prometheus](https://prometheus.io/) + [Loki](https://grafana.com/oss/loki/) + [Promtail](https://grafana.com/docs/loki/latest/send-data/promtail/) + [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)).
- Database setup (Only [Postgresql](https://www.postgresql.org/) so far).
- VPN tunnels with optional proxys ([OpenVPN](https://openvpn.net/) with [Tinyproxy](http://tinyproxy.github.io/)).

SHB provides also services that integrate with those blocks out of the box. Progress is detailed in the [Supported Features](#supported-features) section.

> **Caution:** You should know that although I am using everything in this repo for my personal
> production server, this is really just a one person effort for now and there are most certainly
> bugs that I didn't discover yet.

## TOC

<!--toc:start-->
- [Supported Features](#supported-features)
- [Usage](#usage)
- [Manual](#manual)
- [Provided Services](#provided-services)
- [Demos](#demos)
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

## Usage

The following snippet shows how to deploy to a machine (here `machine2`) using
[Colmena](https://colmena.cli.rs):

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    selfhostblocks.url = "github:ibizaman/selfhostblocks";
  };

  outputs = { self, selfhostblocks }: {
    colmena = {
      meta =
        let
          system = "x86_64-linux";
        in {
          nixpkgs = import nixpkgs { inherit system; };
          nodeNixpkgs = {
            machine2 = import selfhostblocks.inputs.nixpkgs { inherit system; };
          };
        };

      machine1 = ...;

      machine2 = { selfhostblocks, ... }: {
        imports = [
          selfhostblocks.nixosModules.${system}.default
        ];
      };
    };
  };
}
```

More information is provided in the manual (see below).

## Manual

The (WIP) complete manual can be found at [shb.skarabox.com](https://shb.skarabox.com/). The information in
this README will be slowly moved over there.

- [Building Blocks](https://shb.skarabox.com/blocks.html)
- [Services Provided](https://shb.skarabox.com/services.html)

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

See the [`ldap.nix`](./modules/ldap.nix) and [`authelia.nix`](./modules/authelia.nix) modules for more info.

### Backup folders

See the [manual](https://shb.skarabox.com/blocks-backup.html).

### Deploy the full Grafana, Prometheus and Loki suite

See the [manual](https://shb.skarabox.com/blocks-monitoring.html).

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
- [Nextcloud Server](https://shb.skarabox.com/services-nextcloud.html) for private documents, contacts, calendar, etc https://nextcloud.com.
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

### Upload test results to CI

Github actions do now have hardware acceleration, so running them there is not slow anymore. If
needed, the tests results can still be pushed to cachix so they can be reused in CI.

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
