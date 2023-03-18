# Deploy to staging environment

Instead of deploying to prod machines, you'll deploy to VMs running on
your computer with Virtualbox. This is tremendously helpful for
testing.

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
secrets manager. You'll probably see errors about missing passwords
when running this for the first time. To fix those, generate the
password with `pass`.

## Handle host reboot

After restarting the computer running the VMs, do `nixops start` and
continue from the `nixops deploy ...` step.

## Cleanup

To start from scratch, run `nixops destroy` and start at the `nixops
deploy ...` step. This can be useful after fiddling with creating
directories. You could do this on prod too but... it's probably not a
good idea.

Also, you'll need to add the `--no-upgrade` option when running
`disnixos-env` the first time. Otherwise, disnix will try to
deactivate services but since the machine is clean, it will fail to
deactivate the services.
