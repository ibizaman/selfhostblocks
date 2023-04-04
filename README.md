# Self Host Blocks

*Building blocks for self-hosting with battery included.*

SHB's (Self Host Blocks) goal is to provide a lower entry-bar for
self-hosting. I intend to achieve this by providing building blocks
promoting best practices to self-host a wide range of services. Also,
the design will be extendable to allow users to add services not
provided by SHB.

It's goal is to be to disnix what nixpkgs is to NixOS.

As far as features and best practices go, I intend to provide, for all
services:
- Protection and single sign-on using [Keycloak](https://www.keycloak.org/), where sensible.
- Automated backup of data and databases with [Borgmatic](https://torsion.org/borgmatic/).
- Encrypted external backup with [Rclone](https://rclone.org/).
- Central logging, monitoring and dashboards with [Prometheus](prometheus.io/) and [Grafana](https://grafana.com/).
- Integration with external services that are hard to self-host, like email sending.
- Deployment of every services on the same or different machines.
- Home dashboard with [Dashy](https://github.com/lissy93/dashy).
- Vault to store passwords and api keys using [Password Store](https://www.passwordstore.org/), those shouldn't be stored in config or on disk.
- Test changes using local virtual machines to avoid botching prod.
- Automated CI tests that can be run locally using virtual machines.

Implementation is made with the disnix suite -
[Disnix](https://github.com/svanderburg/disnix),
[Dysnomia](https://github.com/svanderburg/dysnomia),
[NixOps](https://github.com/NixOS/nixops) - built on top of the nix
ecosystem.

## Progress Status

Currently, this repo is WIP and the first two services I intend to
provide are [Tiny Tiny RSS](https://tt-rss.org/) and
[Vaultwarden](https://github.com/dani-garcia/vaultwarden). Vaultwarden
was chosen as it's IMO the first stepping stone to enable
self-hosting. Tiny Tiny RSS was chosen because it is somewhat
lightweight.

- Haproxy
  - [x] Systemd service
- Keycloak
  - [x] Provision using keycloak-cli-config
  - [x] Behind haproxy
  - [x] Integration tests
    - [x] Check DB is setup correctly
    - [ ] Make a curl request to assert service is up
    - [ ] Provision a user and attempt login
  - [ ] Backup
- Grafana/Alertmanager/Prometheus
  - [ ] Systemd service
  - [ ] Behind haproxy
  - [ ] Behind keycloak with oauth2proxy
  - [ ] Integration tests
  - [ ] Backup
- Vaultwarden
  - [x] Systemd service
  - [x] Behind haproxy
    - Under vaultwarden subdomain by default
  - [x] Behind keycloak with oauth2proxy
    - /admin path only allowed for admins
    - /api not protected
    - rest is allowed for any authenticated user
  - [ ] Integration tests
    - [ ] Assert endpoints are correctly protected
  - [ ] Backup
  - [ ] Dashboard with Grafana
  - [ ] Alerts with Alertmanager
- TTRSS
  - [ ] Systemd service
  - [ ] Behind haproxy
  - [ ] Behind keycloak with oauth2proxy
  - [ ] Integration tests
  - [ ] Backup
  - [ ] Dashboard with Grafana
  - [ ] Alerts with Alertmanager

Some other "dev" oriented TODOs can be found at the end of the README.

## Getting Started

If you know your way around disnix, feel free to skip this section. If
not and you'd rather read the [disnix
manual](https://hydra.nixos.org/build/203347995/download/2/manual/)
instead of reading my rambling, that's probably a good idea too.

Hey, you're still here! Let's start.

First, you need at least one deploy _target_ where NixOS is installed.
I'll refer you to the [official
guide](https://nixos.wiki/wiki/NixOS_Installation_Guide) for how to do
this. You can install on a could machine or a self-hosted server.

Second, you need a machine where Nix is installed, to drive the
deploy. It can be Nix or NixOS here. To install Nix, see the [official
guide](https://nixos.org/download.html). You'll then need to install
the following packages:
- `nixops_unstable`,
- `disnix`,
- `disnixos`,
- and `sops-nix` + `age` by following the [readme](https://github.com/Mic92/sops-nix).

Assuming this is done, you need to create a folder which will hold 3 files:
- One `network-<env>.nix` per environment - staging, prod - explains
  how to provision each deploy _target_. For example, you'd tell here
  which user or package should exist. That being said, the goal here
  is to keep this file minimal and instead use the `service.nix`.
- `services.nix` is used to install any service - a database, a
  reverse proxy, an app, etc. The goal here is to make the install
  procedure machine independent.
- `distribution.nix` is used to tell which service goes to which
  deployment target.

You'll need to setup password store, following [this
tutorial](https://elvishjerricco.github.io/2018/06/24/secure-declarative-key-management.html).

Next, look at the [examples](/docs/examples) for inspiration.

Also, the [integration tests](/tests/integration) contain more
bite-sized examples.

## Advised Workflow

The workflow is the following:
1. make a change,
2. add or modify tests,
3. run the [unit tests](/docs/tutorials/unittests.md) and [integration tests](/docs/tutorials/integrationtests.md),
4. deploy to [staging environment](/docs/tutorials/deploystaging.md)
5. and deploy to [production environment](/docs/tutorials/deployprod.md).

The first two bullets are very general so I can't realistically
enumerate all possibilities. I'll possibly provide examples in a
following update.

The following three are explained in the linked documents.

## Useful commands

### List deployments

To get the list of deployments, run:

```bash
nixops list
```

### List machines

To know what machines exist on a deployment, run:

```bash
nixops info -d <deployment>
```

### Ssh into a machine

```bash
export NIXOPS_DEPLOYMENT=<deployment>

nixops ssh <machine>
```

### Delete a deployment

```bash
nixops delete -d <deployment>
```

### Garbage collect old derivations

```bash
disnixos-env -s services.nix -n network-prod.nix -d distribution.nix --delete-generations=old
```

### Create manifest file

```bash
disnixos-manifest -s services.nix -n network-virtualbox.nix -d distribution.nix
```

### Create graph of service deployment

```bash
disnix-visualize /nix/store/cjiw9s257dpnvss2v6wm5a0iqx936hpq-manifest.xml | dot -Tpng > dot.png
```

### Test Hercules CI locally

```bash
NIX_PATH="" nix-instantiate default.nix
```

See https://docs.hercules-ci.com/hercules-ci/getting-started/repository for more info.

# Troubleshoot

## Derivation not copied correctly

Sometimes, when aborting at the wrong moment, something does not get
copied over correctly from your local machine to the `<machine>` you
deploy on. If that happens, copy the manifest name from running the
`disnixos-env` command (something like
`/nix/var/nix/profiles/per-user/.../disnix-coordinator/default-319-link`) and run:

```bash
disnix-distribute <manifest>
```

Another way is to identify what path is missing by running `ls
/nix/store/<path>` on both the host machine and the deploy machine.
That path should exist on the former but not the latter. To copy over,
run:

```bash
nix-store --export /nix/store/<path> | \
  bzip2 | \
  nixops ssh <machine> "bunzip2 | nix-store --import"
```

## Cannot lock services

If you canceled a `disnixos-env` invocation, you could end up with
locked services and the next invocation will fail. To unlock the
services manually, run:

```bash
disnix-lock -u
```

# Dev TODOs

In rough order of highest to lowest priority.

Roadmap for V1:
- [ ] Have Vaultwarden deployable behind Haproxy with Keycloak and
      oauth2proxy as SSO.
- [ ] Have example for Vaultwarden working.
- [ ] Have integration tests for Vaultwarden.

- Misc
  - [x] Function to generate haproxy config
  - [ ] Handle Nixops 2 (nixops_unstable)
  - [ ] Documentation for setting up on Linode
  - [ ] Documentation for getting started
  - [ ] Add configuration examples
  - [ ] Merge all keycloak services into one definition
  - [ ] Run tests on Hercules-CI
  - [ ] Explain how to setup secret keys.
  - [ ] Switch to using modules https://nixos.wiki/wiki/NixOS_modules
        to setup configuration.
- Dev
  - [ ] Automatically pull client credentials from keycloak to
        populate oauth2proxy's clientsecret key.
  - [ ] Automatic DNS setup of linode, probably using
        https://github.com/kubernetes-sigs/external-dns.
  - [ ] Add LDAP server.
  - [ ] Use LDAP server with vaultwarden using "[Directory
        Connector](https://github.com/dani-garcia/vaultwarden/wiki)".
  - [ ] Currently, there's a hack with a dnsmasq config in
        `configuration.nix` to redirect every request for
        `<subdomain>.<dev-domain>` to `<machine>`. This is not
        maintainable as the configuration does not rely on information
        provided by `distribution.nix`.
  - [ ] Add dependencies to systemd service files. I'm sure some of them
        are lacking the correct After= and Wants= fields.
  - [ ] Merge configs with systemd units. (remaining: keycloak)
  - [ ] Make haproxy resolve hostnames. For now, I hardcorded 127.0.0.1.
  - [ ] Auto-login into vaultwarden using SSO. Depends on
        https://github.com/dani-garcia/vaultwarden/pull/3154 being
        merged.
  - [ ] Go through https://xeiaso.net/blog/paranoid-nixos-2021-07-18 and
        https://nixos.wiki/wiki/Security
  - [ ] Move a few packages installed through network.nix into services.nix.
  - [ ] Use something else than `pass` to retrieve secrets. Or better,
        allow multiple options.
