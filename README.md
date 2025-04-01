![GitHub Release](https://img.shields.io/github/v/release/ibizaman/selfhostblocks)
![GitHub commits since latest release (branch)](https://img.shields.io/github/commits-since/ibizaman/selfhostblocks/latest/main)
![GitHub commit activity (branch)](https://img.shields.io/github/commit-activity/w/ibizaman/selfhostblocks/main)
![GitHub Issues or Pull Requests](https://img.shields.io/github/issues-pr-raw/ibizaman/selfhostblocks)
![GitHub Issues or Pull Requests](https://img.shields.io/github/issues-pr-closed-raw/ibizaman/selfhostblocks?label=closed)
![GitHub Issues or Pull Requests](https://img.shields.io/github/issues-raw/ibizaman/selfhostblocks)
![GitHub Issues or Pull Requests](https://img.shields.io/github/issues-closed-raw/ibizaman/selfhostblocks?label=closed)

[![Documentation](https://github.com/ibizaman/selfhostblocks/actions/workflows/pages.yml/badge.svg)](https://github.com/ibizaman/selfhostblocks/actions/workflows/pages.yml)
[![Tests](https://github.com/ibizaman/selfhostblocks/actions/workflows/build.yaml/badge.svg)](https://github.com/ibizaman/selfhostblocks/actions/workflows/build.yaml)
[![Demo](https://github.com/ibizaman/selfhostblocks/actions/workflows/demo.yml/badge.svg)](https://github.com/ibizaman/selfhostblocks/actions/workflows/demo.yml)
![Matrix](https://img.shields.io/matrix/selfhostblocks%3Amatrix.org)

<hr />

# SelfHostBlocks

*SelfHostBlocks is a NixOS based server management for self-hosting
using building blocks and promoting best practices.*

It is obvious by now that
a deep dependency on proprietary service providers - "the cloud" - is a significant liability.
One aspect often talked about is privacy which is inherently not guaranteed
when using a proprietary service and is a valid concern.
A more punishing issue is having your account closed or locked
without prior warning.
When that happens, you get an instantaneous sinking feeling in your stomach
at the realization you lost access to your data, possibly without recourse.

Self-hosting is the only alternative that alleviate those concerns
but it requires a lot of technical skills and time.
SelfHostBlocks' and its sibling project [Skarabox][]' goal
is to lower the bar to self-hosting.

SelfHostBlocks is different from other server management projects
because it's main focus is ease of long term maintenance
before ease of installation.
To achieve this, it provides building blocks to setup services.
Some services are already provided out of the box
and adding custom ones is done easily thanks to those blocks.

The building blocks fit nicely together thanks to [contracts](#contracts)
which SelfHostBlocks introduces into nixpkgs.
This will increase modularity, code-reuse and empower end users to
assemble components that fit together to build their server.

## TOC

<!--toc:start-->
- [Usage](#usage)
  - [Existing Installation](#existing-installation)
  - [Installation From Scratch](#installation-from-scratch)
  - [Full Example](#full-example)
- [Features](#features)
  - [Services](#services)
  - [Blocks](#blocks)
  - [Unified Interfaces](#unified-interfaces)
  - [Contracts](#contracts)
  - [Interfacing With Other OSes](#interfacing-with-other-oses)
  - [Sitting on the Shoulders of a Giant](#sitting-on-the-shoulders-of-a-giant)
  - [Automatic Updates](#automatic-updates)
  - [Demos](#demos)
- [Roadmap](#roadmap)
- [Community](#community)
- [Funding](#funding)
- [License](#license)
<!--toc:end-->

## Usage

> **Caution:** You should know that although I am using everything in this repo for my personal
> production server, this is really just a one person effort for now and there are most certainly
> bugs that I didn't discover yet.

### Existing Installation

To get started using SelfHostBlocks,
follow [the usage section](https://shb.skarabox.com/usage.html) of the manual.
It goes over how to deploy with [Colmena][], [nixos-rebuild][] and [deploy-rs][]
and also goes over secrets management with [SOPS][].

[Colmena]: https://shb.skarabox.com/usage.html#usage-example-colmena
[nixos-rebuild]: https://shb.skarabox.com/usage.html#usage-example-nixosrebuild
[deploy-rs]: https://shb.skarabox.com/usage.html#usage-example-deployrs
[SOPS]: https://shb.skarabox.com/usage.html#usage-secrets

Then, to actually configure services, you can choose which one interests you in
[the services section](https://shb.skarabox.com/services.html) of the manual.
Not all services have a corresponding manual page yet.

Head over to the [matrix channel](https://matrix.to/#/#selfhostblocks:matrix.org)
for any remaining question, or just to say hi :)

### Installation From Scratch

I do recommend for this my sibling project [Skarabox][]
which bootstraps a new server and sets up a few tools:

- Create a bootable ISO, installable on an USB key.
- Handles one or two (in raid 1) SSDs for root partition.
- Handles two (in raid 1) or more hard drives for data partition.
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) to install NixOS headlessly.
- [disko](https://github.com/nix-community/disko) to format the drives using native ZFS encryption with remote unlocking through ssh.
- [sops-nix](https://github.com/Mic92/sops-nix) to handle secrets.
- [deploy-rs](https://github.com/serokell/deploy-rs) to deploy updates.

[Skarabox]:  https://github.com/ibizaman/skarabox

### Full Example

See [full example][] in the manual.

[full example]: https://shb.skarabox.com/usage.html#usage-complete-example

## Features

SelfHostBlocks provides building blocks that take care of common self-hosting needs:

- Backup for all services.
- Automatic creation of ZFS datasets per service.
- LDAP and SSO integration for most services.
- Monitoring with Grafana and Prometheus stack with provided dashboards.
- Automatic reverse proxy and certificate management for HTTPS.
- VPN and proxy tunneling services.

Great care is taken to make the proposed stack robust.
This translates into a test suite comprised of automated NixOS VM tests
which includes playwright tests to verify some important workflow
like logging in.

Also, the stack fits together nicely thanks to [contracts](#contracts).

### Services

[Provided services](https://shb.skarabox.com/services.html) are:

- Nextcloud
- Audiobookshelf
- Deluge + *arr stack
- Forgejo
- Grocy
- Hledger
- Home-Assistant
- Jellyfin
- Nextcloud
- Vaultwarden

Like explained above, those services all benefit from
out of the box backup,
LDAP and SSO integration,
monitoring with Grafana,
reverse proxy and certificate management
and VPN integration for the *arr suite.

Some services do not have an entry yet in the manual.
To know options for those, the only way for now
is to go to the [All Options][] section of the manual.

[All Options]: https://shb.skarabox.com/options.html

### Blocks

The services above rely on the following [common blocks][]:

[common blocks]: https://shb.skarabox.com/blocks.html

- Authelia
- BorgBackup
- Davfs
- LDAP
- Monitoring (Grafana - Prometheus - Loki stack)
- Nginx
- PostgreSQL
- Restic
- Sops
- SSL
- Tinyproxy
- VPN
- ZFS

Those blocks can be used with services
not provided by SelfHostBlocks.

Some blocks do not have an entry yet in the manual.
To know options for those, the only way for now
is to go to the [All Options][] section of the manual.

### Unified Interfaces

Thanks to the blocks,
SelfHostBlocks provides an unified configuration interface
for the services it provides.

Compare the configuration for Nextcloud and Forgejo.
The following snippets focus on similitudes and assume the relevant blocks - like secrets - are configured off-screen.
It also does not show specific options for each service.
These are still complete snippets that configure HTTPS,
subdomain serving the service, LDAP and SSO integration.

```nix
shb.nextcloud = {
  enable = true;
  subdomain = "nextcloud";
  domain = "example.com";

  ssl = config.shb.certs.certs.letsencrypt.${domain};

  apps.ldap = {
    enable = true;
    host = "127.0.0.1";
    port = config.shb.ldap.ldapPort;
    dcdomain = config.shb.ldap.dcdomain;
    adminPassword.result = config.shb.sops.secrets."nextcloud/ldap/admin_password".result;
  };
  apps.sso = {
    enable = true;
    endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

    secret.result = config.shb.sops.secrets."nextcloud/sso/secret".result;
    secretForAuthelia.result = config.shb.sops.secrets."nextcloud/sso/secretForAuthelia".result;
  };
};
```

```nix
shb.forgejo = {
  enable = true;
  subdomain = "forgejo";
  domain = "example.com";

  ssl = config.shb.certs.certs.letsencrypt.${domain};

  ldap = {
    enable = true;
    host = "127.0.0.1";
    port = config.shb.ldap.ldapPort;
    dcdomain = config.shb.ldap.dcdomain;
    adminPassword.result = config.shb.sops.secrets."nextcloud/ldap/admin_password".result;
  };

  sso = {
    enable = true;
    endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

    secret.result = config.shb.sops.secrets."forgejo/sso/secret".result;
    secretForAuthelia.result = config.shb.sops.secrets."forgejo/sso/secretForAuthelia".result;
  };
};
```

As you can see, they are pretty similar!
This makes setting up a new service pretty easy and intuitive.

SelfHostBlocks provides an ever growing list of [services](#provided-services)
that are configured in the same way.

### Contracts

To make building blocks that fit nicely together,
SelfHostBlocks pioneers [contracts][] which allows you, the final user,
to be more in control of which piece goes where.
This lets you choose, for example,
any reverse proxy you want or any database you want,
without requiring work from maintainers of the services you want to self host.

A [pre-RFC][] exists to upstream this concept into `nixpkgs`.
The [manual][contracts] also provides an explanation of the why and how of contracts.

Also, two videos exist of me presenting the topic,
the first at [NixCon North America in spring of 2024][NixConNA2024]
and the second at [NixCon in Berlin in fall of 2024][NixConBerlin2024].

[contracts]: https://shb.skarabox.com/contracts.html
[pre-RFC]: https://discourse.nixos.org/t/pre-rfc-decouple-services-using-structured-typing/58257
[NixConNA2024]: https://www.youtube.com/watch?v=lw7PgphB9qM
[NixConBerlin2024]: https://www.youtube.com/watch?v=CP0hR6w1csc

### Interfacing With Other OSes

Thanks to [contracts](#contracts), one can interface NixOS
with systems on other OSes.
The [pre-RFC][] explains how that works.

### Sitting on the Shoulders of a Giant

By using SelfHostBlocks, you get all the benefits of NixOS
which are, for self hosted applications specifically:

- declarative configuration;
- atomic configuration rollbacks;
- real programming language to define configurations;
- create your own higher level abstractions on top of SelfHostBlocks;
- integration with the rest of nixpkgs;
- much fewer "works on my machine" type of issues.

### Automatic Updates

SelfHostBlocks follows nixpkgs unstable branch closely.
There is a GitHub action running every couple of days that updates
the `nixpkgs` input in the root `flakes.nix`,
runs the tests and merges the PR automatically
if the tests pass.

A release is then made every few commits,
whenever deemed sensible.
On your side, to update I recommend pinning to a release
with the following command,
replacing the RELEASE with the one you want:

```bash
RELEASE=0.2.4
nix flake update \
  --override-input selfhostblocks github:ibizaman/selfhostblocks/$RELEASE \
  selfhostblock
```

### Demos

Demos that start and deploy a service
on a Virtual Machine on your computer are located
under the [demo](./demo/) folder.

These show the onboarding experience you would get
if you deployed one of the services on your own server.

## Roadmap

Currently, the Nextcloud and Vaultwarden services
and the SSL and backup blocks
are the most advanced and most documented.

Documenting all services and blocks will be done
as I make all blocks and services use the contracts.

Upstreaming changes is also on the roadmap.

Check the [issues][] and the [milestones]() to see planned work.
Feel free to add more or to contribute!

[issues]: (https://github.com/ibizaman/selfhostblocks/issues)
[milestones]: https://github.com/ibizaman/selfhostblocks/milestones

All blocks and services have NixOS tests.
Also, I am personally using all the blocks and services in this project, so they do work to some extent.

## Community

This project has been the main focus
of my (non work) life for the past 3 year now
and I intend to continue working on this for a long time.

All issues and PRs are welcome. For PRs, if they are substantial changes, please open an issue to
discuss the details first. More details in [the contributing section](https://shb.skarabox.com/contributing.html)
of the manual.

Come hang out in the [Matrix channel](https://matrix.to/#/%23selfhostblocks%3Amatrix.org). :)

One aspect that's close to my heart is I intent to make SelfHostBlocks the lightest layer on top of nixpkgs as
possible. I want to upstream as much as possible. I will still take some time to experiment here but
when I'm satisfied with how things look, I'll upstream changes.

## Funding

I was lucky to [obtain a grant][nlnet] from NlNet which is an European fund,
under [NGI Zero Core][NGI0],
to work on this project.
This also funds the contracts RFC.

Go apply for a grant too!

[nlnet]: https://nlnet.nl/project/SelfHostBlocks
[NGI0]: https://nlnet.nl/core/

<p>
<img alt="NlNet logo" src="https://nlnet.nl/logo/banner.svg" width="200" />
<img alt="NGI Zero Core logo" src="https://nlnet.nl/image/logos/NGI0Core_tag.svg" width="200" />
</p>

## License

I'm following the [Nextcloud](https://github.com/nextcloud/server) license which is AGPLv3.
See [this article](https://www.fsf.org/bulletin/2021/fall/the-fundamentals-of-the-agplv3) from the FSF that explains what this license adds to the GPL one.
