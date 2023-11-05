# Self Host Blocks

<!--toc:start-->
- [Self Host Blocks](#self-host-blocks)
  - [Supported Features](#supported-features)
<!--toc:end-->

*Building blocks for self-hosting with battery included.*

SHB's (Self Host Blocks) goal is to provide a lower entry-bar for self-hosting. I intend to achieve
this by providing opinionated building blocks fitting together to self-host a wide range of
services. Also, the design will be extendable to allow users to add services not provided by SHB.

## Supported Features

- [X] Authelia as SSO provider.
  - [X] Export metrics to Prometheus.
- [X] LDAP server through lldap, it provides a nice Web UI.
  - [X] Administrative UI only accessible from local network.
- [X] Backup with Restic or BorgBackup
  - [ ] UI for backups.
  - [ ] Export metrics to Prometheus.
- [X] Monitoring through Prometheus and Grafana.
  - [X] Export systemd services status.
- [X] Reverse Proxy with Nginx.
  - [ ] Export metrics to Prometheus.
  - [ ] Log slow requests.
  - [X] SSL support.
  - [X] Backup support.
- [X] Nextcloud
  - [ ] Export metrics to Prometheus.
  - [ ] Export traces to Prometheus.
  - [X] LDAP auth, unfortunately we need to configure this manually.
  - [ ] SSO auth.
  - [X] Backup support.
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
- [X] Mount webdav folders
- [ ] Gitea to deploy
- [ ] Scrutiny to monitor hard drives health
  - [ ] Export metrics to Prometheus.
- [ ] Misc
  - [ ] Alert if backups were not made on time.

## Repo layout

The top-level `flake.nix` just outputs a nixos module that gathers all other modules from `modules/`.

Some provided modules are low-level and some are high-level that re-use those low-level ones. For
example, the nextcloud module re-uses the backup and nginx ones.

## How to Use

You want to use this repo as a flake input to your own repo. The `inputs` field of your `flake.nix`
file in your repo should look like so:

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

Also, if you ever want to hack on `selfhostblocks` yourself, you can clone it and then update the
`selfhostblocks` url to point to the absolute path of where you cloned it:

```nix
selfhostblocks.url = "/home/me/projects/selfhostblocks";
```

Now, how you actually deploy using selfhostblocks depends on what system you chose. If you use colmena, this is what your `outputs` field should look like:

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

### Deploy a Nextcloud Instance

Now, what goes inside this `./machines/myserver.nix` file? Let's say you want to deploy Nextcloud,
you would use the [`nextcloud.nix`](./modules/nextcloud.nix) module from this repo as reference and
have something like the following.

First, some common configuration:

```nix
imports = [
  selfhostblocks.nixosModules.x86_64-linux.default
  sops-nix.nixosModules.default
]

shb.ssl = {
  enable = true;
  domain = "example.com";
  adminEmail = "me@example.com";
  sopsFile = ./secrets/linode.yaml;
  dnsProvider = "linode";
};
```

This will import the NixOS module provided by this repository as well as the `sops-nix` module,
needed to store secrets. It then enables SSL support.

Then, the configuration for Nextcloud which sets up:
- the nginx reverse proxy to listen on requests for the `nextcloud.example.com` domain,
- backup of the config folder and the data folder,
- an onlyoffice instance listening at `oo.example.com` that only listens on the local
  nextwork; you still need to setup the onlyoffice plugin in Nextcloud,
- and all the required databases and secrets.

```nix
shb.nextcloud = {
  enable = true;
  domain = "example.com";
  subdomain = "nextcloud";
  sopsFile = ./secrets/nextcloud.yaml;
  localNetworkIPRange = "192.168.1.0/24";
  debug = false;
};

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

shb.backup.instances.nextcloud = {
  backend = "restic";

  keySopsFile = ./secrets/backup.yaml;

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

  environmentFile = true;  # Needed for s3
};
```

### Deploy an hledger Instance with LDAP and SSO support

First, use the same common configuration as above. Then add the SSO and LDAP providers:

```nix
shb.ldap = {
  enable = true;
  domain = "example.com";
  subdomain = "ldap";
  dcdomain = "dc=example,dc=com";
  sopsFile = ./secrets/ldap.yaml;
  localNetworkIPRange = "192.168.1.0/24";
};
shb.backup.instances.lldap = # Same as for the Nextcloud one above

shb.authelia = {
  enable = true;
  domain = "example.com";
  subdomain = "authelia";
  sopsFile = ./secrets/authelia.yaml;

  ldapEndpoint = "ldap://127.0.0.1:3890";
  dcdomain = config.shb.ldap.dcdomain;

  smtpHost = "smtp.mailgun.org";
  smtpPort = 587;
  smtpUsername = "postmaster@mg.example.com";
};
```

Finally, the hledger specific part which sets up:
- the nginx reverse proxy to listen on requests for the `hledger.example.com` domain,
- backup of everything,
- only allow users of the hledger_user to be able to login,
- all the required databases and secrets

```nix
shb.hledger = {
  enable = true;
  subdomain = "hledger";
  domain = "example.com";
  oidcEndpoint = "https://authelia.example.com";
  localNetworkIPRange = "192.168.1.0/24";
};
shb.backup.instances.hledger = # Same as the examples above
```

### Deploy a Jellyfin instance with LDAP and SSO support

First, use the same common configuration as for the Nextcloud example and the SSO and LDAP
configuration than for the hledger example. Then, the jellyfin specific part which sets up :

- the nginx reverse proxy to listen on requests for the `jellyfin.example.com` domain,
- backup of everything,
- only allow users of the `jellyfin_user` or `jellyfin_admin` ldap group to be able to login,
- all the required databases and secrets

```nix
shb.jellyfin = {
  enable = true;
  domain = "example.com";
  subdomain = "jellyfin";

  sopsFile = ./secrets/jellyfin.yaml;
  ldapHost = "127.0.0.1";
  ldapPort = 3890;
  dcdomain = config.shb.ldap.dcdomain;
  oidcEndpoint = "https://authelia.example.com";
  oidcClientID = "jellyfin";
  oidcAdminUserGroup = "jellyfin_admin";
  oidcUserGroup = "jellyfin_user";
};
shb.backup.instances.jellyfin = # Same as the examples above
```

## Tips

### Deploy using colmena

```bash
$ nix run nixpkgs#colmena -- apply
```

### Diff changes

```bash $ nix run nixpkgs#colmena -- build ... Built
"/nix/store/yyw9rgn8v5jrn4657vwpg01ydq0hazgx-nixos-system-baryum-23.11pre-git"

# Make some changes

$ nix run nixpkgs#colmena -- build
...
Built "/nix/store/16n1klx5cxkjpqhrdf0k12npx3vn5042-nixos-system-baryum-23.11pre-git"

$ nix run nixpkgs#nix-diff -- \
  /nix/store/yyw9rgn8v5jrn4657vwpg01ydq0hazgx-nixos-system-baryum-23.11pre-git \
  /nix/store/16n1klx5cxkjpqhrdf0k12npx3vn5042-nixos-system-baryum-23.11pre-git \
  --color always | less
```

Also, in lieu of `nix-diff`, a nice summary of version changes can be produced with:

```bash
nix run nixpkgs#nvd -- diff \
  /nix/store/yyw9rgn8v5jrn4657vwpg01ydq0hazgx-nixos-system-baryum-23.11pre-git \
  /nix/store/16n1klx5cxkjpqhrdf0k12npx3vn5042-nixos-system-baryum-23.11pre-git \
```

## TODOs

- [ ] Add examples that sets up instance in a VM.
- [ ] Do not depend on sops.
- [ ] Add more options to avoid hardcoding stuff.
- [ ] Make sure nginx gets reloaded when SSL certs gets updated.
