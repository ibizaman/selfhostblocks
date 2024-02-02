# Self Host Blocks

*Building blocks for self-hosting with battery included.*

[![Tests](https://github.com/ibizaman/selfhostblocks/actions/workflows/test.yml/badge.svg)](https://github.com/ibizaman/selfhostblocks/actions/workflows/test.yml)
[![Demo](https://github.com/ibizaman/selfhostblocks/actions/workflows/demo.yml/badge.svg)](https://github.com/ibizaman/selfhostblocks/actions/workflows/demo.yml)
[![Documentation](https://github.com/ibizaman/selfhostblocks/actions/workflows/docs.yml/badge.svg)](https://github.com/ibizaman/selfhostblocks/actions/workflows/docs.yml)

SHB's (Self Host Blocks) is yet another server management tool whose goal is to provide a lower
entry-bar for self-hosting. SHB provides opinionated [building blocks](#available-blocks) fitting
together to self-host any service you'd want. Some [common services](#provided-services) are
provided out of the box.

To achieve this, SHB is using the full power of NixOS modules. Indeed, each building block and each
service is a NixOS module and uses the modules defined in
[Nixpkgs](https://github.com/NixOS/nixpkgs/).

## TOC

<!--toc:start-->
- [Usage](#usage)
- [Manual](#manual)
- [Roadmap](#roadmap)
- [Available Blocks](#available-blocks)
- [Provided Services](#provided-services)
- [Demos](#demos)
- [Community](#community)
- [License](#license)
<!--toc:end-->

## Usage

> **Caution:** You should know that although I am using everything in this repo for my personal
> production server, this is really just a one person effort for now and there are most certainly
> bugs that I didn't discover yet.

Self Host Blocks is available as a flake. To use it in your project, add the following flake input:

```nix
inputs.selfhostblocks.url = "github:ibizaman/selfhostblocks";
```

See [the manual](https://shb.skarabox.com/usage.html) for more information about installing Self
Host Blocks.

- You are new to self hosting and want pre-configured services to deploy easily. Look at the
  [services section](https://shb.skarabox.com/services.html).
- You are a seasoned self-hoster but want to enhance some services you deploy already. Go to the
  [blocks section](https://shb.skarabox.com/blocks.html).
- You are a user of Self Host Blocks but would like to use your own implementation for a block. Head
  over to the [matrix channel](https://matrix.to/#/#selfhostblocks:matrix.org) to talk about it
  (this is WIP).

## Why yet another self hosting tool?

By using Self Host Blocks, you get all the benefits of NixOS which are, for self hosted applications
specifically:

- declarative configuration;
- atomic configuration rollbacks;
- real programming language to define configurations;
- user-defined abstractions (create your own functions or NixOS modules on top of SHB!);
- integration with the rest of nixpkgs.

Also, SHB intends to be a library, not a framework, so you can make it fit in your existing
deployment, slowly transitioning to using SHB one block or service at a time.

Each [building block](#available-blocks) defines a part of what a self-hosted app should provide.
For example, HTTPS access through a subdomain or Single Sign-On. The goal of SHB is to make sure
those blocks all fit together, whatever the actual implementation you choose. For example, the
subdomain access could be done using Caddy or Nginx. This is achieved by providing an explicit
contract for each block like for the [SSL
block](https://shb.skarabox.com/blocks-ssl.html#ssl-block-contract) and validating that contract
using NixOS VM integration tests.

## Manual

The manual can be found at [shb.skarabox.com](https://shb.skarabox.com/).

Currently, only some services and blocks are documented. For the rest, unfortunately the source code
is the best place to read about them. [Here](./modules/services) for services and
[here](./modules/blocks) for blocks.

## Roadmap

Currently, the Nextcloud service and SSL block are the most advanced and most documented.

Documenting all services and blocks will be done as I make all blocks and services use the
contracts.

Upstreaming changes is also on the roadmap.

Check [the issues](https://github.com/ibizaman/selfhostblocks/issues) to see planned works.

That being said, I am personally using all the blocks and services in this project, so they do work.

## Available Blocks

- [`authelia.nix`](./modules/blocks/authelia.nix) for Single Sign On.
- [`backup.nix`](./modules/blocks/backup.nix).
- [`ldap.nix`](./modules/blocks/ldap.nix) for user management.
- [`monitoring.nix`](./modules/blocks/monitoring.nix) for dashboards, logs and alerts.
- [`nginx.nix`](./modules/blocks/nginx.nix) for reverse proxy with SSL termination.
- [`postgresql.nix`](./modules/blocks/postgresql.nix) for database setup.
- [`ssl.nix`](./modules/blocks/ssl.nix) for maintaining self-signed SSL certificates or certificates provided by Let's Encrypt.
- [`tinyproxy.nix`](./modules/blocks/tinyproxy.nix) to forward traffic to a VPN tunnel.
- [`vpn.nix`](./modules/blocks/vpn.nix) to setup a VPN tunnel.

## Provided Services

- [`arr.nix`](./modules/services/arr.nix) for finding media https://wiki.servarr.com/.
- [`deluge.nix`](./modules/services/deluge.nix) for downloading linux isos https://deluge-torrent.org/.
- [`hledger.nix`](./modules/services/hledger.nix) for managing finances https://hledger.org/.
- [`home-assistant.nix`](./modules/services/home-assistant.nix) for private IoT https://www.home-assistant.io/.
- [`jellyfin.nix`](./modules/services/jellyfin.nix) for watching media https://jellyfin.org/.
- [Nextcloud Server](https://shb.skarabox.com/services-nextcloud.html) for private documents, contacts, calendar, etc https://nextcloud.com.
- [`vaultwarden.nix`](./modules/services/vaultwarden.nix) for passwords https://github.com/dani-garcia/vaultwarden.

## Demos

Demos that start and deploy a service on a Virtual Machine on your computer are located under the
[demo](./demo/) folder. These show the onboarding experience you would get if you deployed one of
the services on your own server.

## Community

All issues and PRs are welcome. For PRs, if they are substantial changes, please open an issue to
discuss the details first.

Come hang out in the [Matrix channel](https://matrix.to/#/%23selfhostblocks%3Amatrix.org). :)

One important goal of SHB is to be the smallest amount of code above what is available in
[nixpkgs](https://github.com/NixOS/nixpkgs). It should be the minimum necessary to make packages
available there conform with the contracts. This way, there are less chance of breakage when nixpkgs
gets updated. I intend to upstream to nixpkgs as much of those as makes sense.

## License

I'm following the [Nextcloud](https://github.com/nextcloud/server) license which is AGPLv3. See
[this article](https://www.fsf.org/bulletin/2021/fall/the-fundamentals-of-the-agplv3) from the FSF that explains what this license adds to the GPL
one.
