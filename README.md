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

# Self Host Blocks

*Modular server management based on NixOS modules and focused on best practices.*


SHB (Self Host Blocks) is yet another server management tool
that is not like the other server management tools.

## TOC

<!--toc:start-->
- [Usage](#usage)
- [Server Management](#server-management)
  - [Unified Interfaces](#unified-interfaces)
  - [Incremental Adoption](#incremental-adoption)
  - [More Benefits of SHB](#more-benefits-of-shb)
- [Roadmap](#roadmap)
- [Demos](#demos)
- [Community](#community)
- [License](#license)
<!--toc:end-->

## Usage

> **Caution:** You should know that although I am using everything in this repo for my personal
> production server, this is really just a one person effort for now and there are most certainly
> bugs that I didn't discover yet.

Self Host Blocks is available as a flake.
To use it in your project, add the following flake input:

```nix
inputs.selfhostblocks.url = "github:ibizaman/selfhostblocks";
```

Then, pin it to a release/tag with the following snippet.
Updating Self Host Blocks to a new version can be done the same way.

```nix
nix flake lock --override-input selfhostblocks github:ibizaman/selfhostblocks/v0.2.2
```

To get started using Self Host Blocks,
follow [the usage section](https://shb.skarabox.com/usage.html) of the manual.
It goes over how to deploy with [Colmena][], [nixos-rebuild][]
and also goes over secrets management with [SOPS][].

[Colmena]: https://colmena.cli.rs/
[nixos-rebuild]: https://nixos.org/manual/nixos/stable/#sec-changing-config
[SOPS]: https://github.com/Mic92/sops-nix

Then, to actually configure services, you can choose which one interests you in
[the services section](https://shb.skarabox.com/services.html) of the manual.

Head over to the [matrix channel](https://matrix.to/#/#selfhostblocks:matrix.org)
for any remaining question, or just to say hi :)

## Server Management

Self Host Blocks provides a standardized configuration for [some services](https://shb.skarabox.com/services.html) provided by nixpkgs.
The goal is to help spread adoption of self-hosting by providing an opinionated configuration with best practices by default.

Self Host Blocks takes care of common self-hosting needs:
- Backup for all services.
- LDAP and SSO integration for most services.
- Monitoring with Grafana and Prometheus stack with provided dashboards.
- Automatic reverse proxy and certificate management for HTTPS.
- VPN and proxy tunneling services.

### Unified Interfaces

SHB's first goal is to provide unified [building blocks](#available-blocks)
and by extension configuration interface, for self-hosting.

Compare the configuration for Nextcloud and Forgejo in Self Host Blocks.
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

SHB provides an ever growing list of [services](#provided-services)
that are configured in the same way.

### Incremental Adoption

SHB's second goal is to facilitate testing NixOS
and slowly switching an existing installation to NixOS.

To achieve this, SHB pioneers [contracts][]
which allows you, the final user, to be more in control of which piece go where.
This lets you choose, for example,
any reverse proxy you want or any database you want,
without requiring work from maintainers of the services you want to self host.
(See [manual][contracts] for a complete explanation)

Two videos exist of me presenting the topic,
the first at [NixCon North America in spring of 2024][NixConNA2024]
and the second at [NixCon in Berlin in fall of 2024][NixConBerlin2024].

[contracts]: https://shb.skarabox.com/contracts.html
[NixConNA2024]: https://www.youtube.com/watch?v=lw7PgphB9qM
[NixConBerlin2024]: https://www.youtube.com/watch?v=CP0hR6w1csc

### More Benefits of SHB

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

## Roadmap

Currently, the Nextcloud, Vaultwarden services and the SSL and backup blocks are the most advanced and most documented.

Documenting all services and blocks will be done as I make all blocks and services use the
contracts.

Upstreaming changes is also on the roadmap.

Check the [issues][] and the [milestones]() to see planned work.
Feel free to add more or to contribute!

[issues]: (https://github.com/ibizaman/selfhostblocks/issues)
[milestones]: https://github.com/ibizaman/selfhostblocks/milestones

All blocks and services have NixOS tests.
Also, I am personally using all the blocks and services in this project, so they do work to some extent.

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

I'm following the [Nextcloud](https://github.com/nextcloud/server) license which is AGPLv3.
See [this article][why agplv3] from the FSF that explains what this license adds to the GPL one.

[why agplv3]: (https://www.fsf.org/bulletin/2021/fall/the-fundamentals-of-the-agplv3)
