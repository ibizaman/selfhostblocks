# Self Host Blocks

*Building blocks for self-hosting with battery included.*

SHB's (Self Host Blocks) goal is to provide a lower entry-bar for
self-hosting. I intend to achieve this by providing building blocks
promoting best practices to self-host a wide range of services. Also,
the design will be extendable to allow users to add services not
provided by SHB.

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

- [ ] Vaultwarden
- [ ] TTRSS

## Getting Started

WIP

## Deploy to staging environment - Virtualbox

Instead of deploying to prod machines, you'll deploy to VMs running on
your computer. This is tremendously helpful for testing.

```bash
export NIXOPS_DEPLOYMENT=vboxtest
export DISNIXOS_USE_NIXOPS=1

nixops create ./network-virtualbox.nix -d vboxtest

nixops deploy --option extra-builtins-file $(pwd)/pkgs/extra-builtins.nix
nixops reboot

disnixos-env -s services.nix -n network-virtualbox.nix -d distribution.nix
```

It's okay if the `nixops deploy` command fails to activate the new
configuration on first run because of the `virtualbox.service`. If
that happens, continue with the `nixops reboot` command. The service
will activate itself after the reboot.

Rebooting after deploying is anyway needed for systemd to pickup the
`/etc/systemd-mutable` path through the `SYSTEMD_UNIT_PATH`
environment variable.

The `extra-builtins-file` allows us to use password store as the
secrets manager. You'll probably see a errors about missing passwords
when running this for the first time. To fix those, generate the
password with `pass`.

### Handle host reboot

After restarting the computer running the VMs, do `nixops start` and
continue from the `nixops deploy ...` step.

### Cleanup

To start from scratch, run `nixops destroy` and start at the `nixops
deploy ...` step. This can be useful after fiddling with creating
directories. You could do this on prod too but... it's probably not a
good idea.

Also, you'll need to add the `--no-upgrade` option when running
`disnixos-env` the first time. Otherwise, disnix will try to
deactivate services but since the machine is clean, it will fail to
deactivate the services.

## Run tests

```bash
nix-instantiate --eval --strict . -A runtests
```

## Deploy to prod

```bash
export NIXOPS_DEPLOYMENT=prod
export DISNIXOS_USE_NIXOPS=1

nixops create ./network-prod.nix -d prod

nixops deploy --option extra-builtins-file $(pwd)/pkgs/extra-builtins.nix
nixops reboot

disnixos-env -s services.nix -n network-prod.nix -d distribution.nix
```

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

# TODOs

Todos, in rough order of highest to lowest priority.

* [x] Make vaultwarden's `/admin` path be protected by Keycloak using
      oauth2-proxy.
* [x] Add integration tests using VMs
* [ ] Merge all keycloak services into one definition
* [ ] Run those tests in CI
* [ ] Add examples
* [ ] Merge
* [ ] Automatically pull client credentials from keycloak to populate
      oauth2proxy's clientsecret key.
* [ ] Automatic DNS setup of linode, probably using
      https://github.com/kubernetes-sigs/external-dns.
* [ ] Add LDAP server.
* [ ] Use LDAP server with vaultwarden using "[Directory
      Connector](https://github.com/dani-garcia/vaultwarden/wiki)".
* [ ] Currently, there's a hack with a dnsmasq config in
      `configuration.nix` to redirect every request for
      `<subdomain>.<dev-domain>` to `<machine>`. This is not
      maintainable as the configuration does not rely on information
      provided by `distribution.nix`.
* [ ] Add dependencies to systemd service files. I'm sure some of them
      are lacking the correct After= and Wants= fields.
* [ ] Merge configs with systemd units.
* [ ] Make haproxy resolve hostnames. For now, I hardcorded 127.0.0.1.
* [ ] Auto-login into vaultwarden using SSO. Depends on
      https://github.com/dani-garcia/vaultwarden/pull/3154 being
      merged.
* [ ] Go through https://xeiaso.net/blog/paranoid-nixos-2021-07-18 and
      https://nixos.wiki/wiki/Security
* [ ] Move a few packages installed in network.nix into services.nix.

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
