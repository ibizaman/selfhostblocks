# Self Host Blocks

*Modular server management based on NixOS modules and focused on best practices.*

[![Documentation](https://github.com/ibizaman/selfhostblocks/actions/workflows/pages.yml/badge.svg)](https://github.com/ibizaman/selfhostblocks/actions/workflows/pages.yml)
[![Tests](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fgarnix.io%2Fapi%2Fbadges%2Fibizaman%2Fselfhostblocks%3Fbranch%3Dmain)](https://garnix.io) (using Garnix)
[![Demo](https://github.com/ibizaman/selfhostblocks/actions/workflows/demo.yml/badge.svg)](https://github.com/ibizaman/selfhostblocks/actions/workflows/demo.yml)

SHB (Self Host Blocks) is yet another server management tool
that is not like the other server management tools.

## TOC

<!--toc:start-->
- [Unified Interfaces](#unified-interfaces)
- [Incremental Adoption](#incremental-adoption)
- [Usage](#usage)
- [More Benefits of SHB](#more-benefits-of-shb)
- [Manual](#manual)
- [Roadmap](#roadmap)
- [Available Blocks](#available-blocks)
- [Provided Services](#provided-services)
- [Demos](#demos)
- [Community](#community)
- [License](#license)
<!--toc:end-->

## Unified Interfaces

SHB's first goal is to provide unified [building blocks](#available-blocks)
and by extension configuration interface, for self-hosting.

Compare the configuration for Nextcloud and Forgejo in Self Host Blocks.
The following snippets focus on similitudes and assume the relevant blocks are configured off-screen.
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
    adminPasswordFile = config.sops.secrets."nextcloud/ldap_admin_password".path;
  };
  apps.sso = {
    enable = true;
    endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

    secretFile = config.sops.secrets."nextcloud/sso/secret".path;
    secretFileForAuthelia = config.sops.secrets."authelia/nextcloud_sso_secret".path;
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
    adminPasswordFile = config.sops.secrets."forgejo/ldap_admin_password".path;
  };

  sso = {
    enable = true;
    endpoint = "https://${config.shb.authelia.subdomain}.${config.shb.authelia.domain}";

    secretFile = config.sops.secrets."forgejo/ssoSecret".path;
    secretFileForAuthelia = config.sops.secrets."forgejo/authelia/ssoSecret".path;
  };
};
```

As you can see, they are pretty similar!

SHB provides an ever growing list of [services](#provided-services)
that are configured in the same way.

## Incremental Adoption

SHB's second goal is to facilitate testing NixOS
and slowly switching an existing installation to NixOS.

To achieve this, SHB pioneers [contracts][]
which allows you, the final user, to be more in control of which piece go where.
This lets you choose, for example,
any reverse proxy you want or any database you want,
without requiring work from maintainers of the services you want to self host.
(See [manual][contracts] for a complete explanation)

[contracts]: https://shb.skarabox.com/contracts.html

## Usage

> **Caution:** You should know that although I am using everything in this repo for my personal
> production server, this is really just a one person effort for now and there are most certainly
> bugs that I didn't discover yet.

Self Host Blocks is available as a flake.
To use it in your project, add the following flake input:

```nix
inputs.selfhostblocks.url = "github:ibizaman/selfhostblocks";
```

More information is provided in [the manual](https://shb.skarabox.com/usage.html),
like secrets management.

- You are new to self hosting and want pre-configured services to deploy easily.
  Look at the [services section](https://shb.skarabox.com/services.html).
- You are a seasoned self-hoster but want to enhance some services you deploy already.
  Go to the [blocks section](https://shb.skarabox.com/blocks.html).
- You are a user of Self Host Blocks but would like to use your own implementation for a block.
  Go to the [contracts section](https://shb.skarabox.com/contracts.html).

Head over to the [matrix channel](https://matrix.to/#/#selfhostblocks:matrix.org)
for any remaining question, or just to say hi :)

## More Benefits of SHB

By using Self Host Blocks, you get all the benefits of NixOS
which are, for self hosted applications specifically:

- declarative configuration;
- atomic configuration rollbacks;
- real programming language to define configurations;
- user-defined abstractions (create your own functions or NixOS modules on top of SHB!);
- integration with the rest of nixpkgs;
- much fewer "works on my machine" type of issues.

In no particular order, here are some aspects of SHB which I find interesting and differentiates it
from other server management projects:

- SHB intends to be a library, not a framework. You can either go all in and use SHB provided
  services directly or use just one block in your existing infrastructure.
- SHB introduces [contracts](https://shb.skarabox.com/contracts.html) to allow you to swap
  implementation for each self-hosting need. For example, you should be able to use the reverse
  proxy you want without modifying any services depending on it.
- SHB contracts also allows you to use your own custom implementation instead of the provided one,
  as long as it follows the contract and passes the tests.
- SHB provides at least one implementation for each contract like backups, SSL certificates, reverse
  proxy, VPN, etc. Those are called blocks here and are documented in [the
  manual](https://shb.skarabox.com/blocks.html).
- SHB provides several services out of the box fully using the blocks provided. Those can also be
  found in [the manual](https://shb.skarabox.com/services.html).
- SHB follows nixpkgs unstable branch closely. There is a GitHub action running daily that updates
  the `nixpkgs` input in the root `flakes.nix`, runs the tests and merges a PR with the new input if
  the tests pass.

## Manual

The manual can be found at [shb.skarabox.com](https://shb.skarabox.com/).

Work is in progress to document everything in the manual but I'm not there yet. For what's not yet
documented, unfortunately the source code is the best place to read about them.
[Here](./modules/services) for services and [here](./modules/blocks) for blocks.

## Roadmap

Currently, the Nextcloud service and SSL block are the most advanced and most documented.

Documenting all services and blocks will be done as I make all blocks and services use the
contracts.

Upstreaming changes is also on the roadmap.

Check [the issues](https://github.com/ibizaman/selfhostblocks/issues) to see planned works. Feel
free to add more!

That being said, I am personally using all the blocks and services in this project, so they do work
to some extent.

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
- [`audiobookshelf.nix`](./modules/services/audiobookshelf.nix) for hosting podcasts and audio books https://www.audiobookshelf.org/.

## Demos

Demos that start and deploy a service on a Virtual Machine on your computer are located under the
[demo](./demo/) folder. These show the onboarding experience you would get if you deployed one of
the services on your own server.

## Community

All issues and PRs are welcome. For PRs, if they are substantial changes, please open an issue to
discuss the details first. More details in [here](https://shb.skarabox.com/contributing.html).

Come hang out in the [Matrix channel](https://matrix.to/#/%23selfhostblocks%3Amatrix.org). :)

One aspect that's close to my heart is I intent to make SHB the lightest layer on top of nixpkgs as
possible. I want to upstream as much as possible. I will still take some time to experiment here but
when I'm satisfied with how things look, I'll upstream changes.

## License

I'm following the [Nextcloud](https://github.com/nextcloud/server) license which is AGPLv3. See
[this article](https://www.fsf.org/bulletin/2021/fall/the-fundamentals-of-the-agplv3) from the FSF that explains what this license adds to the GPL
one.
