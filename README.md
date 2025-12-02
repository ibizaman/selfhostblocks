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

SelfHostBlocks is:

- Your escape from the cloud, for privacy and data sovereignty enthusiast. [Why?](#why-self-hosting)
- A groupware to self-host [all your data](#services): documents, pictures, calendars, contacts, etc.
- An opinionated NixOS server management OS for a [safe self-hosting experience](#features).
- A NixOS distribution making sure all services build and work correctly thanks to NixOS VM tests.
- A collection of NixOS modules standardizing options so configuring services [look the same](#unified-interfaces).
- A testing ground for [contracts](#contracts) which intents to make nixpkgs modules more modular.
- [Upstreaming][] as much as possible.

[upstreaming]: https://github.com/pulls?page=1&q=created%3A%3E2023-06-01+is%3Apr+author%3Aibizaman+archived%3Afalse+-repo%3Aibizaman%2Fselfhostblocks+-repo%3Aibizaman%2Fskarabox

## Why Self-Hosting

It is obvious by now that
a deep dependency on proprietary service providers - "the cloud" -
is a significant liability.
One aspect often talked about is privacy
which is inherently not guaranteed when using a proprietary service
and is a valid concern.
A more punishing issue is having your account closed or locked
without prior warning
When that happens,
you get an instantaneous sinking feeling in your stomach
at the realization you lost access to your data,
possibly without recourse.

Hosting services yourself is the obvious alternative
to alleviate those concerns
but it tends to require a lot of technical skills and time.
SelfHostBlocks (together with its sibling project [Skarabox][])
aims to lower the bar to self-hosting,
and provides an opinionated server management system based on NixOS modules
embedding best practices.
Contrary to other server management projects,
its main focus is ease of long term maintenance
before ease of installation.
To achieve this, it provides building blocks to setup services.
Some are already provided out of the box,
and customizing or adding additional ones is done easily.

The building blocks fit nicely together thanks to [contracts](#contracts)
which SelfHostBlocks sets out to introduce into nixpkgs.
This will increase modularity, code reuse
and empower end users to assemble components
that fit together to build their server.

## TOC

<!--toc:start-->
- [Usage](#usage)
  - [At a Glance](#at-a-glance)
  - [Existing Installation](#existing-installation)
  - [Installation From Scratch](#installation-from-scratch)
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

To get started using SelfHostBlocks, the following snippet is enough:

```nix
{
  inputs.selfhostblocks.url = "github:ibizaman/selfhostblocks";

  outputs = { selfhostblocks, ... }: let
    system = "x86_64-linux";
    nixpkgs' = selfhostblocks.lib.${system}.patchedNixpkgs;
  in
    nixosConfigurations = {
      myserver = nixpkgs'.nixosSystem {
        inherit system;
        modules = [
          selfhostblocks.nixosModules.default
          ./configuration.nix
        ];
      };
    };
}
```

SelfHostBlocks provides its own patched nixpkgs, so you are required to use it
otherwise evaluation can quickly break.
[The usage section](https://shb.skarabox.com/usage.html) of the manual has
more details and goes over how to deploy with [Colmena][], [nixos-rebuild][] and [deploy-rs][]
and also how to handle secrets management with [SOPS][].

[Colmena]: https://shb.skarabox.com/usage.html#usage-example-colmena
[nixos-rebuild]: https://shb.skarabox.com/usage.html#usage-example-nixosrebuild
[deploy-rs]: https://shb.skarabox.com/usage.html#usage-example-deployrs
[SOPS]: https://shb.skarabox.com/usage.html#usage-secrets

Then, to actually configure services, you can choose which one interests you in
the [services section](https://shb.skarabox.com/services.html) of the manual.

The [recipes section](https://shb.skarabox.com/recipes.html) of the manual shows some other common use cases.

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

This test suite also serves as a guaranty that all services provided by SelfHostBlocks
all evaluate, build and work correctly together. It works similarly as a distribution but here it's all [automated](#automatic-updates).

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
- Karakeep
- Open WebUI
- Pinchflat
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

The services above rely on the following [common blocks][]
which altogether provides a solid foundation for self-hosting services:

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
not provided by SelfHostBlocks as shown [in the manual][common blocks].

[common blocks]: https://shb.skarabox.com/blocks.html

The manual also provides documentation for each individual blocks.

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
    port = config.shb.lldap.ldapPort;
    dcdomain = config.shb.lldap.dcdomain;
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
    port = config.shb.lldap.ldapPort;
    dcdomain = config.shb.lldap.dcdomain;
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

SelfHostBlocks provides an ever growing list of [services](#services)
that are configured in the same way.

### Contracts

To make building blocks that fit nicely together,
SelfHostBlocks pioneers [contracts][] which allows you, the final user,
to be more in control of which piece goes where.
This lets you choose, for example,
any reverse proxy you want or any database you want,
without requiring work from maintainers of the services you want to self host.

An [RFC][] exists to upstream this concept into `nixpkgs`.
The [manual][contracts] also provides an explanation of the why and how of contracts.

Also, two videos exist of me presenting the topic,
the first at [NixCon North America in spring of 2024][NixConNA2024]
and the second at [NixCon in Berlin in fall of 2024][NixConBerlin2024].

[contracts]: https://shb.skarabox.com/contracts.html
[RFC]: https://github.com/NixOS/rfcs/pull/189
[NixConNA2024]: https://www.youtube.com/watch?v=lw7PgphB9qM
[NixConBerlin2024]: https://www.youtube.com/watch?v=CP0hR6w1csc

### Interfacing With Other OSes

Thanks to [contracts](#contracts), one can interface NixOS
with systems on other OSes.
The [RFC][] explains how that works.

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
  selfhostblocks
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

All issues and PRs are welcome:

- Use this project. Something does not make sense? Something's not working?
- Documentation. Something is not clear?
- New services. Have one of your preferred service not integrated yet?
- Better patterns. See something weird in the code?

For PRs, if they are substantial changes, please open an issue to
discuss the details first. More details in [the contributing section](https://shb.skarabox.com/contributing.html)
of the manual.

Issues that are being worked on are labeled with the [in progress][] label.
Before starting work on those, you might want to talk about it in the issue tracker
or in the [matrix][] channel.

The prioritized issues are those belonging to the [next milestone][milestone].
Those issues are not set in stone and I'd be very happy to solve
an issue an user has before scratching my own itch.

[in progress]: https://github.com/ibizaman/selfhostblocks/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22in%20progress%22
[matrix]: https://matrix.to/#/%23selfhostblocks%3Amatrix.org
[milestone]: https://github.com/ibizaman/selfhostblocks/milestones

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
